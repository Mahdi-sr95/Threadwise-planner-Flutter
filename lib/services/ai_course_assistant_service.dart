import 'dart:convert';

import '../models/ai_course_parse_result.dart';
import '../models/enums.dart';
import 'llm_client.dart';

/// Extracts courses from free-form user text using an LLM.
///
/// Goals:
/// - Do not depend on any specific writing format (commas, dashes, bullets, etc.).
/// - Do not depend on any specific language or keywords.
/// - Only return "unrelated" when the model is confident the text is not about studies.
/// - If some fields are missing (difficulty/studyHours), apply safe defaults instead of rejecting.
class AiCourseAssistantService {
  final LLMClient _client;

  AiCourseAssistantService(this._client);

  Future<AiCourseParseResult> analyzeAndExtractCourses(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return AiCourseParseResult.error('Please write some text first.');
    }

    final today = DateTime.now().toIso8601String().split('T').first;

    const systemPrompt = r'''
You are ThreadWise Planner AI Assistant.

You MUST support any language and any writing style:
- paragraphs, bullet points, messy notes, copied messages
- do NOT require separators like comma/dash/underscore

Return ONLY one valid JSON object (no markdown, no extra text) with EXACTLY this schema:

{
  "status": "unrelated|incomplete|complete",
  "message": "string",
  "courses": [
    {
      "name": "string",
      "deadline": "YYYY-MM-DD",
      "difficulty": "easy|medium|hard",
      "studyHours": number
    }
  ],
  "ignoredTextSummary": "string (optional)"
}

Rules:
- Use "unrelated" ONLY if the input is clearly not about studying/courses/exams/deadlines.
- If you can extract at least one course name and a deadline date, set status="complete".
- If difficulty is missing/unclear, set difficulty="medium" and explain this default in "message".
- If studyHours is missing/unclear, estimate a positive number and explain it's an estimate in "message".
- Convert dates to YYYY-MM-DD. Resolve relative dates using "Today is ..." below.
- Write "message" in the same language as the user's input when possible.
''';

    final prompt =
        '''
Today is $today.

User text:
"""$text"""

Return ONLY the JSON object described in the instructions.
''';

    String raw = '';
    try {
      raw = await _client.sendPrompt(
        prompt,
        systemPrompt: systemPrompt,
        maxTokens: 900,
        temperature: 0.2,
        topP: 0.9,
      );
    } catch (e) {
      return AiCourseParseResult.error('AI request failed: $e');
    }

    final obj = _tryParseJsonObject(raw);
    if (obj == null) {
      return AiCourseParseResult(
        status: InputStatus.incomplete,
        message: 'I could not parse the AI response. Please try again.',
        courses: const [],
        rawModelOutput: raw,
      );
    }

    final statusStr = (obj['status'] ?? '').toString().trim().toLowerCase();
    final message = (obj['message'] ?? '').toString().trim();
    final ignored = (obj['ignoredTextSummary'] ?? '').toString().trim();

    final baseStatus = _statusFromString(statusStr);
    final combinedMessage = <String>[
      message,
      ignored,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n\n');

    final rawCourses = obj['courses'];
    final courses = <ParsedCourseDraft>[];

    if (rawCourses is List) {
      for (final item in rawCourses) {
        if (item is! Map) continue;

        final name = (item['name'] ?? '').toString().trim();
        final deadlineRaw = (item['deadline'] ?? '').toString().trim();
        final diffRaw = (item['difficulty'] ?? '').toString().trim();
        final hoursRaw = item['studyHours'];

        if (name.isEmpty) continue;

        // Deadline: must be usable; we will not "reject the user" for formatting,
        // but we must request a deadline if AI did not provide one.
        final deadlineIso = _normalizeToIsoDate(deadlineRaw);
        if (deadlineIso == null) {
          return AiCourseParseResult(
            status: InputStatus.incomplete,
            message: _preferNonEmpty(
              combinedMessage,
              'Please provide a deadline date for "$name" (example: 2026-02-20).',
            ),
            courses: const [],
            rawModelOutput: raw,
          );
        }

        // Difficulty: default to medium if missing/invalid.
        final difficulty = _difficultyFromSchema(diffRaw) ?? Difficulty.medium;

        // Study hours: use AI value if valid, otherwise estimate.
        final hours = _hoursFromAny(hoursRaw);
        final studyHours = (hours != null && hours > 0)
            ? hours
            : _estimateStudyHours(deadlineIso);

        courses.add(
          ParsedCourseDraft(
            name: name,
            deadline: deadlineIso,
            difficulty: difficulty,
            studyHours: studyHours,
          ),
        );
      }
    }

    // If we managed to build at least one course, do not reject due to AI status.
    if (courses.isNotEmpty) {
      return AiCourseParseResult(
        status: InputStatus.complete,
        message: combinedMessage.isEmpty
            ? InputStatus.complete.message
            : combinedMessage,
        courses: List.unmodifiable(courses),
        rawModelOutput: raw,
      );
    }

    // No extracted courses: honor unrelated/incomplete, but stay helpful.
    if (baseStatus == InputStatus.unrelated) {
      return AiCourseParseResult(
        status: InputStatus.unrelated,
        message: combinedMessage.isEmpty
            ? InputStatus.unrelated.message
            : combinedMessage,
        courses: const [],
        rawModelOutput: raw,
      );
    }

    return AiCourseParseResult(
      status: InputStatus.incomplete,
      message: _preferNonEmpty(
        combinedMessage,
        'Please include at least one course/exam name and a deadline date.',
      ),
      courses: const [],
      rawModelOutput: raw,
    );
  }

  InputStatus _statusFromString(String s) {
    switch (s) {
      case 'unrelated':
        return InputStatus.unrelated;
      case 'complete':
        return InputStatus.complete;
      case 'incomplete':
      default:
        return InputStatus.incomplete;
    }
  }

  Difficulty? _difficultyFromSchema(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'easy') return Difficulty.easy;
    if (s == 'medium') return Difficulty.medium;
    if (s == 'hard') return Difficulty.hard;
    return null;
  }

  double? _hoursFromAny(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();

    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
    if (m == null) return null;

    return double.tryParse(m.group(1)!);
  }

  double _estimateStudyHours(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return 10.0;

    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final d1 = DateTime(dt.year, dt.month, dt.day);
    final daysLeft = d1.difference(d0).inDays;

    if (daysLeft <= 3) return 18.0;
    if (daysLeft <= 7) return 15.0;
    if (daysLeft <= 14) return 12.0;
    if (daysLeft <= 30) return 10.0;
    return 8.0;
  }

  String _preferNonEmpty(String primary, String fallback) {
    final p = primary.trim();
    return p.isNotEmpty ? p : fallback;
  }

  /// Normalizes a date string to YYYY-MM-DD.
  ///
  /// We keep this intentionally minimal and language-agnostic:
  /// - Accepts YYYY-MM-DD (and YYYY/MM/DD, YYYY.MM.DD)
  /// - Accepts DD/MM/YYYY or MM/DD/YYYY (tries both; if ambiguous, prefers day-first)
  /// - Accepts a full ISO datetime by taking the first 10 characters
  String? _normalizeToIsoDate(String raw) {
    final s0 = raw.trim();
    if (s0.isEmpty) return null;

    // Full ISO datetime -> use first 10 chars if possible.
    if (s0.length >= 10) {
      final head = s0.substring(0, 10);
      final headIso = _normalizeIsoLike(head);
      if (headIso != null) return headIso;
    }

    // ISO-like
    final iso = _normalizeIsoLike(s0);
    if (iso != null) return iso;

    // Numeric day/month/year
    final numeric = RegExp(
      r'^\s*(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{4})\s*$',
    ).firstMatch(s0);
    if (numeric != null) {
      final a = int.tryParse(numeric.group(1)!);
      final b = int.tryParse(numeric.group(2)!);
      final y = int.tryParse(numeric.group(3)!);
      if (a == null || b == null || y == null) return null;

      // Prefer day-first, but also try swapped if day-first invalid.
      final dayFirst = _padIso(y, b, a);
      if (dayFirst != null) return dayFirst;

      final monthFirst = _padIso(y, a, b);
      if (monthFirst != null) return monthFirst;

      return null;
    }

    return null;
  }

  String? _normalizeIsoLike(String raw) {
    final s = raw.trim().replaceAll('/', '-').replaceAll('.', '-');
    final parts = s.split('-');
    if (parts.length != 3) return null;

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;

    return _padIso(y, m, d);
  }

  String? _padIso(int y, int m, int d) {
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;

    // Validate using DateTime normalization rules.
    final dt = DateTime(y, m, d);
    if (dt.year != y || dt.month != m || dt.day != d) return null;

    final mm = m.toString().padLeft(2, '0');
    final dd = d.toString().padLeft(2, '0');
    return '$y-$mm-$dd';
  }

  Map<String, dynamic>? _tryParseJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // First attempt: strict decode.
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}

    // Recovery: extract outermost {...}.
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    final candidate = trimmed.substring(start, end + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }

    // Explicit null return to satisfy analyzer warning (nullable return type).
    return null;
  }
}

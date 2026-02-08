import 'dart:convert';

import '../models/ai_course_parse_result.dart';
import '../models/enums.dart';
import 'llm_client.dart';

/// AI assistant that extracts structured courses from free-form user text.
///
/// Key goals:
/// - Be robust to natural language dates (e.g., "15th of September 2026").
/// - If a date is ambiguous (e.g., "09/10/2026"), ask a precise follow-up instead of failing.
/// - Keep output strict: we only accept courses when the model marks status="complete".
class AiCourseAssistantService {
  final LLMClient _client;

  AiCourseAssistantService(this._client);

  Future<AiCourseParseResult> analyzeAndExtractCourses(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return AiCourseParseResult.error('Please write some text first.');
    }

    final today = DateTime.now().toIso8601String().split('T').first;

    // System prompt: strict JSON only, any language.
    const systemPrompt = '''
You are ThreadWise Planner AI Assistant.

Your job:
1) Decide if the user's text is related to study planning/courses/exams.
2) If incomplete, ask for the missing info (be specific) WITHOUT deleting the user's text.
3) If the text is mixed (relevant + irrelevant), ignore irrelevant parts and proceed only with relevant parts.
4) Extract structured courses ONLY when you have enough info.

Output requirements (VERY IMPORTANT):
- Output ONLY a single valid JSON object.
- No markdown, no code fences, no extra text.
- Use exactly these fields:

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
- If unrelated: status="unrelated", courses=[], message explains you only help with study planning/courses/exams.
- If incomplete: status="incomplete", courses=[], message must ask *precise* missing info (e.g., which year for a date).
- If complete: status="complete" and courses must contain 1..N courses.
- Deadlines must be converted to YYYY-MM-DD. If user uses relative dates, use today's date as reference.
- difficulty must be easy|medium|hard. If missing or unclear, ask (incomplete), do not guess.
- studyHours must be a positive number. If missing or unclear, ask (incomplete), do not guess.
- Write "message" in the SAME language as the user's text if possible.
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
      return AiCourseParseResult.error(
        'AI output was not valid JSON. Please try again.',
        raw: raw,
      );
    }

    final statusStr = (obj['status'] ?? '').toString().trim().toLowerCase();
    final message = (obj['message'] ?? '').toString().trim();
    final ignored = (obj['ignoredTextSummary'] ?? '').toString().trim();

    final status = _statusFromString(statusStr);

    // Keep message language-neutral and preserve model message if present.
    final combinedMessage = <String>[
      message,
      ignored,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n\n');

    // Only accept extracted courses when the model explicitly says "complete".
    if (status != InputStatus.complete) {
      return AiCourseParseResult(
        status: status,
        message: combinedMessage.isEmpty ? status.message : combinedMessage,
        courses: const [],
        rawModelOutput: raw,
      );
    }

    final rawCourses = obj['courses'];
    final courses = <ParsedCourseDraft>[];

    if (rawCourses is List) {
      for (final item in rawCourses) {
        if (item is! Map) continue;

        final name = (item['name'] ?? '').toString().trim();
        final deadlineRaw = (item['deadline'] ?? '').toString().trim();
        final diffStr = (item['difficulty'] ?? '').toString().trim();
        final hoursRaw = item['studyHours'];

        final hours = (hoursRaw is num)
            ? hoursRaw.toDouble()
            : double.tryParse(hoursRaw?.toString() ?? '');

        if (name.isEmpty) continue;

        // Validate hours (if missing, we must ask, not guess).
        if (hours == null || hours <= 0) {
          return AiCourseParseResult(
            status: InputStatus.incomplete,
            message: _preferNonEmpty(
              combinedMessage,
              'For "$name", how many study hours do you need?',
            ),
            courses: const [],
            rawModelOutput: raw,
          );
        }

        // Validate difficulty (if missing, we must ask, not guess).
        if (diffStr.isEmpty) {
          return AiCourseParseResult(
            status: InputStatus.incomplete,
            message: _preferNonEmpty(
              combinedMessage,
              'For "$name", what is the difficulty (easy/medium/hard)?',
            ),
            courses: const [],
            rawModelOutput: raw,
          );
        }

        Difficulty diff;
        try {
          diff = _difficultyFromString(diffStr);
        } catch (_) {
          return AiCourseParseResult(
            status: InputStatus.incomplete,
            message: _preferNonEmpty(
              combinedMessage,
              'For "$name", difficulty must be easy/medium/hard. Which one is it?',
            ),
            courses: const [],
            rawModelOutput: raw,
          );
        }

        // Normalize deadline robustly.
        final norm = _normalizeDateFlexible(deadlineRaw);
        if (norm.kind == _DateNormKind.ok) {
          courses.add(
            ParsedCourseDraft(
              name: name,
              deadline: norm.iso!,
              difficulty: diff,
              studyHours: hours,
            ),
          );
          continue;
        }

        // If ambiguous or missing year: ask a precise follow-up question.
        return AiCourseParseResult(
          status: InputStatus.incomplete,
          message: _preferNonEmpty(
            combinedMessage,
            'For "$name", ${norm.question ?? 'please provide a clear deadline date (YYYY-MM-DD).'}',
          ),
          courses: const [],
          rawModelOutput: raw,
        );
      }
    }

    if (courses.isEmpty) {
      return AiCourseParseResult.error(
        combinedMessage.isNotEmpty
            ? combinedMessage
            : 'AI marked the input as complete, but no courses were extracted. Please try again.',
        raw: raw,
      );
    }

    return AiCourseParseResult(
      status: InputStatus.complete,
      message: combinedMessage.isEmpty ? status.message : combinedMessage,
      courses: List.unmodifiable(courses),
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

  Difficulty _difficultyFromString(String s) {
    switch (s.trim().toLowerCase()) {
      case 'easy':
        return Difficulty.easy;
      case 'medium':
        return Difficulty.medium;
      case 'hard':
        return Difficulty.hard;
      default:
        throw FormatException(
          'Invalid difficulty (expected easy|medium|hard).',
          s,
        );
    }
  }

  /// Returns the best message: if [primary] is non-empty, keep it; otherwise use [fallback].
  String _preferNonEmpty(String primary, String fallback) {
    final p = primary.trim();
    return p.isNotEmpty ? p : fallback;
  }

  // -------------------------
  // Date normalization
  // -------------------------

  _DateNorm _normalizeDateFlexible(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const _DateNorm(
        kind: _DateNormKind.needClarification,
        question: 'what is the deadline date?',
      );
    }

    // 1) ISO-like: YYYY-MM-DD or YYYY-M-D
    final iso = _normalizeIsoDate(s);
    if (iso != null) return _DateNorm.ok(iso);

    // 2) Relative keywords (very minimal; model should usually convert these already)
    final lower = s.toLowerCase();
    if (lower == 'today') {
      final d = DateTime.now();
      return _DateNorm.ok(_padIso(d.year, d.month, d.day));
    }
    if (lower == 'tomorrow') {
      final d = DateTime.now().add(const Duration(days: 1));
      return _DateNorm.ok(_padIso(d.year, d.month, d.day));
    }

    // 3) Numeric: DD/MM/YYYY or MM/DD/YYYY (ambiguous when both <=12)
    final slash = RegExp(r'^\s*(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\s*$');
    final m = slash.firstMatch(s);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);

      if (a == null || b == null || y == null) {
        return const _DateNorm(
          kind: _DateNormKind.needClarification,
          question: 'please provide the date as YYYY-MM-DD.',
        );
      }

      // If both could be month/day -> ask to clarify format
      final aIsMonth = a >= 1 && a <= 12;
      final bIsMonth = b >= 1 && b <= 12;

      if (aIsMonth && bIsMonth && a != b) {
        return const _DateNorm(
          kind: _DateNormKind.needClarification,
          question: 'is this date in DD/MM/YYYY or MM/DD/YYYY format?',
        );
      }

      // Prefer DD/MM/YYYY when unambiguous (e.g., 15/09/2026).
      final day = a;
      final month = b;

      if (_isValidYmd(y, month, day)) {
        return _DateNorm.ok(_padIso(y, month, day));
      }

      // Try swapped as fallback if first attempt invalid.
      final day2 = b;
      final month2 = a;
      if (_isValidYmd(y, month2, day2)) {
        return _DateNorm.ok(_padIso(y, month2, day2));
      }

      return const _DateNorm(
        kind: _DateNormKind.needClarification,
        question: 'please provide a valid date as YYYY-MM-DD.',
      );
    }

    // 4) Month names (English): "15th of September 2026", "Sep 15, 2026", "15 Sep 2026"
    final monthName = _parseMonthNameDate(s);
    if (monthName != null) return monthName;

    return const _DateNorm(
      kind: _DateNormKind.needClarification,
      question:
          'please provide the deadline as YYYY-MM-DD (or include the year, e.g., "15 Sep 2026").',
    );
  }

  /// Accepts YYYY-MM-DD and tolerates YYYY-M-D, returns strictly padded YYYY-MM-DD.
  String? _normalizeIsoDate(String raw) {
    final s = raw.trim();
    final parts = s.split('-');
    if (parts.length != 3) return null;

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);

    if (y == null || m == null || d == null) return null;
    if (!_isValidYmd(y, m, d)) return null;

    return _padIso(y, m, d);
  }

  _DateNorm? _parseMonthNameDate(String s) {
    final months = _monthMap();

    // Pattern: 15th of September 2026
    final p1 = RegExp(
      r'^\s*(\d{1,2})(?:st|nd|rd|th)?\s*(?:of\s+)?([A-Za-z]+)\s*,?\s*(\d{4})\s*$',
      caseSensitive: false,
    );
    final m1 = p1.firstMatch(s);
    if (m1 != null) {
      final day = int.tryParse(m1.group(1)!);
      final monStr = m1.group(2)!.toLowerCase();
      final year = int.tryParse(m1.group(3)!);

      final month = months[monStr];
      if (day == null || year == null || month == null) return null;

      if (_isValidYmd(year, month, day)) {
        return _DateNorm.ok(_padIso(year, month, day));
      }
      return const _DateNorm(
        kind: _DateNormKind.needClarification,
        question: 'that date seems invalid; please provide a valid YYYY-MM-DD.',
      );
    }

    // Pattern: Sep 15, 2026
    final p2 = RegExp(
      r'^\s*([A-Za-z]+)\s*(\d{1,2})(?:st|nd|rd|th)?\s*,?\s*(\d{4})\s*$',
      caseSensitive: false,
    );
    final m2 = p2.firstMatch(s);
    if (m2 != null) {
      final monStr = m2.group(1)!.toLowerCase();
      final day = int.tryParse(m2.group(2)!);
      final year = int.tryParse(m2.group(3)!);

      final month = months[monStr];
      if (day == null || year == null || month == null) return null;

      if (_isValidYmd(year, month, day)) {
        return _DateNorm.ok(_padIso(year, month, day));
      }
      return const _DateNorm(
        kind: _DateNormKind.needClarification,
        question: 'that date seems invalid; please provide a valid YYYY-MM-DD.',
      );
    }

    // Pattern: 15 Sep (missing year) => ask year
    final p3 = RegExp(
      r'^\s*(\d{1,2})(?:st|nd|rd|th)?\s*([A-Za-z]+)\s*$',
      caseSensitive: false,
    );
    final m3 = p3.firstMatch(s);
    if (m3 != null) {
      return const _DateNorm(
        kind: _DateNormKind.needClarification,
        question: 'which year is this deadline in?',
      );
    }

    return null;
  }

  Map<String, int> _monthMap() => const {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  bool _isValidYmd(int y, int m, int d) {
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    try {
      final dt = DateTime(y, m, d);
      return dt.year == y && dt.month == m && dt.day == d;
    } catch (_) {
      return false;
    }
  }

  String _padIso(int y, int m, int d) {
    final mm = m.toString().padLeft(2, '0');
    final dd = d.toString().padLeft(2, '0');
    return '$y-$mm-$dd';
  }

  // -------------------------
  // JSON parsing
  // -------------------------

  Map<String, dynamic>? _tryParseJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // First attempt: strict decode.
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}

    // Recovery: extract outermost {...}
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

    return null;
  }
}

enum _DateNormKind { ok, needClarification }

class _DateNorm {
  final _DateNormKind kind;
  final String? iso;
  final String? question;

  const _DateNorm({required this.kind, this.iso, this.question});

  const _DateNorm.ok(String iso) : this(kind: _DateNormKind.ok, iso: iso);
}

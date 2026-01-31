import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for interacting with Hugging Face Router chat-completions endpoint.
class LLMClient {
  static const String apiUrl = 'https://router.huggingface.co/v1/chat/completions';

  final String apiToken;
  final String model;

  LLMClient({
    required this.apiToken,
    this.model = 'meta-llama/Llama-3.2-3B-Instruct',
  });

  /// Sends a chat prompt and returns the assistant content as plain text.
  /// Retries on transient failures (e.g., 503 model loading).
  Future<String> sendPrompt(
    String prompt, {
    int maxTokens = 2500,
    String? systemPrompt,
    double temperature = 0.7,
    double topP = 0.9,
    int retries = 3,
  }) async {
    final List<Map<String, String>> messages = [];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    Duration waitTime = const Duration(seconds: 3);

    for (int i = 0; i < retries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Authorization': 'Bearer $apiToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'messages': messages,
                'max_tokens': maxTokens,
                'temperature': temperature,
                'top_p': topP,
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['choices'] is List) {
            final List choices = decoded['choices'] as List;
            if (choices.isNotEmpty) {
              final dynamic message = choices.first['message'];
              final String? content = message is Map ? message['content']?.toString() : null;
              return (content ?? '').trim();
            }
          }
          return '';
        }

        if (response.statusCode == 503) {
          if (i < retries - 1) {
            await Future.delayed(waitTime);
            waitTime = Duration(seconds: waitTime.inSeconds * 2);
            continue;
          }
          throw Exception('Model is still loading. Please try again later.');
        }

        if (response.statusCode == 401) {
          throw Exception('Invalid API token. Check your HuggingFace token.');
        }

        if (response.statusCode == 404 || response.statusCode == 410) {
          throw Exception('Model not found or endpoint not available.');
        }

        throw Exception('API Error ${response.statusCode}: ${response.body}');
      } catch (e) {
        final msg = e.toString();
        final isNetwork =
            msg.contains('SocketException') || msg.contains('TimeoutException');

        if (isNetwork && i < retries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        rethrow;
      }
    }

    throw Exception('Failed after $retries attempts');
  }

  /// Tests whether the API is reachable.
  Future<bool> testConnection() async {
    try {
      final response = await sendPrompt(
        'Respond with just "OK".',
        systemPrompt: 'You are a helpful assistant.',
        maxTokens: 10,
      );
      return response.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

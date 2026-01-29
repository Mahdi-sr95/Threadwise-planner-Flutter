import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for interacting with Hugging Face LLM API
/// Supports chat completion format with retry logic and error handling
class LLMClient {
  final String apiUrl;
  final String apiToken;

  LLMClient({
    required this.apiToken,
    String model = 'meta-llama/Llama-3.2-3B-Instruct',
  }) : apiUrl = 'https://api-inference.huggingface.co/models/$model/v1/chat/completions';

  /// Send a prompt to the LLM and return the response
  /// Automatically retries on model loading (503) or network errors
  Future<String> sendPrompt(
    String prompt, {
    int maxTokens = 2500,
    String? systemPrompt,
  }) async {
    final messages = <Map<String, String>>[];
    
    if (systemPrompt != null) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }

    messages.add({
      'role': 'user',
      'content': prompt,
    });

    int retries = 3;
    Duration waitTime = const Duration(seconds: 3);

    for (int i = 0; i < retries; i++) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'messages': messages,
            'max_tokens': maxTokens,
            'temperature': 0.7,
            'top_p': 0.9,
            'stream': false,
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('choices')) {
            final choices = data['choices'] as List;
            if (choices.isNotEmpty) {
              final message = choices[0]['message'];
              return message['content']?.toString().trim() ?? '';
            }
          }
          return '';
        } else if (response.statusCode == 503) {
          if (i < retries - 1) {
            await Future.delayed(waitTime);
            waitTime = waitTime * 2;
            continue;
          }
          throw Exception('Model is still loading. Please try again later.');
        } else if (response.statusCode == 401) {
          throw Exception('Invalid API token. Check your HuggingFace token.');
        } else if (response.statusCode == 404 || response.statusCode == 410) {
          throw Exception('Chat endpoint not available for this model.');
        } else {
          final errorBody = response.body;
          throw Exception('API Error ${response.statusCode}: $errorBody');
        }
      } catch (e) {
        if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException')) {
          if (i < retries - 1) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception('Network error. Check internet connection.');
        }
        rethrow;
      }
    }

    throw Exception('Failed after $retries attempts');
  }

  /// Test if the API connection works
  Future<bool> testConnection() async {
    try {
      final response = await sendPrompt(
        'Respond with just "OK"',
        systemPrompt: 'You are a helpful assistant.',
      );
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

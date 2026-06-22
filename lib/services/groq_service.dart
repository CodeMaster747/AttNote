// services/groq_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin client for Groq's OpenAI-compatible chat completions API.
///
/// The key is read from `GROQ_API_KEY` in `.env`. On Flutter Web this key is
/// bundled into the shipped JS (accepted for this project). When no key is
/// configured, [isConfigured] is false and callers should fall back to their
/// deterministic behavior instead of calling [chat].
class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  String get _apiKey => dotenv.maybeGet('GROQ_API_KEY')?.trim() ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Send a single-turn chat. Returns the assistant text, or null on failure.
  /// When [json] is true, Groq is asked to return a strict JSON object.
  Future<String?> chat(
    String systemPrompt,
    String userPrompt, {
    bool json = false,
    double temperature = 0.4,
    int maxTokens = 1024,
  }) async {
    if (!isConfigured) return null;
    try {
      final body = <String, dynamic>{
        'model': _model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        if (json) 'response_format': {'type': 'json_object'},
      };

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('Groq error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;
      final content = choices.first['message']?['content'];
      return content is String ? content.trim() : null;
    } catch (e) {
      debugPrint('Groq request failed: $e');
      return null;
    }
  }

  /// Convenience: parse a JSON object response, tolerating code fences.
  Future<Map<String, dynamic>?> chatJson(
    String systemPrompt,
    String userPrompt, {
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    final raw = await chat(
      systemPrompt,
      userPrompt,
      json: true,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    if (raw == null) return null;
    return _tryParseJsonObject(raw);
  }

  static Map<String, dynamic>? _tryParseJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return null;
    try {
      return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Groq JSON parse failed: $e');
      return null;
    }
  }
}

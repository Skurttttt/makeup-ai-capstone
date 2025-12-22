import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<String> generateMakeupInstructions({
    required String skinTone,
    required String undertone,
    required String faceShape,
    required String lookName,
  }) async {
    if (apiKey.isEmpty) {
      // Return a safe fallback (so app doesn't crash)
      return 'AI is disabled (missing OPENAI_API_KEY). Using rule-based instructions.';
    }

    final prompt = '''
You are a makeup artist assistant.
Generate practical, step-by-step makeup instructions for a user with:
- skinTone: $skinTone
- undertone: $undertone
- faceShape: $faceShape
- lookName: $lookName

Rules:
- Output in 8–12 short steps.
- Be beginner-friendly.
- Include placement tips for blush/contour based on faceShape.
- Avoid brand names.
- Keep it concise and clear.
''';

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final body = {
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "system", "content": "You write clear makeup instructions."},
        {"role": "user", "content": prompt}
      ],
      "temperature": 0.6,
      "max_tokens": 300
    };

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return 'AI error ${res.statusCode}. Using rule-based instructions.';
    }

    final decoded = jsonDecode(res.body);
    final content = decoded["choices"][0]["message"]["content"];
    return (content is String) ? content.trim() : 'No AI content returned.';
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static const String _model = 'gpt-4o-mini';
  static const Duration _timeout = Duration(seconds: 30);

  static const List<String> _expectedTitles = [
    'Base Prep',
    'Eyebrows',
    'Eyeshadow',
    'Eyeliner',
    'Blush / Contour',
    'Lips',
    'Final Look',
  ];

  static const List<String> _expectedTargetAreas = [
    'full_face',
    'brows',
    'eyeshadow',
    'eyeliner',
    'blush_contour',
    'lips',
    'full_makeup',
  ];

  Future<List<Map<String, dynamic>>> generateMakeupInstructions({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) async {
    _logRequestStart();

    final fallback = _fallbackSteps(
      lookName: lookName,
      skinTone: skinTone,
      undertone: undertone,
      faceShape: faceShape,
    );

    if (apiKey.isEmpty) {
      debugPrint('OPENAI_API_KEY is missing. Using fallback steps.');
      return fallback;
    }

    try {
      final response = await _sendRequest(
        lookName: lookName,
        skinTone: skinTone,
        undertone: undertone,
        faceShape: faceShape,
      );

      debugPrint("===== OPENAI STATUS ===== ${response.statusCode}");
      debugPrint("===== FULL RESPONSE BODY =====");
      debugPrint(response.body);

      if (!_isSuccessfulStatus(response.statusCode)) {
        debugPrint('OpenAI request failed. Using fallback steps.');
        return fallback;
      }

      final steps = _parseAndNormalizeSteps(
        responseBody: response.body,
        fallback: fallback,
      );

      if (!_hasMeaningfulInstructions(steps)) {
        debugPrint('No meaningful instructions found. Using fallback steps.');
        return fallback;
      }

      debugPrint("===== FINAL STEPS =====");
      debugPrint(jsonEncode({"steps": steps}));

      return steps;
    } catch (e, stackTrace) {
      debugPrint('OpenAI error: $e');
      debugPrint(stackTrace.toString());
      return fallback;
    }
  }

  Future<http.Response> _sendRequest({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    final prompt = _buildPrompt(
      lookName: lookName,
      skinTone: skinTone,
      undertone: undertone,
      faceShape: faceShape,
    );

    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
              "You are a makeup tutorial generator that returns only valid JSON."
        },
        {"role": "user", "content": prompt}
      ],
      "temperature": 0.3,
      "max_tokens": 1200,
      "response_format": {"type": "json_object"},
    };

    return _client
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  String _buildPrompt({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    return '''
You are a professional makeup artist AI assistant.

Your task is to generate a personalized, beginner-friendly, step-by-step makeup tutorial.

Return ONLY valid JSON.
Do NOT include markdown.
Do NOT include explanations outside JSON.

FORMAT:
{
  "steps": [
    {
      "stepNumber": 1,
      "title": "...",
      "instruction": "...",
      "whyThisColorSuitsYou": "...",
      "targetArea": "..."
    }
  ]
}

RULES:
- EXACTLY 7 steps ONLY
- Follow EXACT order:
  1. Base Prep → full_face
  2. Eyebrows → brows
  3. Eyeshadow → eyeshadow
  4. Eyeliner → eyeliner
  5. Blush / Contour → blush_contour
  6. Lips → lips
  7. Final Look → full_makeup

PERSONALIZATION:
- Tailor each instruction based on:
  - lookName
  - skinTone
  - undertone
  - faceShape
- Adjust color suggestions based on undertone
- Adjust placement based on face shape
- Adjust intensity based on look style
- Vary wording naturally

WHY THIS SUITS YOU:
- Steps 1–6:
  Explain why the chosen COLOR or tone works for the user
- Step 7 (Final Look):
  Explain why the ENTIRE LOOK suits the user overall
  - Mention harmony of features
  - Balance with skin tone and undertone
  - Suitability to face shape
  - Overall vibe (soft, bold, natural, etc.)
- Use the same field name: "whyThisColorSuitsYou"
- Each explanation must be 1 sentence only
- Avoid generic phrases like "because it looks nice"

STYLE:
- Each instruction must be 1–2 sentences only
- Use simple, beginner-friendly language
- Be specific
- Avoid brand names

CONTEXT:
lookName: $lookName
skinTone: ${skinTone ?? "unknown"}
undertone: ${undertone ?? "unknown"}
faceShape: ${faceShape ?? "unknown"}

FINAL RULE:
Return ONLY JSON. No extra text.
''';
  }

  List<Map<String, dynamic>> _parseAndNormalizeSteps({
    required String responseBody,
    required List<Map<String, dynamic>> fallback,
  }) {
    final decoded = jsonDecode(responseBody);
    final content = decoded["choices"]?[0]?["message"]?["content"];

    debugPrint("===== RAW AI CONTENT =====");
    debugPrint(content?.toString() ?? 'null');

    if (content == null || content is! String || content.trim().isEmpty) {
      debugPrint('AI content is empty. Using fallback steps.');
      return fallback;
    }

    final cleaned = _cleanJsonString(content);

    debugPrint("===== CLEANED JSON =====");
    debugPrint(cleaned);

    if (cleaned.isEmpty) {
      debugPrint('Cleaned JSON is empty. Using fallback steps.');
      return fallback;
    }

    final parsed = jsonDecode(cleaned);

    if (parsed is! Map<String, dynamic>) {
      debugPrint('Parsed JSON is not a map. Using fallback steps.');
      return fallback;
    }

    final rawSteps = parsed['steps'];
    if (rawSteps is! List) {
      debugPrint('"steps" is missing or not a list. Using fallback steps.');
      return fallback;
    }

    return _normalizeSteps(
      rawSteps: rawSteps,
      fallback: fallback,
    );
  }

  List<Map<String, dynamic>> _normalizeSteps({
    required List rawSteps,
    required List<Map<String, dynamic>> fallback,
  }) {
    final steps = <Map<String, dynamic>>[];

    for (int i = 0; i < _expectedTitles.length; i++) {
      final item = i < rawSteps.length ? rawSteps[i] : null;

      final instruction = _readString(item, 'instruction').isNotEmpty
          ? _readString(item, 'instruction')
          : fallback[i]['instruction']!.toString();

      final whyThisColorSuitsYou =
          _readString(item, 'whyThisColorSuitsYou').isNotEmpty
              ? _readString(item, 'whyThisColorSuitsYou')
              : fallback[i]['whyThisColorSuitsYou']!.toString();

      steps.add({
        'stepNumber': i + 1,
        'title': _expectedTitles[i],
        'instruction': instruction,
        'whyThisColorSuitsYou': whyThisColorSuitsYou,
        'targetArea': _expectedTargetAreas[i],
      });
    }

    return steps;
  }

  String _readString(dynamic item, String key) {
    if (item is Map) {
      return item[key]?.toString().trim() ?? '';
    }
    return '';
  }

  bool _hasMeaningfulInstructions(List<Map<String, dynamic>> steps) {
    return steps.any(
      (step) => (step['instruction']?.toString().trim().isNotEmpty ?? false),
    );
  }

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  void _logRequestStart() {
    debugPrint('API KEY EMPTY: ${apiKey.isEmpty}');
    debugPrint(
      'API KEY PREFIX: ${apiKey.isNotEmpty ? apiKey.substring(0, 5) : "empty"}',
    );
    debugPrint('Calling OpenAI now...');
  }

  String _cleanJsonString(String input) {
    var cleaned = input.trim();

    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    cleaned = cleaned.trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      return '';
    }

    return cleaned.substring(firstBrace, lastBrace + 1).trim();
  }

  List<Map<String, dynamic>> _fallbackSteps({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    final look = lookName.toLowerCase();
    final tone = (skinTone ?? 'unknown').toLowerCase();
    final under = (undertone ?? 'neutral').toLowerCase();
    final shape = (faceShape ?? 'balanced').toLowerCase();

    final isSoft = look.contains('soft') || look.contains('glam');
    final isBold =
        look.contains('bold') || look.contains('editorial') || look.contains('emo');
    final isNatural = look.contains('natural') || look.contains('everyday');

    final intensityWord = isBold
        ? 'a more defined'
        : isNatural
            ? 'a very soft'
            : isSoft
                ? 'a soft-glam'
                : 'a balanced';

    final baseTone = _baseToneForUndertone(under);
    final lipTone = _lipToneForUndertone(under);
    final browTone = _browToneForSkinTone(tone);
    final blushPlacement = _blushPlacementForFaceShape(shape);
    final eyeshadowPlacement = _eyeshadowPlacementForFaceShape(shape);

    final baseWhy = _baseWhyForUndertone(under);
    final browWhy = _browWhyForSkinTone(tone);
    final eyeshadowWhy = _eyeshadowWhyForUndertone(under);

    final eyelinerWhy = isBold
        ? 'A stronger liner suits this look because your overall color direction is meant to feel more defined and expressive.'
        : 'A softer liner suits you here because it defines the eyes without competing with your natural balance.';

    final blushWhy = _blushWhyForFaceShape(shape);
    final lipsWhy = _lipsWhyForUndertone(under);

    final finalWhy = isBold
        ? 'This overall look suits you because the stronger contrast enhances your features while still staying aligned with your natural undertone and face structure.'
        : 'This overall look suits you because the tones, placement, and softness work together to enhance your natural features and facial balance.';

    return [
      {
        'stepNumber': 1,
        'title': 'Base Prep',
        'instruction':
            'Prep your full face with moisturizer and a light base for $intensityWord finish. Keep the layers thin and even so the skin looks smooth instead of heavy.',
        'whyThisColorSuitsYou': baseWhy,
        'targetArea': 'full_face',
      },
      {
        'stepNumber': 2,
        'title': 'Eyebrows',
        'instruction':
            'Fill your brows with a $browTone shade using small hair-like strokes. Brush through the front lightly so the brows stay soft and natural-looking.',
        'whyThisColorSuitsYou': browWhy,
        'targetArea': 'brows',
      },
      {
        'stepNumber': 3,
        'title': 'Eyeshadow',
        'instruction':
            'Apply a $baseTone eyeshadow across the lids, then add a slightly deeper shade to the crease for dimension. $eyeshadowPlacement',
        'whyThisColorSuitsYou': eyeshadowWhy,
        'targetArea': 'eyeshadow',
      },
      {
        'stepNumber': 4,
        'title': 'Eyeliner',
        'instruction': isBold
            ? 'Trace a more defined eyeliner close to the lash line and extend the outer edge slightly for extra shape. Keep both sides thin first, then build slowly.'
            : 'Trace a thin eyeliner close to the lash line to softly define the eyes. Keep the outer edge small and lifted for a clean beginner-friendly finish.',
        'whyThisColorSuitsYou': eyelinerWhy,
        'targetArea': 'eyeliner',
      },
      {
        'stepNumber': 5,
        'title': 'Blush / Contour',
        'instruction':
            'Use a $baseTone blush or contour tone very lightly so it complements your undertone. $blushPlacement',
        'whyThisColorSuitsYou': blushWhy,
        'targetArea': 'blush_contour',
      },
      {
        'stepNumber': 6,
        'title': 'Lips',
        'instruction':
            'Apply a $lipTone lip color, starting at the center and blending outward for better control. Add one more light layer if you want a more polished look.',
        'whyThisColorSuitsYou': lipsWhy,
        'targetArea': 'lips',
      },
      {
        'stepNumber': 7,
        'title': 'Final Look',
        'instruction':
            'Check the full makeup in good lighting and soften any harsh edges with a clean brush or sponge. Finish with powder or setting spray so the whole look stays neat and blended.',
        'whyThisColorSuitsYou': finalWhy,
        'targetArea': 'full_makeup',
      },
    ];
  }

  String _baseToneForUndertone(String under) {
    switch (under) {
      case 'warm':
        return 'golden or peach-toned';
      case 'cool':
        return 'rose, taupe, or cool-toned';
      case 'neutral':
        return 'soft neutral beige or mauve';
      default:
        return 'soft neutral';
    }
  }

  String _lipToneForUndertone(String under) {
    switch (under) {
      case 'warm':
        return 'peachy nude or warm rose';
      case 'cool':
        return 'pink nude or rosy mauve';
      case 'neutral':
        return 'neutral nude or muted pink';
      default:
        return 'soft nude';
    }
  }

  String _browToneForSkinTone(String tone) {
    switch (tone) {
      case 'light':
        return 'light brown';
      case 'medium':
        return 'medium brown';
      case 'tan':
        return 'deep brown';
      case 'deep':
        return 'rich deep brown';
      default:
        return 'natural brown';
    }
  }

  String _blushPlacementForFaceShape(String shape) {
    switch (shape) {
      case 'round':
        return 'Place blush slightly higher and blend upward toward the temples to create a lifted effect.';
      case 'square':
        return 'Blend blush softly on the outer cheeks and sweep it upward to soften strong angles.';
      case 'heart':
        return 'Keep blush slightly lower on the cheeks and blend outward for balance.';
      case 'oval':
        return 'Place blush on the apples of the cheeks and blend slightly upward for a naturally balanced finish.';
      default:
        return 'Place blush on the cheeks and blend outward and upward for a soft finish.';
    }
  }

  String _eyeshadowPlacementForFaceShape(String shape) {
    switch (shape) {
      case 'round':
        return 'Blend the outer corner slightly upward to elongate the eyes.';
      case 'square':
        return 'Keep the blending soft and rounded to balance sharper features.';
      case 'heart':
        return 'Focus a bit more color on the outer lid to add balance.';
      case 'oval':
        return 'Blend evenly across the lid and slightly into the crease for a balanced look.';
      default:
        return 'Blend softly across the lid and crease.';
    }
  }

  String _baseWhyForUndertone(String under) {
    switch (under) {
      case 'warm':
        return 'These warmer base tones blend more naturally into your complexion and keep your skin looking fresh instead of flat.';
      case 'cool':
        return 'These softer cool-beige tones suit your undertone and help the base look clean, balanced, and not too yellow.';
      case 'neutral':
        return 'These neutral base tones match your coloring well, so the skin looks even without feeling too warm or too pink.';
      default:
        return 'This balanced base tone helps your complexion look even and natural for the selected look.';
    }
  }

  String _browWhyForSkinTone(String tone) {
    switch (tone) {
      case 'light':
        return 'A lighter brown keeps your brows defined without overpowering your softer natural contrast.';
      case 'medium':
        return 'A medium brown gives enough definition while still blending naturally with your overall coloring.';
      case 'tan':
        return 'A deeper brown suits your skin depth better, so the brows stay visible and balanced on your face.';
      case 'deep':
        return 'A rich deep brown works better with your skin depth and keeps the brows strong without looking ashy.';
      default:
        return 'This brow tone keeps your features framed in a way that still looks natural on you.';
    }
  }

  String _eyeshadowWhyForUndertone(String under) {
    switch (under) {
      case 'warm':
        return 'These warm tones echo the natural warmth in your undertone, so the eyes look brighter and more harmonious.';
      case 'cool':
        return 'These cooler tones work better with your undertone and help the eye makeup look refined instead of muddy.';
      case 'neutral':
        return 'These neutral tones are flexible on your complexion, giving depth without pulling too warm or too cool.';
      default:
        return 'This eyeshadow tone gives your eyes dimension while staying flattering on your complexion.';
    }
  }

  String _blushWhyForFaceShape(String shape) {
    switch (shape) {
      case 'round':
        return 'This blush tone and lifted placement help add structure while still keeping the cheeks fresh and soft.';
      case 'square':
        return 'This softer blush direction helps balance stronger angles and gives the face a smoother finish.';
      case 'heart':
        return 'This tone and placement help keep the center of the face soft while balancing a wider upper face.';
      case 'oval':
        return 'This blush style works well on your proportions because it adds color without disrupting your natural balance.';
      default:
        return 'This blush tone adds healthy color while keeping the face soft and flattering.';
    }
  }

  String _lipsWhyForUndertone(String under) {
    switch (under) {
      case 'warm':
        return 'This lip shade complements the warmth in your complexion, so it looks lively and natural instead of too cool.';
      case 'cool':
        return 'This lip tone flatters your undertone by adding color in a way that feels polished and balanced.';
      case 'neutral':
        return 'This lip color suits you because neutral rosy tones usually stay flattering without overpowering your features.';
      default:
        return 'This lip shade adds enough color to enhance your face while still staying wearable.';
    }
  }
}
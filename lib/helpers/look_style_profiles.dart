enum MakeupMood {
  soft,
  bold,
  edgy,
  elegant,
  youthful,
  natural,
  warm,
}

class LookStyleProfile {
  final String id;
  final List<String> aliases;
  final MakeupMood mood;
  final bool highContrast;
  final double colorIntensity;

  final List<String> allowedKeywords;
  final List<String> avoidedKeywords;
  final List<String> preferredFinishes;

  const LookStyleProfile({
    required this.id,
    required this.aliases,
    required this.mood,
    required this.highContrast,
    required this.colorIntensity,
    required this.allowedKeywords,
    required this.avoidedKeywords,
    required this.preferredFinishes,
  });

  bool matches(String lookName) {
    final look = lookName.toLowerCase();
    return aliases.any((a) => look.contains(a.toLowerCase()));
  }
}

class LookStyleProfiles {
  static const List<LookStyleProfile> profiles = [
    LookStyleProfile(
      id: 'emo',
      aliases: ['emo', 'e-girl', 'egirl', 'grunge'],
      mood: MakeupMood.edgy,
      highContrast: true,
      colorIntensity: 0.95,
      allowedKeywords: [
        'wine',
        'berry',
        'dark berry',
        'black cherry',
        'plum',
        'mauve',
        'deep mauve',
        'beet',
        'beet rose',
        'ash rose',
        'smokey',
        'smoky',
        'gunmetal',
        'dark',
        'set 3',
      ],
      avoidedKeywords: [
        'mona lisa pink',
        'cute pink',
        'bright pink',
        'soft pink',
        'peach',
        'coral',
        'pastel',
        'milk tea',
        'warm peach',
        'soft coral',
      ],
      preferredFinishes: ['matte', 'velvet', 'soft matte'],
    ),

    LookStyleProfile(
      id: 'soft_glam',
      aliases: ['soft glam', 'bridal'],
      mood: MakeupMood.soft,
      highContrast: false,
      colorIntensity: 0.55,
      allowedKeywords: [
        'muted rose',
        'rosy nude',
        'warm peach',
        'champagne',
        'soft brown',
        'caramel nude',
        'dusty mauve',
        'beige nude',
        'rose',
      ],
      avoidedKeywords: [
        'gunmetal',
        'black cherry',
        'neon',
        'electric',
        'goth',
      ],
      preferredFinishes: ['natural', 'dewy', 'glossy', 'velvet'],
    ),

    LookStyleProfile(
      id: 'k_beauty',
      aliases: ['k-beauty', 'kbeauty', 'korean', 'doll k beauty'],
      mood: MakeupMood.youthful,
      highContrast: false,
      colorIntensity: 0.45,
      allowedKeywords: [
        'gradient pink',
        'soft coral',
        'peach nude',
        'milk tea',
        'soft rose',
        'cool pink',
        'rosy pink',
        'berry pink',
      ],
      avoidedKeywords: [
        'black cherry',
        'dark berry',
        'gunmetal',
        'smokey',
        'wine',
        'deep plum',
        'brown nude',
        'terracotta',
      ],
      preferredFinishes: ['glossy', 'natural', 'dewy'],
    ),

    LookStyleProfile(
      id: 'douyin',
      aliases: ['douyin', 'chinese idol'],
      mood: MakeupMood.bold,
      highContrast: true,
      colorIntensity: 0.80,
      allowedKeywords: [
        'cherry red',
        'cool pink',
        'rosewood',
        'muted plum',
        'berry pink',
        'rosy pink',
      ],
      avoidedKeywords: [
        'pastel peach',
        'warm brown',
        'terracotta',
        'orange coral',
      ],
      preferredFinishes: ['glossy', 'dewy', 'glass'],
    ),

    LookStyleProfile(
      id: 'editorial',
      aliases: ['editorial', 'bold editorial', 'bold glam'],
      mood: MakeupMood.bold,
      highContrast: true,
      colorIntensity: 1.0,
      allowedKeywords: [
        'electric',
        'royal plum',
        'metallic',
        'bronze',
        'graphite',
        'wine',
        'red',
        'berry',
        'plum',
      ],
      avoidedKeywords: [
        'barely there',
        'clear',
        'universal clear',
      ],
      preferredFinishes: ['metallic', 'glossy', 'matte'],
    ),

    LookStyleProfile(
      id: 'latte',
      aliases: ['latte', 'coffee', 'mocha'],
      mood: MakeupMood.elegant,
      highContrast: false,
      colorIntensity: 0.50,
      allowedKeywords: [
        'latte',
        'mocha',
        'warm nude',
        'coffee',
        'coffee beige',
        'brown',
        'brown nude',
        'caramel',
        'terracotta',
      ],
      avoidedKeywords: [
        'bright pink',
        'cool pink',
        'neon',
        'black cherry',
      ],
      preferredFinishes: ['soft matte', 'natural', 'velvet'],
    ),

    LookStyleProfile(
      id: 'old_money',
      aliases: ['old money', 'classic nude', 'quiet luxury'],
      mood: MakeupMood.elegant,
      highContrast: false,
      colorIntensity: 0.40,
      allowedKeywords: [
        'muted rose',
        'classic nude',
        'taupe',
        'elegant brown',
        'beige nude',
        'soft brown',
        'champagne',
      ],
      avoidedKeywords: [
        'neon',
        'bright coral',
        'electric',
        'hot pink',
      ],
      preferredFinishes: ['velvet', 'natural', 'soft matte'],
    ),

    LookStyleProfile(
      id: 'clean_girl',
      aliases: ['clean girl', 'glass skin', 'natural fresh'],
      mood: MakeupMood.natural,
      highContrast: false,
      colorIntensity: 0.35,
      allowedKeywords: [
        'beige nude',
        'muted rose',
        'soft peach',
        'rosy pink',
        'clear',
        'natural',
      ],
      avoidedKeywords: [
        'wine',
        'black cherry',
        'deep plum',
        'gunmetal',
        'smokey',
      ],
      preferredFinishes: ['dewy', 'natural', 'glossy'],
    ),

    LookStyleProfile(
      id: 'bronzed_goddess',
      aliases: ['bronzed', 'golden', 'bronzed goddess'],
      mood: MakeupMood.warm,
      highContrast: false,
      colorIntensity: 0.70,
      allowedKeywords: [
        'bronze',
        'golden',
        'terracotta',
        'caramel',
        'warm brown',
        'brown nude',
        'copper',
      ],
      avoidedKeywords: [
        'cool pink',
        'icy pink',
        'gunmetal',
      ],
      preferredFinishes: ['dewy', 'metallic', 'natural'],
    ),

    LookStyleProfile(
      id: 'cherry_cola',
      aliases: ['cherry cola'],
      mood: MakeupMood.bold,
      highContrast: true,
      colorIntensity: 0.90,
      allowedKeywords: [
        'cherry',
        'wine',
        'cola',
        'berry',
        'red brown',
        'black cherry',
      ],
      avoidedKeywords: [
        'peach',
        'coral',
        'milk tea',
        'cute pink',
      ],
      preferredFinishes: ['glossy', 'velvet', 'matte'],
    ),
  ];

  static LookStyleProfile? get(String lookName) {
    for (final profile in profiles) {
      if (profile.matches(lookName)) return profile;
    }
    return null;
  }
}
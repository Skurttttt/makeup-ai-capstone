class LookAreaPalette {
  final List<String> preferred;
  final List<String> acceptable;
  final List<String> forbidden;

  const LookAreaPalette({
    required this.preferred,
    this.acceptable = const [],
    this.forbidden = const [],
  });
}

class LookMasterPalette {
  final String id;
  final List<String> aliases;
  final Map<String, LookAreaPalette> areas;

  const LookMasterPalette({
    required this.id,
    required this.aliases,
    required this.areas,
  });

  bool matches(String lookName) {
    final look = lookName.toLowerCase();
    return aliases.any((a) => look.contains(a.toLowerCase()));
  }
}

class LookMasterPalettes {
  static const List<LookMasterPalette> palettes = [
    LookMasterPalette(
      id: 'soft_glam',
      aliases: ['soft glam', 'bridal glam'],
      areas: {
        'lips': LookAreaPalette(
          preferred: ['muted rose', 'rosy nude', 'peach nude', 'dusty mauve', 'diana', 'bliss'],
          acceptable: ['soft pink', 'rosy pink', 'beige nude'],
          forbidden: ['beet', 'berry', 'wine', 'black cherry', 'terracotta', 'dark brown'],
        ),
        'blush': LookAreaPalette(
          preferred: ['soft peach', 'muted rose', 'warm peach', 'mona lisa pink', 'melon crush'],
          acceptable: ['rosy pink', 'dusty mauve'],
          forbidden: ['beet', 'berry', 'wine', 'dark', 'plum'],
        ),
        'eyeshadow': LookAreaPalette(
          preferred: ['champagne', 'soft brown', 'warm brown', 'taupe', 'set 2'],
          acceptable: ['muted rose', 'dusty mauve', 'brown nude'],
          forbidden: ['set 3', 'gunmetal', 'black cherry', 'berry pink'],
        ),
      },
    ),

    LookMasterPalette(
      id: 'emo',
      aliases: ['emo', 'e-girl', 'egirl', 'grunge'],
      areas: {
        'lips': LookAreaPalette(
          preferred: ['wine red', 'black cherry', 'dark berry', 'plum', 'marilyn', 'taylor', 'britney', 'katy'],
          acceptable: ['berry pink', 'cool berry', 'mauve'],
          forbidden: ['soft pink', 'peach', 'coral', 'milk tea', 'nude', 'selena'],
        ),
        'blush': LookAreaPalette(
          preferred: ['beet rose', 'dark rose', 'mauve', 'muted berry'],
          acceptable: ['muted rose'],
          forbidden: ['mona lisa pink', 'soft peach', 'coral', 'bright pink'],
        ),
        'eyeshadow': LookAreaPalette(
          preferred: ['set 3', 'smokey', 'plum', 'dark brown', 'gunmetal'],
          acceptable: ['berry pink', 'mauve'],
          forbidden: ['set 1', 'soft peach', 'champagne', 'coral'],
        ),
      },
    ),

    LookMasterPalette(
      id: 'clean_girl',
      aliases: ['clean girl', 'glass skin', 'no makeup makeup'],
      areas: {
        'lips': LookAreaPalette(
          preferred: ['soft pink', 'muted rose', 'rosy nude', 'beige nude', 'bliss', 'diana'],
          acceptable: ['rosy pink', 'peach nude'],
          forbidden: ['wine', 'black cherry', 'dark berry', 'plum'],
        ),
        'blush': LookAreaPalette(
          preferred: ['soft peach', 'rosy pink', 'mona lisa pink', 'melon crush'],
          acceptable: ['muted rose'],
          forbidden: ['beet', 'wine', 'dark berry', 'terracotta'],
        ),
        'eyeshadow': LookAreaPalette(
          preferred: ['champagne', 'beige nude', 'soft brown', 'set 2'],
          acceptable: ['muted rose'],
          forbidden: ['set 3', 'gunmetal', 'black cherry'],
        ),
      },
    ),

    LookMasterPalette(
      id: 'k_beauty',
      aliases: ['k-beauty', 'kbeauty', 'korean', 'doll'],
      areas: {
        'lips': LookAreaPalette(
          preferred: ['gradient pink', 'soft pink', 'rosy pink', 'peach nude', 'selena', 'ariana'],
          acceptable: ['berry pink', 'cool pink'],
          forbidden: ['wine', 'black cherry', 'brown nude', 'terracotta'],
        ),
        'blush': LookAreaPalette(
          preferred: ['mona lisa pink', 'soft coral', 'soft peach', 'rosy pink'],
          acceptable: ['berry pink'],
          forbidden: ['beet', 'wine', 'terracotta', 'dark brown'],
        ),
        'eyeshadow': LookAreaPalette(
          preferred: ['soft rose', 'milk tea', 'champagne', 'set 2'],
          acceptable: ['rosy pink'],
          forbidden: ['set 3', 'smokey', 'gunmetal', 'dark brown'],
        ),
      },
    ),

    LookMasterPalette(
      id: 'latte',
      aliases: ['latte', 'latte makeup'],
      areas: {
        'lips': LookAreaPalette(
          preferred: ['brown nude', 'caramel nude', 'warm nude', 'coffee', 'dark choco'],
          acceptable: ['muted rose'],
          forbidden: ['bright pink', 'cool pink', 'berry pink'],
        ),
        'blush': LookAreaPalette(
          preferred: ['terracotta', 'warm brown', 'brown nude', 'melon crush'],
          acceptable: ['muted rose'],
          forbidden: ['cool pink', 'berry pink', 'bright pink'],
        ),
        'eyeshadow': LookAreaPalette(
          preferred: ['warm brown', 'brown nude', 'coffee', 'dark brown', 'set 1'],
          acceptable: ['set 2'],
          forbidden: ['berry pink', 'cool pink', 'set 3'],
        ),
      },
    ),
  ];

  static LookMasterPalette? get(String lookName) {
    for (final p in palettes) {
      if (p.matches(lookName)) return p;
    }
    return null;
  }
}
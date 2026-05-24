import 'look_style_profiles.dart';
import 'look_master_palette.dart'; // ADDED IMPORT

class ProductRecommendationEngine {
  static List<Map<String, dynamic>> recommendBestProducts({
    required List<Map<String, dynamic>> products,
    required String selectedLook,
    required String userUndertone,
    required String userShadeDepth,
    required String targetArea,
    required String preferredFinish,
    int limit = 2,
    Set<String>? alreadyUsedProductIds,
  }) {
    final scoredProducts = <Map<String, dynamic>>[];
    final usedIds = alreadyUsedProductIds ?? {};

    for (final product in products) {
      final categoryScore = _strictTargetAreaGate(
        product: product,
        targetArea: targetArea,
      );

      if (categoryScore <= -10000) continue;

      int score = categoryScore;

      final styleScore = _strictLookStyleScore(
        selectedLook: selectedLook,
        product: product,
      );

      if (styleScore <= -3000) continue;

      score += styleScore;

      // ADDED: Palette harmony scoring
      final harmonyScore = _paletteHarmonyScore(
        selectedLook: selectedLook,
        targetArea: targetArea,
        product: product,
      );

      if (harmonyScore <= -5000) continue;

      score += harmonyScore;

      score += _metadataScore(
        product: product,
        selectedLook: selectedLook,
        userUndertone: userUndertone,
        userShadeDepth: userShadeDepth,
        preferredFinish: preferredFinish,
      );

      final confidenceWeight =
          (product['confidence_weight'] as num?)?.toDouble() ?? 1.0;

      score = (score * confidenceWeight).round();

      final productId = product['id']?.toString();
      if (productId != null && usedIds.contains(productId)) {
        score -= 250;
      }

      scoredProducts.add({
        ...product,
        '_match_score': score,
      });
    }

    scoredProducts.sort(
      (a, b) => (b['_match_score'] as int).compareTo(a['_match_score'] as int),
    );

    return scoredProducts.take(limit).toList();
  }

  static int _strictTargetAreaGate({
    required Map<String, dynamic> product,
    required String targetArea,
  }) {
    final target = _field(product, 'target_area');
    final category = _field(product, 'category');
    final name = _field(product, 'name');

    if (target == targetArea) return 1000;

    bool match = false;

    switch (targetArea) {
      case 'lips':
        match = category.contains('lip') || name.contains('lip');
        break;

      case 'blush':
        match = category.contains('blush') || name.contains('blush');
        break;

      case 'contour':
        match = category.contains('contour') ||
            name.contains('contour') ||
            name.contains('multi palette') ||
            category.contains('palette');
        break;

      case 'eyeshadow':
        match = category.contains('eyeshadow') ||
            name.contains('eyeshadow') ||
            category.contains('palette');
        break;

      case 'eyeliner':
        match = category.contains('eyeliner') || name.contains('eyeliner');
        break;

      case 'brows':
        match = category.contains('brow') ||
            category.contains('eyebrow') ||
            name.contains('brow') ||
            name.contains('eyebrow');
        break;

      case 'primer':
        match = category.contains('primer') || name.contains('primer');
        break;

      case 'setting':
        match = category.contains('setting') ||
            category.contains('mist') ||
            name.contains('setting') ||
            name.contains('mist') ||
            name.contains('fix');
        break;

      case 'foundation':
        match = category.contains('foundation') || name.contains('foundation');
        break;

      case 'concealer':
        match = category.contains('concealer') || name.contains('concealer');
        break;

      case 'powder':
        match = category.contains('powder') || name.contains('powder');
        break;

      default:
        match = false;
    }

    if (!match) return -10000;

    return 300;
  }

  static int _strictLookStyleScore({
    required String selectedLook,
    required Map<String, dynamic> product,
  }) {
    final profile = LookStyleProfiles.get(selectedLook);
    if (profile == null) return 0;

    final text = _productText(product);

    final allowedHit = profile.allowedKeywords.any(
      (k) => text.contains(k.toLowerCase()),
    );

    final avoidedHit = profile.avoidedKeywords.any(
      (k) => text.contains(k.toLowerCase()),
    );

    int score = 0;

    if (avoidedHit) score -= 4000;
    if (allowedHit) {
      score += 1500;
    } else {
      score -= 700;
    }

    return score;
  }

  // ADDED: Palette harmony scoring method
  static int _paletteHarmonyScore({
    required String selectedLook,
    required String targetArea,
    required Map<String, dynamic> product,
  }) {
    final palette = LookMasterPalettes.get(selectedLook);
    if (palette == null) return 0;

    final area = palette.areas[targetArea];
    if (area == null) return 0;

    final text = _productText(product);

    final preferredHit = _hasAny(text, area.preferred);
    final acceptableHit = _hasAny(text, area.acceptable);
    final forbiddenHit = _hasAny(text, area.forbidden);

    if (forbiddenHit) return -6000;
    if (preferredHit) return 2200;
    if (acceptableHit) return 900;

    return -1800;
  }

  static int _metadataScore({
    required Map<String, dynamic> product,
    required String selectedLook,
    required String userUndertone,
    required String userShadeDepth,
    required String preferredFinish,
  }) {
    int score = 0;

    final compatibleLooks = _toList(
      product['compatible_looks_json'] ?? product['compatible_looks'],
    );

    final undertones = _toList(
      product['undertones'] ?? product['undertone'],
    );

    final skinTypes = _toList(
      product['skin_types'] ?? product['compatible_skin_type'],
    );

    final finishTypes = _toList(
      product['finish_types'] ?? product['finish_type'],
    );

    final shadeDepth = _field(product, 'shade_depth');

    final recommendationPriority =
        product['recommendation_priority'] as int? ?? 50;

    score += (recommendationPriority / 10).round();

    if (compatibleLooks.any((look) {
      return look.toLowerCase() == selectedLook.toLowerCase() ||
          selectedLook.toLowerCase().contains(look.toLowerCase()) ||
          look.toLowerCase().contains(selectedLook.toLowerCase());
    })) {
      score += 300;
    }

    if (userUndertone.isNotEmpty &&
        undertones.contains(userUndertone.toLowerCase())) {
      score += 80;
    }

    if (userShadeDepth.isNotEmpty &&
        _isShadeDepthMatch(userShadeDepth, shadeDepth)) {
      score += 70;
    }

    if (preferredFinish.isNotEmpty &&
        skinTypes.contains(preferredFinish.toLowerCase())) {
      score += 30;
    }

    if (preferredFinish.isNotEmpty &&
        finishTypes.contains(preferredFinish.toLowerCase())) {
      score += 30;
    }

    return score;
  }

  static bool _isShadeDepthMatch(String userShade, String productShade) {
    final user = userShade.toLowerCase();
    final product = productShade.toLowerCase();

    if (user == product) return true;

    if ((user.contains('fair') || user.contains('light')) &&
        (product.contains('fair') || product.contains('light'))) {
      return true;
    }

    if ((user.contains('medium') || user.contains('morena')) &&
        (product.contains('medium') || product.contains('morena'))) {
      return true;
    }

    if (user.contains('deep') && product.contains('deep')) {
      return true;
    }

    return false;
  }

  static String _field(Map<String, dynamic> product, String key) {
    return (product[key] ?? '').toString().toLowerCase().trim();
  }

  static String _productText(Map<String, dynamic> product) {
    return [
      product['name'],
      product['category'],
      product['target_area'],
      product['shade_name'],
      product['color_family'],
      product['finish_type'],
      product['compatible_looks'],
      product['compatible_looks_json'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  static List<String> _toList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) => e.toString().toLowerCase().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return value
        .toString()
        .split(',')
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ADDED: Helper method for keyword matching
  static bool _hasAny(String value, List<String> keywords) {
    final lower = value.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }
}
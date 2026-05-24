import 'look_style_profiles.dart';
import 'look_master_palette.dart';
import 'palette_mood_engine.dart';
import 'package:flutter/foundation.dart';

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
      // ADDED: Debug print before matching
      debugPrint(
        'CHECK PRODUCT: ${product['name']} | '
        'category=${product['category']} | '
        'target_area=${product['target_area']} | '
        'target_areas=${product['target_areas']} | '
        'wanted=$targetArea',
      );

      // Check if product matches the target area using the new helper
      if (!_matchesTargetArea(product, targetArea)) {
        debugPrint('  → REJECTED: does not match target area');
        continue;
      }

      debugPrint('  → ACCEPTED: matches target area');

      final categoryScore = _strictTargetAreaGate(
        product: product,
        targetArea: targetArea,
      );

      if (categoryScore <= -10000) {
        debugPrint('  → REJECTED: category score too low ($categoryScore)');
        continue;
      }

      int score = categoryScore;

      // REPLACED: Multi-palette detection logic
      final isMultiPalette = product['is_multi_palette'] == true ||
          (product['category']?.toString().toLowerCase().trim() == 'palette');

      final styleScore = _strictLookStyleScore(
        selectedLook: selectedLook,
        product: product,
      );

      // ADDED: Check if this is a support product (primer, setting, foundation, concealer, powder)
      final isSupportProduct = _isSupportProductTarget(targetArea);

      // Support products should NOT be killed by style gate
      if (!isSupportProduct && !isMultiPalette && styleScore <= -3000) {
        debugPrint('  → REJECTED: style score too low ($styleScore)');
        continue;
      }

      // Soften score for support products, clamp for multi-palette
      score += isSupportProduct
          ? 0
          : isMultiPalette
              ? styleScore.clamp(-800, 1200).toInt()
              : styleScore;

      // ADDED: Palette harmony scoring
      final harmonyScore = _paletteHarmonyScore(
        selectedLook: selectedLook,
        targetArea: targetArea,
        product: product,
      );

      if (harmonyScore <= -5000) {
        debugPrint('  → REJECTED: harmony score too low ($harmonyScore)');
        continue;
      }

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

      // ========== MULTI-PALETTE MOOD SCORING ==========
      // This upgrades palette products from single HEX matching
      // into full palette mood matching.
      final paletteMoodScore = PaletteMoodEngine.scoreProductForLook(
        product: product,
        selectedLook: selectedLook,
        targetArea: targetArea,
      );

      score += paletteMoodScore;

      score = (score * confidenceWeight).round();

      final productId = product['id']?.toString();
      if (productId != null && usedIds.contains(productId)) {
        score -= 250;
      }

      debugPrint('  → FINAL SCORE: $score');

      scoredProducts.add({
        ...product,
        '_match_score': score,
      });
    }

    scoredProducts.sort(
      (a, b) => (b['_match_score'] as int).compareTo(a['_match_score'] as int),
    );

    debugPrint('RECOMMENDATION RESULTS: ${scoredProducts.length} products scored');
    for (final p in scoredProducts.take(3)) {
      debugPrint('  - ${p['name']}: ${p['_match_score']}');
    }

    // Production fallback:
    // If strict AI scoring returns fewer than needed,
    // fill the missing slots with safe same-category products.
    if (scoredProducts.length < limit) {
      final existingIds = scoredProducts
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toSet();

      final fallbackProducts = _fallbackProductsForTargetArea(
        products: products,
        targetArea: targetArea,
        existingIds: existingIds,
        limit: limit - scoredProducts.length,
      );

      scoredProducts.addAll(fallbackProducts);
    }

    // REPLACED: Final return with palette-specific fallback
    final results = scoredProducts.take(limit).toList();

    // fallback: if strict scoring returns only 1 contour/eyeshadow palette,
    // allow another same-target palette as alternative
    if (results.length < limit &&
        (targetArea == 'contour' || targetArea == 'eyeshadow')) {
      final existingIds = results
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toSet();

      final fallbackPalettes = products.where((product) {
        final id = product['id']?.toString();
        final name = (product['name'] ?? '').toString().toLowerCase();
        final category = (product['category'] ?? '').toString().toLowerCase();
        final target = (product['target_area'] ?? '').toString().toLowerCase();

        if (id == null || existingIds.contains(id)) return false;
        if (product['is_active'] != true) return false;

        return target == targetArea ||
            category.contains('palette') ||
            name.contains('palette');
      }).map((p) => {
            ...p,
            '_match_score': 1,
            '_fallback_alternative': true,
          });

      results.addAll(fallbackPalettes.take(limit - results.length));
    }

    return results;
  }

  // ADDED: Check if target area is a support product
  static bool _isSupportProductTarget(String targetArea) {
    final target = targetArea.toLowerCase().trim();

    return target == 'primer' ||
        target == 'setting' ||
        target == 'foundation' ||
        target == 'concealer' ||
        target == 'powder' ||
        target == 'base';
  }

  // REPLACED: Target area matching helper with fuzzy matching for palette products
  static bool _matchesTargetArea(
    Map<String, dynamic> product,
    String targetArea,
  ) {
    final wanted = targetArea.toLowerCase().trim();

    final category =
        product['category']?.toString().toLowerCase().trim() ?? '';

    final singleTarget =
        product['target_area']?.toString().toLowerCase().trim() ?? '';

    final targetAreas = product['target_areas'];

    // New multi-target support with fuzzy matching
    if (targetAreas is List && targetAreas.isNotEmpty) {
      final match = targetAreas.any((area) {
        final normalized = area.toString().toLowerCase().trim();

        return normalized == wanted ||
            wanted.contains(normalized) ||
            normalized.contains(wanted);
      });

      if (match) return true;
    }

    if (singleTarget == wanted) return true;
    if (category == wanted) return true;

    // IMPORTANT:
    // Palette products can serve eyeshadow and contour
    if (category == 'palette') {
      return wanted.contains('eye') ||
          wanted.contains('shadow') ||
          wanted.contains('eyeshadow') ||
          wanted.contains('contour');
    }

    return false;
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

  // ADDED: Fallback products for target area
  static List<Map<String, dynamic>> _fallbackProductsForTargetArea({
    required List<Map<String, dynamic>> products,
    required String targetArea,
    required Set<String> existingIds,
    required int limit,
  }) {
    if (limit <= 0) return [];

    final wanted = targetArea.toLowerCase().trim();

    final fallback = products.where((product) {
      final id = product['id']?.toString();

      if (id == null || id.isEmpty) return false;
      if (existingIds.contains(id)) return false;
      if (product['is_active'] != true) return false;

      return _safeFallbackMatch(product, wanted);
    }).map((product) {
      final priority =
          (product['recommendation_priority'] as num?)?.toInt() ?? 50;

      return {
        ...product,
        '_match_score': priority,
        '_fallback_match': true,
      };
    }).toList();

    fallback.sort(
      (a, b) => (b['_match_score'] as int).compareTo(a['_match_score'] as int),
    );

    return fallback.take(limit).toList();
  }

  // ADDED: Safe fallback match for edge cases
  static bool _safeFallbackMatch(
    Map<String, dynamic> product,
    String targetArea,
  ) {
    final category = _field(product, 'category');
    final target = _field(product, 'target_area');
    final name = _field(product, 'name');

    final targetAreas = product['target_areas'];

    if (targetAreas is List && targetAreas.isNotEmpty) {
      final match = targetAreas.any((area) {
        final normalized = area.toString().toLowerCase().trim();

        return normalized == targetArea ||
            targetArea.contains(normalized) ||
            normalized.contains(targetArea);
      });

      if (match) return true;
    }

    if (target == targetArea) return true;
    if (category == targetArea) return true;

    switch (targetArea) {
      case 'primer':
        return category.contains('primer') ||
            category.contains('foundation') ||
            category.contains('concealer') ||
            target.contains('base') ||
            name.contains('primer') ||
            name.contains('foundation') ||
            name.contains('concealer');

      case 'setting':
        return category.contains('setting') ||
            category.contains('spray') ||
            category.contains('mist') ||
            name.contains('setting') ||
            name.contains('spray') ||
            name.contains('mist') ||
            name.contains('fix');

      case 'brows':
        return category.contains('brow') ||
            category.contains('eyebrow') ||
            name.contains('brow') ||
            name.contains('eyebrow');

      case 'eyeshadow':
        return category.contains('eyeshadow') ||
            category.contains('palette') ||
            name.contains('eyeshadow') ||
            name.contains('palette');

      case 'contour':
        return category.contains('contour') ||
            category.contains('palette') ||
            name.contains('contour') ||
            name.contains('palette');

      case 'blush':
        return category.contains('blush') ||
            name.contains('blush');

      case 'lips':
        return category.contains('lip') ||
            name.contains('lip');

      case 'eyeliner':
        return category.contains('eyeliner') ||
            name.contains('eyeliner') ||
            name.contains('liner');

      default:
        return false;
    }
  }

  static String _field(Map<String, dynamic> product, String key) {
    return (product[key] ?? '').toString().toLowerCase().trim();
  }

  // REPLACED: Enhanced _productText with multi-palette intelligence fields
  static String _productText(Map<String, dynamic> product) {
    return [
      product['name'],
      product['category'],
      product['target_area'],
      product['target_areas'],
      product['shade_name'],
      product['color_family'],
      product['finish_type'],
      product['compatible_looks'],
      product['compatible_looks_json'],

      // Multi-palette intelligence fields
      product['palette_mood'],
      product['palette_depth'],
      product['palette_hexes'],
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
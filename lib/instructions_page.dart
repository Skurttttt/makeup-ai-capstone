import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'look_engine.dart';
import 'config/makeup_look_config.dart';
import 'config/makeup_look_configs.dart';
import 'openai_service.dart';
import 'painters/base_prep_guide_painter.dart';
import 'painters/eyebrow_guide_painter.dart';
import 'painters/lip_guide_painter.dart';
import 'painters/eyeshadow_guide_painter.dart';
import 'painters/eyeliner_guide_painter.dart';
import 'home_screen.dart';
import 'screens/checkout_screen.dart';
import 'helpers/instructions_recommendation_helper.dart';
import 'widgets/instructions_support_widgets.dart';

// Widgets
import 'widgets/eyeshadow_guide_card.dart';
import 'widgets/eyeliner_guide_card.dart';
import 'widgets/blush_contour_guide_card.dart';
import 'widgets/final_look_guide_card.dart';
import 'widgets/base_prep_guide_card.dart';
import 'widgets/eyebrow_guide_card.dart';
import 'widgets/lip_guide_card.dart';

// ========== SKIN TYPE ENUM ==========
enum SkinType {
  oily,
  dry,
  combination,
  sensitive,
  normal,
}

class InstructionsPage extends StatefulWidget {
  final LookResult look;
  final FaceProfile? faceProfile;
  final String? scannedImagePath;
  final Face? detectedFace;
  final MakeupLookPreset selectedPreset;

  const InstructionsPage({
    super.key,
    required this.look,
    this.faceProfile,
    this.scannedImagePath,
    this.detectedFace,
    required this.selectedPreset,
  });

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  // AI-related state
  bool _loadingAI = false;
  String? _aiError;
  List<Map<String, dynamic>> _aiSteps = [];
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Guide generation state
  bool _generatingBasePrepGuide = false;
  bool _generatingEyebrowGuide = false;
  bool _generatingEyeshadowGuide = false;
  bool _generatingEyelinerGuide = false;
  bool _generatingLipGuide = false;
  
  String? _basePrepGuideImagePath;
  String? _eyebrowGuideImagePath;
  String? _eyeshadowGuideImagePath;
  String? _eyelinerGuideImagePath;
  String? _lipGuideImagePath;

  // Skin type state
  SkinType? _selectedSkinType;

  // Recommended kit state
  bool _buildingRecommendedKit = false;
  List<Map<String, dynamic>> _recommendedKitItems = [];
  final Map<String, Color> _recommendedStepColors = {};
  final Set<String> _prefetchedTargetAreas = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showSkinTypeSheet();

      await _lockMarketColorsForLook();

      await _generateAIInstructions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper method to show full instruction sheet
  void _showFullInstructionSheet({
    required String title,
    required String instruction,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3D93),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                instruction,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF33333A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to get skin type label
  String _skinTypeLabel(SkinType type) {
    switch (type) {
      case SkinType.oily:
        return 'Oily';
      case SkinType.dry:
        return 'Dry';
      case SkinType.combination:
        return 'Combination';
      case SkinType.sensitive:
        return 'Sensitive';
      case SkinType.normal:
        return 'Normal';
    }
  }

  Future<void> _lockMarketColorsForLook() async {
    const colorTargetAreas = [
      'eyeshadow',
      'blush_contour',
      'lips',
    ];

    for (final targetArea in colorTargetAreas) {
      try {
        final products = await _fetchRecommendedProducts(targetArea);

        if (products.isEmpty) continue;

        final bestProduct = products.first;
        final hex = bestProduct['hex_code']?.toString();
        final color = colorFromHex(hex);

        if (color == null) continue;

        _recommendedStepColors[targetArea] = color;
      } catch (e) {
        debugPrint('❌ Failed to lock market color for $targetArea: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _lipGuideImagePath = null;
      _eyeshadowGuideImagePath = null;
    });
  }

  String _detectRecommendedLipColorFamilyFromLook(String lookName) {
    final look = lookName.toLowerCase();

    if (look.contains('peach')) {
      return 'soft peach';
    }

    if (look.contains('clean girl') || look.contains('glass skin')) {
      return 'muted rose';
    }

    if (look.contains('douyin') || look.contains('k-beauty')) {
      return 'rosy pink';
    }

    if (look.contains('soft glam')) {
      return 'muted rose';
    }

    if (look.contains('latte') || look.contains('old money')) {
      return 'brown nude';
    }

    if (look.contains('bronzed') || look.contains('golden')) {
      return 'terracotta';
    }

    if (look.contains('emo') || look.contains('e-girl')) {
      return 'cool berry';
    }

    if (look.contains('cherry cola')) {
      return 'wine red';
    }

    if (look.contains('cold girl') || look.contains('monochrome pink')) {
      return 'cool pink';
    }

    if (look.contains('bridal')) {
      return 'muted rose';
    }

    if (look.contains('arab') || look.contains('party')) {
      return 'wine red';
    }

    return 'rosy pink';
  }

  Future<List<Map<String, dynamic>>> _fetchRecommendedProducts(
    String targetArea,
  ) async {
    final category = categoryForTargetArea(targetArea);
    final selectedLook = widget.look.lookName.toLowerCase();

    final selectedSkinType = _selectedSkinType == null
        ? ''
        : _skinTypeLabel(_selectedSkinType!).toLowerCase();

    final detectedUndertone =
        widget.faceProfile?.undertone.name.toLowerCase() ?? '';

    final userSkinTone =
        widget.faceProfile?.skinTone.name.toLowerCase() ?? '';

    final response = await Supabase.instance.client
        .from('products')
        .select()
        .eq('is_active', true);

    final products = List<Map<String, dynamic>>.from(response);

    final categoryFilteredProducts = products.where((product) {
      final productCategory =
          (product['category'] ?? '').toString().toLowerCase();

      final requiredCategory = category.toLowerCase();

      if (targetArea == 'full_face') {
        return productCategory.contains('primer') ||
            productCategory.contains('foundation') ||
            productCategory.contains('concealer') ||
            productCategory.contains('cushion') ||
            productCategory.contains('skin tint');
      }

      if (targetArea == 'eyeshadow') {
        return productCategory.contains('eyeshadow') ||
            productCategory.contains('palette');
      }

      if (targetArea == 'blush_contour') {
        return productCategory.contains('blush') ||
            productCategory.contains('contour');
      }

      if (targetArea == 'lips') {
        return productCategory.contains('lipstick') ||
            productCategory.contains('lip tint') ||
            productCategory.contains('lip gloss') ||
            productCategory.contains('lip');
      }

      return productCategory.contains(requiredCategory);
    }).toList();

    final preferredFamily = preferredColorFamilyForLook(
      lookName: widget.look.lookName,
      targetArea: targetArea,
    );

    final scoredProducts = categoryFilteredProducts.map((product) {
      int score = 0;

      final compatibleLooks =
          (product['compatible_looks'] ?? '').toString().toLowerCase();

      final compatibleSkinType =
          (product['compatible_skin_type'] ?? '').toString().toLowerCase();

      final undertone =
          (product['undertone'] ?? '').toString().toLowerCase();

      final shadeDepth =
          (product['shade_depth'] ?? '').toString().toLowerCase();

      final colorFamily =
          (product['color_family'] ?? '').toString().toLowerCase();

      final productHex =
          (product['hex_code'] ?? '').toString().trim();

      score += 10;

      // Compatible looks is now only secondary.
      if (targetArea == 'lips') {
        if (compatibleLooks.contains(selectedLook)) {
          score += 1;
        }
      } else {
        if (compatibleLooks.contains(selectedLook)) {
          score += 4;
        }
      }

      if (preferredFamily.isNotEmpty) {
        if (colorFamily.contains(preferredFamily.toLowerCase()) ||
            preferredFamily.toLowerCase().contains(colorFamily)) {
          score += 80;
        } else {
          score -= 30;
        }
      }

      if (selectedSkinType.isNotEmpty &&
          compatibleSkinType.contains(selectedSkinType)) {
        score += 3;
      }

      if (detectedUndertone.isNotEmpty &&
          undertone.contains(detectedUndertone)) {
        score += 2;
      }

      if (userSkinTone.isNotEmpty && shadeDepth.isNotEmpty) {
        if (skinToneMatchesShadeDepth(userSkinTone, shadeDepth)) {
          score += 3;
        }
      }

      if (targetArea == 'lips') {
        final recommendedLipHex =
            hexFromColor(widget.look.lipstickColor);

        score += lipstickStrictScore(
          product: product,
          lookName: widget.look.lookName,
          recommendedHex: recommendedLipHex,
          recommendedColorFamily: preferredFamily,
          userUndertone: detectedUndertone,
          userSkinType: selectedSkinType,
          userShadeDepth: userSkinTone,
        ).toInt();
      } else {
        score += lookColorFamilyScore(
          lookName: widget.look.lookName,
          targetArea: targetArea,
          colorFamily: colorFamily,
        );

        // Product HEX should exist for color-based areas.
        if ((targetArea == 'eyeshadow' ||
                targetArea == 'blush_contour') &&
            productHex.isEmpty) {
          score -= 100;
        }
      }

      return {
        ...product,
        '_match_score': score,
      };
    }).toList();

    scoredProducts.sort((a, b) {
      return (b['_match_score'] as int).compareTo(a['_match_score'] as int);
    });

    final bestProducts = scoredProducts.take(2).toList();

    // MARKET COLOR LOCKING:
    // The first/best product HEX becomes the official color.
    if (bestProducts.isNotEmpty) {
      final bestHex = bestProducts.first['hex_code']?.toString();
      final bestColor = colorFromHex(bestHex);

      if (bestColor != null) {
        _recommendedStepColors[targetArea] = bestColor;
      }
    }

    return bestProducts;
  }

  Future<void> _prefetchRecommendedProductColor(String targetArea) async {
    if (_prefetchedTargetAreas.contains(targetArea)) return;

    _prefetchedTargetAreas.add(targetArea);

    try {
      final products = await _fetchRecommendedProducts(targetArea);

      if (products.isEmpty) return;

      final bestProduct = products.first;
      final hex = bestProduct['hex_code']?.toString();
      final color = colorFromHex(hex);

      if (color == null) return;

      if (!mounted) return;

      setState(() {
        _recommendedStepColors[targetArea] = color;

        // Force regenerate guide image if color changed
        if (targetArea == 'lips') {
          _lipGuideImagePath = null;
        }

        if (targetArea == 'eyeshadow') {
          _eyeshadowGuideImagePath = null;
        }

        if (targetArea == 'blush_contour') {
          // Blush contour uses FutureBuilder directly, no cached path here
        }
      });

      _ensureGuideForTargetArea(targetArea);
    } catch (e) {
      debugPrint('❌ Product color prefetch failed for $targetArea: $e');
    }
  }

  // Skin type selection modal
  Future<void> _showSkinTypeSheet() async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ Personalize Your Recommendations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF3D93),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'What’s your skin type?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF66666E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: SkinType.values.map((type) {
                      final selected = _selectedSkinType == type;

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _selectedSkinType = type;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFF3D93)
                                : const Color(0xFFFFF1F6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFF3D93)
                                  : const Color(0xFFFFD3E5),
                            ),
                          ),
                          child: Text(
                            _skinTypeLabel(type),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFFF3D93),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedSkinType == null
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3D93),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateAIInstructions() async {
    debugPrint('🔥 AI TRIGGERED');

    setState(() {
      _loadingAI = true;
      _aiError = null;
    });

    try {
      final steps = await OpenAIService().generateMakeupInstructions(
        lookName: widget.look.lookName,
        skinTone: widget.faceProfile?.skinTone.name,
        undertone: widget.faceProfile?.undertone.name,
        faceShape: widget.faceProfile?.faceShape.name,
      );

      debugPrint('🔥 AI STEPS RECEIVED: ${steps.length}');

      setState(() {
        _aiSteps = steps;
      });

      // Trigger Step 1 guide after AI loads
      _ensureGuideForTargetArea('full_face');
    } catch (e) {
      debugPrint('❌ AI ERROR: $e');

      setState(() {
        _aiError = e.toString();
      });
    } finally {
      setState(() {
        _loadingAI = false;
      });
    }
  }

  MakeupLookConfig get _config => MakeupLookConfigs.get(widget.selectedPreset);

  Future<String> _createGuideImage({
    required String prefix,
    required CustomPainter painter,
  }) async {
    if (widget.scannedImagePath == null) {
      throw Exception('No scanned image path found.');
    }

    final image = await _loadUiImageFromFile(widget.scannedImagePath!);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImage(image, Offset.zero, Paint());
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final guideImage = await picture.toImage(image.width, image.height);

    final byteData = await guideImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to encode guide image.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp(prefix);
    final file = File('${dir.path}/guide.png');

    await file.writeAsBytes(pngBytes, flush: true);

    return file.path;
  }

  Future<void> _ensureBasePrepGuideGenerated() async {
    if (_basePrepGuideImagePath != null || _generatingBasePrepGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingBasePrepGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'base_prep_guide_',
        painter: BasePrepGuidePainter(
          face: widget.detectedFace!,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() {
        _basePrepGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingBasePrepGuide = false);
      }
    }
  }

  Future<void> _ensureEyebrowGuideGenerated() async {
    if (_eyebrowGuideImagePath != null || _generatingEyebrowGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyebrowGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'eyebrow_guide_',
        painter: EyebrowGuidePainter(
          face: widget.detectedFace!,
          preset: widget.selectedPreset,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() {
        _eyebrowGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingEyebrowGuide = false);
      }
    }
  }

  Future<void> _ensureLipGuideGenerated() async {
    if (_lipGuideImagePath != null || _generatingLipGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingLipGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'lip_guide_',
        painter: LipGuidePainter(
          face: widget.detectedFace!,
          preset: widget.selectedPreset,
          lipColor: _recommendedStepColors['lips']!,
        ),
      );

      if (!mounted) return;

      setState(() {
        _lipGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingLipGuide = false);
      }
    }
  }

  Future<void> _ensureEyeshadowGuideGenerated() async {
    if (_eyeshadowGuideImagePath != null || _generatingEyeshadowGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyeshadowGuide = true);

    try {
      final eyeshadowColor = _recommendedStepColors['eyeshadow']!;
      
      final path = await _createGuideImage(
        prefix: 'eyeshadow_guide_',
        painter: EyeshadowGuidePainter(
          face: widget.detectedFace!,
          config: _config,
          palette: EyeshadowGuidePalette(
            lidColor: eyeshadowColor.withOpacity(0.95),
            creaseColor: eyeshadowColor.withOpacity(0.75),
            outerColor: eyeshadowColor.withOpacity(1.0),
            guideColor: const Color(0xFFFF4D97),
          ),
        ),
      );

      if (!mounted) return;

      setState(() => _eyeshadowGuideImagePath = path);
    } finally {
      if (mounted) {
        setState(() => _generatingEyeshadowGuide = false);
      }
    }
  }

  Future<void> _ensureEyelinerGuideGenerated() async {
    if (_eyelinerGuideImagePath != null || _generatingEyelinerGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyelinerGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'eyeliner_guide_',
        painter: EyelinerGuidePainter(
          face: widget.detectedFace!,
          config: _config,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() => _eyelinerGuideImagePath = path);
    } finally {
      if (mounted) {
        setState(() => _generatingEyelinerGuide = false);
      }
    }
  }

  Map<String, dynamic> _getAiStepForFixedStep(int stepNumber, String targetArea) {
    try {
      return _aiSteps.firstWhere(
        (s) =>
            s['stepNumber'] == stepNumber ||
            s['stepNumber']?.toString() == stepNumber.toString() ||
            s['targetArea'] == targetArea,
      );
    } catch (_) {
      return {};
    }
  }

  String _cleanWhyText(String raw, String targetArea) {
    final text = raw.trim();

    if (text.isEmpty || text.contains('Color(') || text.contains('colorSpace')) {
      if (targetArea == 'blush_contour') {
        return 'This blush and contour placement helps add warmth, shape, and soft dimension to your face.';
      }

      if (targetArea == 'eyeshadow') {
        return 'This eyeshadow placement helps add soft depth while keeping the look balanced and wearable.';
      }

      if (targetArea == 'eyeliner') {
        return 'This eyeliner shape helps define your eyes while matching the overall style of the look.';
      }

      if (targetArea == 'lips') {
        return 'This lip color helps balance the look and complements your natural skin tone.';
      }

      if (targetArea == 'full_makeup') {
        return 'This final look brings all the colors and placements together for a balanced finish.';
      }

      return '';
    }

    return text;
  }

  void _ensureGuideForTargetArea(String targetArea) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchRecommendedProductColor(targetArea);

      if (targetArea == 'full_face') _ensureBasePrepGuideGenerated();
      if (targetArea == 'brows') _ensureEyebrowGuideGenerated();
      if (targetArea == 'eyeshadow') _ensureEyeshadowGuideGenerated();
      if (targetArea == 'eyeliner') _ensureEyelinerGuideGenerated();
      if (targetArea == 'lips') _ensureLipGuideGenerated();
    });
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _showInfoSheet({
    required String title,
    required String description,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3D93),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF33333A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductRecommendationSheet(String targetArea) {
    final skinTypeText = _selectedSkinType == null
        ? 'your selected skin type'
        : _skinTypeLabel(_selectedSkinType!);

    final undertoneText =
        widget.faceProfile?.undertone.name ?? 'your detected undertone';

    final lookText = widget.look.lookName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRecommendedProducts(targetArea),
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final products = snapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF3D93),
                        ),
                      ),
                    )
                  : products.isEmpty
                      ? const Text(
                          'No matching products found yet.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Recommended Product',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF171725),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Matched to your $undertoneText undertone, $skinTypeText skin, and $lookText look.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF777780),
                              ),
                            ),
                            const SizedBox(height: 16),

                            ...products.asMap().entries.map((entry) {
                              final index = entry.key;
                              final product = entry.value;
                              final name = product['name']?.toString() ?? 'Product';
                              final shade = product['shade_name']?.toString() ?? '';
                              final price = product['price']?.toString() ?? '';
                              final imageUrl = product['image_url']?.toString() ?? '';
                              // ignore: unused_local_variable
                              final matchScore = product['_match_score']?.toString() ?? '';
                              final matchLabel = index == 0 ? 'BEST MATCH' : 'ALTERNATIVE';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7FA),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFFFD8E8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: 58,
                                              height: 58,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 58,
                                              height: 58,
                                              color: const Color(0xFFFFE5F0),
                                              child: const Icon(
                                                Icons.shopping_bag_outlined,
                                                color: Color(0xFFFF3D93),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            matchLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: index == 0
                                                  ? const Color(0xFFFF3D93)
                                                  : const Color(0xFF777780),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (shade.isNotEmpty)
                                            Text(
                                              'Shade: $shade',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF777780),
                                              ),
                                            ),
                                          const Text(
                                            'AI match based on your look, skin type, and undertone',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFFF3D93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      price.isEmpty ? '' : '₱$price',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFF3D93),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuideWidgetForTargetArea({
    required String targetArea,
  }) {
    if (targetArea == 'full_face') {
      if (_generatingBasePrepGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_basePrepGuideImagePath != null) {
        return BasePrepGuideCard(
          imagePath: _basePrepGuideImagePath!,
        );
      }
    }

    if (targetArea == 'brows') {
      if (_generatingEyebrowGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_eyebrowGuideImagePath != null) {
        return EyebrowGuideCard(
          imagePath: _eyebrowGuideImagePath!,
        );
      }
    }

    if (targetArea == 'eyeshadow') {
      if (_generatingEyeshadowGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_eyeshadowGuideImagePath != null) {
        return FutureBuilder<ui.Image>(
          future: _loadUiImageFromFile(_eyeshadowGuideImagePath!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return EyeshadowGuideCard(
              face: widget.detectedFace!,
              config: _config,
              image: snapshot.data!,
            );
          },
        );
      }
    }

    if (targetArea == 'eyeliner') {
      if (_generatingEyelinerGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_eyelinerGuideImagePath != null) {
        return FutureBuilder<ui.Image>(
          future: _loadUiImageFromFile(_eyelinerGuideImagePath!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return EyelinerGuideCard(
              face: widget.detectedFace!,
              config: _config,
              image: snapshot.data!,
            );
          },
        );
      }
    }

    if (targetArea == 'blush_contour') {
      if (widget.detectedFace != null && widget.scannedImagePath != null) {
        return FutureBuilder<ui.Image>(
          future: _loadUiImageFromFile(widget.scannedImagePath!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return BlushContourGuideCard(
              face: widget.detectedFace!,
              config: _config,
              image: snapshot.data!,
              blushColor: _recommendedStepColors['blush_contour']!,
            );
          },
        );
      }
    }

    if (targetArea == 'lips') {
      if (_generatingLipGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_lipGuideImagePath != null) {
        return LipGuideCard(
          imagePath: _lipGuideImagePath!,
        );
      }
    }

    if (targetArea == 'full_makeup') {
      if (widget.detectedFace != null && widget.scannedImagePath != null) {
        return FutureBuilder<ui.Image>(
          future: _loadUiImageFromFile(widget.scannedImagePath!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return FinalLookGuideCard(
              face: widget.detectedFace!,
              image: snapshot.data!,
            );
          },
        );
      }
    }

    return const Center(child: CircularProgressIndicator());
  }

  // Recommended kit methods
  Future<void> _buildFinalRecommendedKit() async {
    if (_buildingRecommendedKit) return;

    setState(() => _buildingRecommendedKit = true);

    try {
      const targetAreas = [
        'full_face',
        'brows',
        'eyeshadow',
        'eyeliner',
        'blush_contour',
        'lips',
        'full_makeup',
      ];

      final Map<String, Map<String, dynamic>> uniqueProducts = {};

      for (final targetArea in targetAreas) {
        final products = await _fetchRecommendedProducts(targetArea);

        if (products.isEmpty) continue;

        final bestMatch = products.first;
        final productId = bestMatch['id']?.toString();

        if (productId == null || productId.isEmpty) continue;
        if (uniqueProducts.containsKey(productId)) continue;

        uniqueProducts[productId] = {
          ...bestMatch,
          'quantity': 1,
          'variation': {
            'color_name': bestMatch['shade_name'],
            'hex_code': bestMatch['hex_code'],
          },
        };
      }

      if (!mounted) return;

      setState(() {
        _recommendedKitItems = uniqueProducts.values.toList();
      });

      _showFinalRecommendedKitSheet();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to build recommended kit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _buildingRecommendedKit = false);
      }
    }
  }

  void _showFinalRecommendedKitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double subtotal = _recommendedKitItems.fold(
              0.0,
              (sum, item) {
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final qty = item['quantity'] as int? ?? 1;
                return sum + (price * qty);
              },
            );

            void updateQty(int index, int change) {
              final currentQty = _recommendedKitItems[index]['quantity'] as int? ?? 1;
              final newQty = currentQty + change;

              if (newQty < 0) return;

              if (newQty == 0) {
                setModalState(() {
                  _recommendedKitItems[index]['quantity'] = 0;
                });
                setState(() {});
              } else {
                setModalState(() {
                  _recommendedKitItems[index]['quantity'] = newQty;
                });
                setState(() {});
              }
            }

            // Filter out items with quantity 0 for checkout
            final checkoutItems = _recommendedKitItems
                .where((item) => (item['quantity'] as int? ?? 0) > 0)
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD3E5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        '✨ Your AI Recommended Kit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF3D93),
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Best-match products from your full makeup guide.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF777780),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: _recommendedKitItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'No recommended products found yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _recommendedKitItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _recommendedKitItems[index];

                                  final name =
                                      item['name']?.toString() ?? 'Product';
                                  final shade =
                                      item['shade_name']?.toString() ?? '';
                                  final imageUrl =
                                      item['image_url']?.toString() ?? '';
                                  final price =
                                      (item['price'] as num?)?.toDouble() ?? 0.0;
                                  final qty = item['quantity'] as int? ?? 1;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: qty == 0
                                          ? const Color(0xFFF5F5F5)
                                          : const Color(0xFFFFF7FA),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: qty == 0
                                            ? const Color(0xFFE0E0E0)
                                            : const Color(0xFFFFD8E8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                  color: qty == 0
                                                      ? Colors.black.withOpacity(0.3)
                                                      : null,
                                                  colorBlendMode: qty == 0
                                                      ? BlendMode.darken
                                                      : null,
                                                )
                                              : Container(
                                                  width: 64,
                                                  height: 64,
                                                  color: qty == 0
                                                      ? const Color(0xFFE0E0E0)
                                                      : const Color(0xFFFFE5F0),
                                                  child: Icon(
                                                    Icons.shopping_bag_outlined,
                                                    color: qty == 0
                                                        ? Colors.grey
                                                        : const Color(0xFFFF3D93),
                                                  ),
                                                ),
                                        ),

                                        const SizedBox(width: 12),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'BEST MATCH',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFFF3D93),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: qty == 0
                                                      ? Colors.grey
                                                      : const Color(0xFF171725),
                                                ),
                                              ),
                                              if (shade.isNotEmpty)
                                                Text(
                                                  'Shade: $shade',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: qty == 0
                                                        ? Colors.grey
                                                        : const Color(0xFF777780),
                                                  ),
                                                ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '₱${price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: qty == 0
                                                      ? Colors.grey
                                                      : const Color(0xFFFF3D93),
                                                ),
                                              ),
                                              if (qty == 0)
                                                const Text(
                                                  'Removed from checkout',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        Row(
                                          children: [
                                            KitQtyButton(
                                              icon: Icons.remove,
                                              onTap: () => updateQty(index, -1),
                                              isDisabled: qty == 0,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Text(
                                                qty.toString(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: qty == 0
                                                      ? Colors.grey
                                                      : const Color(0xFF171725),
                                                ),
                                              ),
                                            ),
                                            KitQtyButton(
                                              icon: Icons.add,
                                              onTap: () => updateQty(index, 1),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF55555F),
                                  ),
                                ),
                                Text(
                                  '₱${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF171725),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF171725),
                                  ),
                                ),
                                Text(
                                  '₱${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF3D93),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: checkoutItems.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context);

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(
                                        cartItems: checkoutItems,
                                        onCheckoutComplete: () {
                                          setState(() {
                                            _recommendedKitItems.clear();
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.shopping_cart_checkout_rounded),
                          label: Text(
                            checkoutItems.isEmpty
                                ? 'No items selected'
                                : 'Checkout (${checkoutItems.length} items)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3D93),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFFF3D93).withOpacity(0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAIStepsPager() {
    const fixedStepOrder = [
      {
        'stepNumber': 1,
        'title': 'Base Prep',
        'targetArea': 'full_face',
        'fallbackInstruction':
            'Prep your skin by priming the T-zone, hydrating the cheeks, and brightening the under-eye area.',
      },
      {
        'stepNumber': 2,
        'title': 'Eyebrows',
        'targetArea': 'brows',
        'fallbackInstruction':
            'Define your brows softly by following your natural brow shape.',
      },
      {
        'stepNumber': 3,
        'title': 'Eyeshadow',
        'targetArea': 'eyeshadow',
        'fallbackInstruction':
            'Apply the main shade on the lid, blend the crease, then add depth to the outer corner.',
      },
      {
        'stepNumber': 4,
        'title': 'Eyeliner',
        'targetArea': 'eyeliner',
        'fallbackInstruction':
            'Draw close to the upper lash line, connect the outer edge, then flick outward for the wing.',
      },
      {
        'stepNumber': 5,
        'title': 'Blush / Contour',
        'targetArea': 'blush_contour',
        'fallbackInstruction':
            'Apply blush on the upper cheek area, then contour lightly below the cheekbone for shape.',
      },
      {
        'stepNumber': 6,
        'title': 'Lips',
        'targetArea': 'lips',
        'fallbackInstruction':
            'Apply your lip color from the center outward and blend evenly for a polished finish.',
      },
      {
        'stepNumber': 7,
        'title': 'Final Look',
        'targetArea': 'full_makeup',
        'fallbackInstruction':
            'Set your makeup with a light spray using X and T motion, then check the final blend.',
      },
    ];

    if (_loadingAI && _aiSteps.isEmpty) {
      return AiTutorialLoadingView(lookName: widget.look.lookName);
    }

    if (_aiError != null) {
      return Center(
        child: Text(
          _aiError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_aiSteps.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            children: [
              const SizedBox(height: 4),

              const Text(
                '✨ AI Personalized Guide ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF3D93),
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 7,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);

                    final fixedStep = fixedStepOrder[index];
                    _ensureGuideForTargetArea(
                      fixedStep['targetArea'].toString(),
                    );
                  },
                  itemBuilder: (context, index) {
                    final fixedStep = fixedStepOrder[index];

                    final stepNumber = fixedStep['stepNumber'].toString();
                    final title = fixedStep['title'].toString();
                    final targetArea = fixedStep['targetArea'].toString();

                    final aiStep = _getAiStepForFixedStep(index + 1, targetArea);

                    final instruction =
                        aiStep['instruction']?.toString() ??
                        fixedStep['fallbackInstruction'].toString();

                    final whyThisColorSuitsYou = _cleanWhyText(
                      aiStep['whyThisColorSuitsYou']?.toString() ?? '',
                      targetArea,
                    );

                    _ensureGuideForTargetArea(targetArea);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          InstructionCard(
                            stepNumber: stepNumber,
                            title: title,
                            instruction: instruction,
                            onTap: () {
                              _showFullInstructionSheet(
                                title: 'Step $stepNumber • $title',
                                instruction: instruction,
                              );
                            },
                          ),

                          const SizedBox(height: 3),

                          Flexible(
                            fit: FlexFit.tight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: GuideCardShell(
                                    child: _buildGuideWidgetForTargetArea(
                                      targetArea: targetArea,
                                    ),
                                  ),
                                ),

                                Positioned(
                                  right: 7,
                                  top: 4,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FloatingMiniButton(
                                        icon: Icons.lightbulb_rounded,
                                        size: 34,
                                        onTap: () {
                                          _showInfoSheet(
                                            title: 'Tip',
                                            description: tipForTargetArea(targetArea),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 4),

                                      FloatingMiniButton(
                                        icon: Icons.palette_rounded,
                                        size: 34,
                                        onTap: () {
                                          _showInfoSheet(
                                            title: targetArea == 'full_makeup'
                                                ? 'Why this look suits you'
                                                : 'Why this color suits you',
                                            description: whyThisColorSuitsYou.trim().isEmpty
                                                ? 'This step is personalized based on your selected look, undertone, skin type, and product match.'
                                                : whyThisColorSuitsYou,
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 4),

                                      FloatingMiniButton(
                                        icon: Icons.shopping_bag_outlined,
                                        size: 34,
                                        onTap: () {
                                          _showProductRecommendationSheet(targetArea);
                                        },
                                      ),

                                      const SizedBox(height: 4),

                                      if (targetArea == 'full_makeup')
                                        FloatingMiniButton(
                                          icon: Icons.shopping_cart_checkout_rounded,
                                          size: 34,
                                          onTap: _buildingRecommendedKit
                                              ? () {}
                                              : _buildFinalRecommendedKit,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 3),

              Text(
                'Step ${_currentPage + 1} of 7',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF777780),
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
                  final isActive = index == _currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFF3D93)
                          : const Color(0xFFFF3D93).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),

              SizedBox(height: _currentPage == 6 ? 6 : 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAI && _aiSteps.isEmpty) {
      return AiTutorialLoadingView(
        lookName: widget.look.lookName,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFF4D97).withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_retouching_natural_outlined),
            selectedIcon: Icon(Icons.face_retouching_natural),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Premium',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),

      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 0,
          ),
          child: _buildAIStepsPager(),
        ),
      ),
    );
  }
}
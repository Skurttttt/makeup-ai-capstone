import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
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
import 'widgets/bottom_beauty_nav.dart';
import 'home_screen.dart';

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSkinTypeSheet();
      _generateAIInstructions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  String _categoryForTargetArea(String targetArea) {
    switch (targetArea) {
      case 'full_face':
        return 'Primer';
      case 'brows':
        return 'Eyebrow';
      case 'eyeshadow':
        return 'Eyeshadow';
      case 'eyeliner':
        return 'Eyeliner';
      case 'blush_contour':
        return 'Blush';
      case 'lips':
        return 'Lipstick';
      case 'full_makeup':
        return 'Setting Spray';
      default:
        return '';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecommendedProducts(
    String targetArea,
  ) async {
    final category = _categoryForTargetArea(targetArea);
    final selectedLook = widget.look.lookName.toLowerCase();
    final selectedSkinType = _selectedSkinType == null
        ? ''
        : _skinTypeLabel(_selectedSkinType!).toLowerCase();

    final detectedUndertone =
        widget.faceProfile?.undertone.name.toLowerCase() ?? '';

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

    final scoredProducts = categoryFilteredProducts.map((product) {
      int score = 0;

      final compatibleLooks =
          (product['compatible_looks'] ?? '').toString().toLowerCase();

      final compatibleSkinType =
          (product['compatible_skin_type'] ?? '').toString().toLowerCase();

      final undertone =
          (product['undertone'] ?? '').toString().toLowerCase();

      score += 10; // category match is required and strongest

      if (compatibleLooks.contains(selectedLook)) score += 4;

      if (selectedSkinType.isNotEmpty &&
          compatibleSkinType.contains(selectedSkinType)) {
        score += 3;
      }

      if (detectedUndertone.isNotEmpty &&
          undertone.contains(detectedUndertone)) {
        score += 2;
      }

      return {
        ...product,
        '_match_score': score,
      };
    }).toList();

    scoredProducts.sort((a, b) {
      return (b['_match_score'] as int).compareTo(a['_match_score'] as int);
    });

    return scoredProducts.take(2).toList();
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
          lipColor: widget.look.lipstickColor,
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
      final path = await _createGuideImage(
        prefix: 'eyeshadow_guide_',
        painter: EyeshadowGuidePainter(
          face: widget.detectedFace!,
          config: _config,
          palette: EyeshadowGuidePalette(
            lidColor: widget.look.eyeshadowColor.withOpacity(0.95),
            creaseColor: widget.look.eyeshadowColor.withOpacity(0.75),
            outerColor: widget.look.eyeshadowColor.withOpacity(1.0),
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
        return BasePrepGuideCard(imagePath: _basePrepGuideImagePath!);
      }
    }

    if (targetArea == 'brows') {
      if (_generatingEyebrowGuide) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_eyebrowGuideImagePath != null) {
        return EyebrowGuideCard(imagePath: _eyebrowGuideImagePath!);
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
        return LipGuideCard(imagePath: _lipGuideImagePath!);
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
                          _InstructionCard(
                            stepNumber: stepNumber,
                            title: title,
                            instruction: instruction,
                          ),

                          const SizedBox(height: 6),

                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: _GuideCardShell(
                                    child: _buildGuideWidgetForTargetArea(
                                      targetArea: targetArea,
                                    ),
                                  ),
                                ),

                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Column(
                                    children: [
                                      _FloatingMiniButton(
                                        icon: Icons.lightbulb_rounded,
                                        onTap: () {
                                          _showInfoSheet(
                                            title: 'Tip',
                                            description:
                                                'Follow the guide slowly and blend lightly. You can always add more product, but it is harder to remove excess makeup.',
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      _FloatingMiniButton(
                                        icon: Icons.palette_rounded,
                                        onTap: () {
                                          _showInfoSheet(
                                            title: targetArea == 'full_makeup'
                                                ? 'Why this look suits you'
                                                : 'Why this color suits you',
                                            description:
                                                whyThisColorSuitsYou.trim().isEmpty
                                                    ? 'This step is personalized based on your face shape, skin tone, and selected makeup look.'
                                                    : whyThisColorSuitsYou,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      _FloatingMiniButton(
                                        icon: Icons.shopping_bag_outlined,
                                        onTap: () {
                                          _showProductRecommendationSheet(targetArea);
                                        },
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

              const SizedBox(height: 8),

              Text(
                'Step ${_currentPage + 1} of 7',
                style: const TextStyle(
                  fontSize: 11,
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
                    width: isActive ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFF3D93)
                          : const Color(0xFFFF3D93).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 4),
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

      bottomNavigationBar: BottomBeautyNav(
        currentIndex: 1,
        onTap: (index) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
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

// ========== HELPER WIDGETS ==========

class _InstructionCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String instruction;

  const _InstructionCard({
    required this.stepNumber,
    required this.title,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD8E8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $stepNumber • ${title.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF3D93),
              letterSpacing: 0.1,
              height: 1,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            instruction,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.8,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Color(0xFF55555C),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCardShell extends StatelessWidget {
  final Widget child;

  const _GuideCardShell({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: child,
    );
  }
}

class _FloatingMiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingMiniButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF3D93),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: const Color(0xFFFF3D93).withOpacity(0.22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class AiTutorialLoadingView extends StatelessWidget {
  final String lookName;

  const AiTutorialLoadingView({
    super.key,
    required this.lookName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      bottomNavigationBar: BottomBeautyNav(
        currentIndex: 1,
        onTap: (index) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: 90,
                    left: -80,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF4D97).withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: -70,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withOpacity(0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 145,
                    right: -8,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          'assets/images/makeup_brush.png',
                          width: 92,
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .moveY(
                              begin: -4,
                              end: 6,
                              duration: 2400.ms,
                              curve: Curves.easeInOut,
                            )
                            .then()
                            .moveY(
                              begin: 6,
                              end: -4,
                              duration: 2400.ms,
                              curve: Curves.easeInOut,
                            ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        const Text(
                          'Creating your',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF171725),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'personalized tutorial',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF4D97),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Our AI is analyzing your unique features to craft the perfect $lookName tutorial just for you.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF74747A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D97)
                                        .withOpacity(0.26),
                                    blurRadius: 42,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            ClipOval(
                              child: Image.asset(
                                'assets/images/ai_orb.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .scale(
                                  duration: 2200.ms,
                                  begin: const Offset(0.94, 0.94),
                                  end: const Offset(1.04, 1.04),
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .scale(
                                  duration: 2200.ms,
                                  begin: const Offset(1.04, 1.04),
                                  end: const Offset(0.94, 0.94),
                                  curve: Curves.easeInOut,
                                ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE7D7FF),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6)
                                    .withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Shimmer.fromColors(
                            baseColor: const Color(0xFF6D4FE8),
                            highlightColor: const Color(0xFFFF4D97),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Analyzing your features...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _AiProgressCard(),
                        const SizedBox(height: 14),
                        _AiInfoCard(lookName: lookName),
                        const Spacer(),
                        const _AiTipCard(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AiProgressCard extends StatelessWidget {
  const _AiProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD9E9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: const [
          Expanded(
            child: _ProgressStep(
              icon: Icons.face_retouching_natural_rounded,
              title: 'Analyzing',
              subtitle: 'Face',
              active: false,
              done: true,
            ),
          ),
          Expanded(
            child: _ProgressStep(
              icon: Icons.palette_rounded,
              title: 'Selecting',
              subtitle: 'Look',
              active: false,
              done: true,
            ),
          ),
          Expanded(
            child: _ProgressStep(
              icon: Icons.auto_awesome_rounded,
              title: 'Generating',
              subtitle: 'Steps',
              active: true,
              done: false,
            ),
          ),
          Expanded(
            child: _ProgressStep(
              icon: Icons.description_rounded,
              title: 'Finalizing',
              subtitle: 'Guide',
              active: false,
              done: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool done;

  const _ProgressStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF8B5CF6)
        : done
            ? const Color(0xFFFF4D97)
            : const Color(0xFFB8B8BF);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFF4EEFF)
                    : done
                        ? const Color(0xFFFFEEF6)
                        : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.25),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            if (done)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D97),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF74747A),
          ),
        ),
      ],
    );
  }
}

class _AiInfoCard extends StatelessWidget {
  final String lookName;

  const _AiInfoCard({
    required this.lookName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFF4D97),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "What's happening?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF171725),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Analyzing your face shape, skin tone, and features to create your $lookName guide.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF74747A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: 0.65,
            child: Image.asset(
              'assets/images/face_mesh.png',
              width: 78,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFFF4D97),
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'This may take a few moments.\n',
                    style: TextStyle(
                      color: Color(0xFFFF4D97),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: "We're crafting something beautiful ✨",
                    style: TextStyle(
                      color: Color(0xFF74747A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
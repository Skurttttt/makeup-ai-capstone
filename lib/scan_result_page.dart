import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'home_screen.dart';
import 'makeup_layer.dart';
import 'instructions_page.dart';
import 'look_engine.dart';
import 'widgets/face_preview_card.dart';
import 'widgets/beauty_slider.dart';

// 1. Add imports
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/product_recommendation_engine.dart';

enum MakeupControlArea {
  lips,
  eyebrows,
  eyeshadow,
  eyeliner,
  blush,
  general,
}

class ScanResultPage extends StatefulWidget {
  final String? scannedImagePath;
  final String? scannedItem;
  final Face? detectedFace;
  final FaceProfile? faceProfile;
  final LookResult? look;
  final MakeupLookPreset selectedPreset;
  final bool isRestoredSavedLook;
  final List<Map<String, dynamic>>? restoredAiSteps;

  const ScanResultPage({
    super.key,
    this.scannedImagePath,
    this.scannedItem,
    this.detectedFace,
    this.faceProfile,
    this.look,
    this.selectedPreset = MakeupLookPreset.softGlam,
    this.isRestoredSavedLook = false,
    this.restoredAiSteps,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  ui.Image? _uiImage;
  Face? _previewFace;

  MakeupControlArea _selectedArea = MakeupControlArea.general;

  // Individual ValueNotifiers for each opacity type
  final ValueNotifier<double> _globalOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _lipOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _blushOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _eyeOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _linerOpacity = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _browOpacity = ValueNotifier<double>(1.0);

  // Combined preview values notifier
  late final ValueNotifier<MakeupPreviewValues> _previewValues;

  late final MakeupLookPreset _currentPreset;

  // 2. Add state variables
  bool _loadingOverlayColors = false;

  Color? _recommendedLipColor;
  Color? _recommendedBlushColor;
  Color? _recommendedEyeshadowColor;

  Map<String, dynamic>? _lockedLipProduct;
  Map<String, dynamic>? _lockedBlushProduct;
  Map<String, dynamic>? _lockedEyeshadowProduct;

  @override
  void initState() {
    super.initState();

    _currentPreset = widget.selectedPreset;

    _previewValues = ValueNotifier<MakeupPreviewValues>(
      MakeupPreviewValues(
        globalIntensity: _globalOpacity.value,
        lipOpacity: _lipOpacity.value,
        blushOpacity: _blushOpacity.value,
        eyeOpacity: _eyeOpacity.value,
        linerOpacity: _linerOpacity.value,
        browOpacity: _browOpacity.value,
      ),
    );

    // Add listeners to update combined notifier
    _globalOpacity.addListener(_updatePreviewValues);
    _lipOpacity.addListener(_updatePreviewValues);
    _blushOpacity.addListener(_updatePreviewValues);
    _eyeOpacity.addListener(_updatePreviewValues);
    _linerOpacity.addListener(_updatePreviewValues);
    _browOpacity.addListener(_updatePreviewValues);

    // Use already-detected face immediately.
    // This avoids waiting for ML Kit again.
    _previewFace = widget.detectedFace;

    _loadPreviewAndDetect();

    // 7. Call loader in initState()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendedOverlayColors();
    });
  }

  void _updatePreviewValues() {
    _previewValues.value = MakeupPreviewValues(
      globalIntensity: _globalOpacity.value,
      lipOpacity: _lipOpacity.value,
      blushOpacity: _blushOpacity.value,
      eyeOpacity: _eyeOpacity.value,
      linerOpacity: _linerOpacity.value,
      browOpacity: _browOpacity.value,
    );
  }

  @override
  void dispose() {
    _globalOpacity.removeListener(_updatePreviewValues);
    _lipOpacity.removeListener(_updatePreviewValues);
    _blushOpacity.removeListener(_updatePreviewValues);
    _eyeOpacity.removeListener(_updatePreviewValues);
    _linerOpacity.removeListener(_updatePreviewValues);
    _browOpacity.removeListener(_updatePreviewValues);

    _globalOpacity.dispose();
    _lipOpacity.dispose();
    _blushOpacity.dispose();
    _eyeOpacity.dispose();
    _linerOpacity.dispose();
    _browOpacity.dispose();
    _previewValues.dispose();

    super.dispose();
  }

  Future<void> _loadPreviewAndDetect() async {
    final path = widget.scannedImagePath;
    if (path == null) return;

    try {
      final bytes = await File(path).readAsBytes();

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 720,
      );

      final frame = await codec.getNextFrame();

      if (!mounted) return;

      setState(() {
        _uiImage = frame.image;
        _previewFace = widget.detectedFace;
      });

      // IMPORTANT:
      // If the scan already gave us a face, do not run ML Kit again.
      if (widget.detectedFace != null) {
        return;
      }

      // Fallback only for restored/saved looks or missing face data.
      final face = await _detectFaceOnFile(path);

      if (!mounted) return;

      setState(() {
        _previewFace = face;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _previewFace = widget.detectedFace;
      });
    }
  }

  // Keep for fallback when needed
  Future<Face?> _detectFaceOnFile(String filePath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );

    try {
      final input = InputImage.fromFilePath(filePath);
      final faces = await detector.processImage(input);
      return faces.isEmpty ? null : faces.first;
    } finally {
      await detector.close();
    }
  }

  ValueNotifier<double> _notifierForArea() {
    switch (_selectedArea) {
      case MakeupControlArea.lips:
        return _lipOpacity;

      case MakeupControlArea.eyebrows:
        return _browOpacity;

      case MakeupControlArea.eyeshadow:
        return _eyeOpacity;

      case MakeupControlArea.eyeliner:
        return _linerOpacity;

      case MakeupControlArea.blush:
        return _blushOpacity;

      case MakeupControlArea.general:
        return _globalOpacity;
    }
  }

  String _titleForArea() {
    switch (_selectedArea) {
      case MakeupControlArea.lips:
        return 'Lips Opacity';
      case MakeupControlArea.eyebrows:
        return 'Eyebrows Opacity';
      case MakeupControlArea.eyeshadow:
        return 'Eyeshadow Opacity';
      case MakeupControlArea.eyeliner:
        return 'Eyeliner Opacity';
      case MakeupControlArea.blush:
        return 'Blush Opacity';
      case MakeupControlArea.general:
        return 'General Opacity';
    }
  }

  String _subtitleForArea() {
    switch (_selectedArea) {
      case MakeupControlArea.lips:
        return 'Adjust lip makeup intensity';
      case MakeupControlArea.eyebrows:
        return 'Adjust eyebrow makeup intensity';
      case MakeupControlArea.eyeshadow:
        return 'Adjust eyeshadow intensity';
      case MakeupControlArea.eyeliner:
        return 'Adjust eyeliner intensity';
      case MakeupControlArea.blush:
        return 'Adjust blush intensity';
      case MakeupControlArea.general:
        return 'Adjust all makeup layers';
    }
  }

  void _updateAreaValue(double value) {
    value = value.clamp(0.0, 1.0);

    final notifier = _notifierForArea();

    if ((notifier.value - value).abs() < 0.006) {
      return;
    }

    notifier.value = value;
  }

  void _resetAll() {
    _globalOpacity.value = 1.0;
    _lipOpacity.value = 1.0;
    _blushOpacity.value = 1.0;
    _eyeOpacity.value = 1.0;
    _linerOpacity.value = 1.0;
    _browOpacity.value = 1.0;

    setState(() {
      _selectedArea = MakeupControlArea.general;
    });
  }

  // 3. Add safe HEX parser
  Color? _safeColorFromHex(String? hex) {
    if (hex == null) return null;

    final cleaned = hex.trim().replaceAll('#', '');

    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)) {
      return null;
    }

    return Color(int.parse('FF$cleaned', radix: 16));
  }

  // 4. Add target-area recommendation loader
  Future<Map<String, dynamic>?> _fetchBestProductForOverlay({
    required String targetArea,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('is_active', true);

      final allProducts = List<Map<String, dynamic>>.from(response);

      final recommended = ProductRecommendationEngine.recommendBestProducts(
        products: allProducts,
        selectedLook: widget.look?.lookName ?? '',
        userUndertone: widget.faceProfile?.undertone.name ?? 'Neutral',
        userShadeDepth: _userShadeDepthFromFaceProfile(),
        targetArea: targetArea,
        preferredFinish: '',
        limit: 1,
      );

      if (recommended.isEmpty) return null;

      return recommended.first;
    } catch (e) {
      debugPrint('❌ Overlay product fetch failed for $targetArea: $e');
      return null;
    }
  }

  // 5. Add shade depth helper
  String _userShadeDepthFromFaceProfile() {
    final raw = widget.faceProfile?.skinTone.name.toLowerCase() ?? '';

    if (raw.contains('fair')) return 'Fair';
    if (raw.contains('light')) return 'Light';
    if (raw.contains('medium')) return 'Medium';
    if (raw.contains('morena')) return 'Morena';
    if (raw.contains('deep')) return 'Deep Morena';

    return 'Medium';
  }

  // 6. Add overlay color loader
  Future<void> _loadRecommendedOverlayColors() async {
    if (_loadingOverlayColors) return;

    setState(() => _loadingOverlayColors = true);

    try {
      final lip = await _fetchBestProductForOverlay(targetArea: 'lips');
      final blush = await _fetchBestProductForOverlay(targetArea: 'blush');
      final eyeshadow =
          await _fetchBestProductForOverlay(targetArea: 'eyeshadow');

      if (!mounted) return;

      // Simplified debug logging
      debugPrint('💄 PREVIEW LIP PRODUCT: ${lip?['shade_name']} ${lip?['hex_code']}');
      debugPrint('🌸 PREVIEW BLUSH PRODUCT: ${blush?['shade_name']} ${blush?['hex_code']}');
      debugPrint('👁 PREVIEW EYESHADOW PRODUCT: ${eyeshadow?['shade_name']} ${eyeshadow?['hex_code']}');

      // Parse colors BEFORE setState
      final lipColor = _safeColorFromHex(lip?['hex_code']?.toString());
      final blushColor = _safeColorFromHex(blush?['hex_code']?.toString());
      final eyeshadowColor = _safeColorFromHex(eyeshadow?['hex_code']?.toString());

      if (!mounted) return;

      setState(() {
        _lockedLipProduct = lip;
        _lockedBlushProduct = blush;
        _lockedEyeshadowProduct = eyeshadow;

        _recommendedLipColor = lipColor;
        _recommendedBlushColor = blushColor;
        _recommendedEyeshadowColor = eyeshadowColor;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingOverlayColors = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final faceForOverlay = _previewFace ?? widget.detectedFace;
    final canOverlay =
        _uiImage != null && faceForOverlay != null && widget.look != null;

    // Check if overlay colors are ready
    final overlayReady =
        _recommendedLipColor != null ||
        _recommendedBlushColor != null ||
        _recommendedEyeshadowColor != null;

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
          padding: const EdgeInsets.only(bottom: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final previewHeight = (h * 0.42).clamp(320.0, 410.0);

              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 2),

                      _Header(onReset: _resetAll),

                      const SizedBox(height: 4),

                      Container(
                        height: previewHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D97).withOpacity(0.10),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: overlayReady
                                  ? FacePreviewCard(
                                      uiImage: _uiImage,
                                      scannedImagePath: widget.scannedImagePath,
                                      canOverlay: canOverlay,
                                      faceForOverlay: faceForOverlay,
                                      look: widget.look,
                                      faceProfile: widget.faceProfile,
                                      preset: _currentPreset,
                                      previewValues: _previewValues,
                                      makeupLayer: MakeupLayer.full,
                                      customLipColor: _recommendedLipColor,
                                      customBlushColor: _recommendedBlushColor,
                                      customEyeshadowColor: _recommendedEyeshadowColor,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFF4D97),
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.86),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'AI Preview',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF4D97),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _currentPreset.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      _AreaSelector(
                        selectedArea: _selectedArea,
                        onSelected: (area) {
                          setState(() => _selectedArea = area);
                        },
                      ),

                      const SizedBox(height: 10),

                      ValueListenableBuilder<double>(
                        valueListenable: _notifierForArea(),
                        builder: (_, sliderValue, __) {
                          return _SingleOpacityCard(
                            title: _titleForArea(),
                            subtitle: _subtitleForArea(),
                            value: sliderValue,
                            onChanged: _updateAreaValue,
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      _TutorialOnlyCard(
                        onTutorial: widget.look == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InstructionsPage(
                                      look: widget.look!,
                                      faceProfile: widget.faceProfile,
                                      scannedImagePath: widget.scannedImagePath,
                                      detectedFace: faceForOverlay,
                                      selectedPreset: _currentPreset,
                                      isRestoredSavedLook: widget.isRestoredSavedLook,
                                      restoredAiSteps: widget.restoredAiSteps,
                                    ),
                                  ),
                                );
                              },
                      ),

                      const SizedBox(height: 0),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onReset;

  const _Header({
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onReset,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFD9E9),
                    width: 1.2,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFFFF4D97),
                      size: 26,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Reset',
                      style: TextStyle(
                        color: Color(0xFFFF4D97),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Style Preview',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF171725),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Adjust opacity for each makeup area',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF74747A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xFFFF4D97),
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaSelector extends StatelessWidget {
  final MakeupControlArea selectedArea;
  final ValueChanged<MakeupControlArea> onSelected;

  const _AreaSelector({
    required this.selectedArea,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _AreaItem(MakeupControlArea.lips, Icons.favorite_rounded, 'Lips'),
      _AreaItem(MakeupControlArea.eyebrows, Icons.remove_rounded, 'Eyebrows'),
      _AreaItem(MakeupControlArea.eyeshadow, Icons.visibility_rounded, 'Eyeshadow'),
      _AreaItem(MakeupControlArea.eyeliner, Icons.edit_rounded, 'Eyeliner'),
      _AreaItem(MakeupControlArea.blush, Icons.brush_rounded, 'Blush'),
      _AreaItem(MakeupControlArea.general, Icons.tune_rounded, 'General'),
    ];

    return SizedBox(
      height: 128,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.35,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item.area == selectedArea;

          return GestureDetector(
            onTap: () => onSelected(item.area),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF4D97) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF4D97)
                      : const Color(0xFFFFD9E9),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 22,
                    color: isSelected ? Colors.white : const Color(0xFF202124),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AreaItem {
  final MakeupControlArea area;
  final IconData icon;
  final String label;

  const _AreaItem(this.area, this.icon, this.label);
}

class _SingleOpacityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  const _SingleOpacityCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF171725),
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF4D97),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: BeautySlider(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialOnlyCard extends StatelessWidget {
  final VoidCallback? onTutorial;

  const _TutorialOnlyCard({
    required this.onTutorial,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTutorial == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTutorial,
        child: Container(
          width: double.infinity,
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EEFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF7B4CE0).withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B4CE0).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Color(0xFF7B4CE0),
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutorial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF171725),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Open AI step-by-step makeup guide',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF777780),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF7B4CE0),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'home_screen.dart';
import 'instructions_page.dart';
import 'look_engine.dart';
import 'skin_analyzer.dart';
import 'widgets/bottom_action_buttons.dart';
import 'widgets/bottom_beauty_nav.dart';
import 'widgets/face_preview_card.dart';
import 'widgets/opacity_control_card.dart';

class ScanResultPage extends StatefulWidget {
  final String? scannedImagePath;
  final String? scannedItem;
  final Face? detectedFace;
  final FaceProfile? faceProfile;
  final LookResult? look;
  final MakeupLookPreset selectedPreset;

  const ScanResultPage({
    super.key,
    this.scannedImagePath,
    this.scannedItem,
    this.detectedFace,
    this.faceProfile,
    this.look,
    this.selectedPreset = MakeupLookPreset.softGlam,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  ui.Image? _uiImage;
  Face? _previewFace;

  final ValueNotifier<double> _globalOpacity = ValueNotifier<double>(0.75);

  final ValueNotifier<MakeupPreviewValues> _previewValues =
      ValueNotifier<MakeupPreviewValues>(
    const MakeupPreviewValues(
      globalIntensity: 0.75,
      lipOpacity: 1.0,
      blushOpacity: 1.0,
      eyeOpacity: 1.0,
      linerOpacity: 1.0,
      browOpacity: 1.0,
    ),
  );

  late final MakeupLookPreset _currentPreset;

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.selectedPreset;
    _loadPreviewAndDetect();
  }

  @override
  void dispose() {
    _globalOpacity.dispose();
    _previewValues.dispose();
    super.dispose();
  }

  void _applyPreviewValues({
    double? globalIntensity,
    double? lipOpacity,
    double? blushOpacity,
    double? eyeOpacity,
    double? linerOpacity,
    double? browOpacity,
  }) {
    _previewValues.value = _previewValues.value.copyWith(
      globalIntensity: globalIntensity,
      lipOpacity: lipOpacity,
      blushOpacity: blushOpacity,
      eyeOpacity: eyeOpacity,
      linerOpacity: linerOpacity,
      browOpacity: browOpacity,
    );
  }

  Future<void> _loadPreviewAndDetect() async {
    final path = widget.scannedImagePath;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 720,
    );

    final frame = await codec.getNextFrame();
    final previewImage = frame.image;

    if (!mounted) return;

    setState(() {
      _uiImage = previewImage;
      _previewFace = null;
    });

    try {
      final tmpFile = await _writeUiImageToTempPng(previewImage);
      final face = await _detectFaceOnFile(tmpFile.path);

      if (!mounted) return;

      setState(() {
        _previewFace = face;
      });

      tmpFile.delete().catchError((_) => tmpFile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _previewFace = null);
    }
  }

  Future<File> _writeUiImageToTempPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode preview image.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp('ft_preview_');
    final file = File('${dir.path}/preview.png');
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

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
      if (faces.isEmpty) return null;
      return faces.first;
    } finally {
      await detector.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final faceForOverlay = _previewFace ?? widget.detectedFace;
    final canOverlay =
        _uiImage != null && faceForOverlay != null && widget.look != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final previewHeight = (h * 0.43).clamp(292.0, 410.0);
            final sidePadding = constraints.maxWidth < 390 ? 18.0 : 22.0;

            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _TopBar(onBack: () => Navigator.pop(context)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: previewHeight,
                          child: FacePreviewCard(
                            uiImage: _uiImage,
                            scannedImagePath: widget.scannedImagePath,
                            canOverlay: canOverlay,
                            faceForOverlay: faceForOverlay,
                            look: widget.look,
                            faceProfile: widget.faceProfile,
                            preset: _currentPreset,
                            previewValues: _previewValues,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_uiImage != null && widget.look != null)
                          OpacityControlCard(
                            globalOpacity: _globalOpacity,
                            onApplyGlobal: (v) {
                              _applyPreviewValues(globalIntensity: v);
                            },
                          ),
                        const Spacer(),
                        BottomActionButtons(
                          onBack: () => Navigator.pop(context),
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
                                      ),
                                    ),
                                  );
                                },
                          onBuyProducts: _showBuyProductsDialog,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                BottomBeautyNav(
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
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBuyProductsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Buy Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Product recommendations will be connected here once the market system is ready.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFFFF4D97)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 21,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const Expanded(
            child: Text(
              'Style Preview',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.favorite_border_rounded,
              size: 24,
              color: Color(0xFFFF4D97),
            ),
          ),
        ],
      ),
    );
  }
}
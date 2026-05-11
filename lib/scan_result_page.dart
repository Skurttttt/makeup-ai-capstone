import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'home_screen.dart';
import 'makeup_layer.dart';
import 'instructions_page.dart';
import 'look_engine.dart';
import 'widgets/bottom_beauty_nav.dart';
import 'widgets/face_preview_card.dart';
import 'widgets/beauty_slider.dart';

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

  MakeupControlArea _selectedArea = MakeupControlArea.general;

  final ValueNotifier<MakeupPreviewValues> _previewValues =
      ValueNotifier<MakeupPreviewValues>(
    const MakeupPreviewValues(
      globalIntensity: 1.0,
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
    _previewValues.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewAndDetect() async {
    final path = widget.scannedImagePath;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 720);
    final frame = await codec.getNextFrame();

    if (!mounted) return;

    setState(() {
      _uiImage = frame.image;
      _previewFace = null;
    });

    try {
      final tmpFile = await _writeUiImageToTempPng(frame.image);
      final face = await _detectFaceOnFile(tmpFile.path);

      if (!mounted) return;

      setState(() => _previewFace = face);
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

    final pngBytes = byteData.buffer.asUint8List();
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
      return faces.isEmpty ? null : faces.first;
    } finally {
      await detector.close();
    }
  }

  double _valueForArea(MakeupPreviewValues values) {
    switch (_selectedArea) {
      case MakeupControlArea.lips:
        return values.lipOpacity;
      case MakeupControlArea.eyebrows:
        return values.browOpacity;
      case MakeupControlArea.eyeshadow:
        return values.eyeOpacity;
      case MakeupControlArea.eyeliner:
        return values.linerOpacity;
      case MakeupControlArea.blush:
        return values.blushOpacity;
      case MakeupControlArea.general:
        return values.globalIntensity;
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
    final current = _previewValues.value;

    switch (_selectedArea) {
      case MakeupControlArea.lips:
        _previewValues.value = current.copyWith(lipOpacity: value);
        break;
      case MakeupControlArea.eyebrows:
        _previewValues.value = current.copyWith(browOpacity: value);
        break;
      case MakeupControlArea.eyeshadow:
        _previewValues.value = current.copyWith(eyeOpacity: value);
        break;
      case MakeupControlArea.eyeliner:
        _previewValues.value = current.copyWith(linerOpacity: value);
        break;
      case MakeupControlArea.blush:
        _previewValues.value = current.copyWith(blushOpacity: value);
        break;
      case MakeupControlArea.general:
        _previewValues.value = current.copyWith(globalIntensity: value);
        break;
    }
  }

  void _resetAll() {
    _previewValues.value = const MakeupPreviewValues(
      globalIntensity: 1.0,
      lipOpacity: 1.0,
      blushOpacity: 1.0,
      eyeOpacity: 1.0,
      linerOpacity: 1.0,
      browOpacity: 1.0,
    );

    setState(() {
      _selectedArea = MakeupControlArea.general;
    });
  }

  @override
  Widget build(BuildContext context) {
    final faceForOverlay = _previewFace ?? widget.detectedFace;
    final canOverlay =
        _uiImage != null && faceForOverlay != null && widget.look != null;

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
                            FacePreviewCard(
                              uiImage: _uiImage,
                              scannedImagePath: widget.scannedImagePath,
                              canOverlay: canOverlay,
                              faceForOverlay: faceForOverlay,
                              look: widget.look,
                              faceProfile: widget.faceProfile,
                              preset: _currentPreset,
                              previewValues: _previewValues,
                              makeupLayer: MakeupLayer.full,
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

                      ValueListenableBuilder<MakeupPreviewValues>(
                        valueListenable: _previewValues,
                        builder: (context, values, _) {
                          final selectedValue = _valueForArea(values);

                          return _SingleOpacityCard(
                            title: _titleForArea(),
                            subtitle: _subtitleForArea(),
                            value: selectedValue,
                            onChanged: _updateAreaValue,
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      _ActionCards(
                        onProduct: () {},
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

class _ActionCards extends StatelessWidget {
  final VoidCallback onProduct;
  final VoidCallback? onTutorial;

  const _ActionCards({
    required this.onProduct,
    required this.onTutorial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Product',
            subtitle: 'Recommended for you',
            color: const Color(0xFFFF4D97),
            background: const Color(0xFFFFEEF6),
            onTap: onProduct,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.school_outlined,
            title: 'Tutorial',
            subtitle: 'Step by step guide',
            color: const Color(0xFF7B4CE0),
            background: const Color(0xFFF4EEFF),
            onTap: onTutorial,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.24)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
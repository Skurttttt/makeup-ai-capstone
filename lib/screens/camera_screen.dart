// lib/screens/camera_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' show cos, sin;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../skin_analyzer.dart';
import '../look_engine.dart';
import '../look_picker.dart';
import '../instructions_page.dart';
import '../scan_result_page.dart';
import '../services/scan_quota_service.dart';
import 'user_subscription_page.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;
  final MakeupLookPreset? preselectedLook;

  const CameraScreen({
    super.key,
    required this.camera,
    this.scannedItem,
    this.preselectedLook,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return FaceScanPage(
      camera: widget.camera,
      scannedItem: widget.scannedItem,
      preselectedLook: widget.preselectedLook,
    );
  }
}

class FaceScanPage extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;
  final MakeupLookPreset? preselectedLook;

  const FaceScanPage({
    super.key,
    required this.camera,
    this.scannedItem,
    this.preselectedLook,
  });

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage> {
  CameraController? _controller;
  bool _busy = false;

  XFile? _capturedFile;
  ui.Image? _capturedUiImage;
  Face? _detectedFace;

  FaceProfile? _faceProfile;
  LookResult? _look;

  double _intensity = 0.75;

  double _sceneLuminance = 0.50;
  double _leftCheekLum = 0.50;
  double _rightCheekLum = 0.50;

  bool _liveRunning = false;
  DateTime _lastLiveTick = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _liveInterval = Duration(milliseconds: 450);

  String _liveQualityLabel = 'Point camera at your face…';
  List<String> _liveWarnings = [];

  final InputImageRotation _liveRotation = InputImageRotation.rotation270deg;

  int _noFaceStreak = 0;
  Face? _lastDetectedFace;

  MakeupLookPreset _selectedLook = MakeupLookPreset.softGlam;

  late final FaceDetector _liveFaceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.05,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
    ),
  );

  String _status = 'Tap the preview to capture & scan.';

  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.preselectedLook != null) {
      _selectedLook = widget.preselectedLook!;
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    final controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });

      await _startLiveQuality(controller);
    } catch (e) {
      setState(() => _status = 'Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _stopLiveQuality();
    _controller?.dispose();
    _faceDetector.close();
    _liveFaceDetector.close();
    super.dispose();
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<double> _estimateSceneLuminance(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0.5;

    final bytes = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    final stepX = (w / 25).clamp(8, 40).toInt();
    final stepY = (h / 25).clamp(8, 40).toInt();

    double sum = 0.0;
    int count = 0;

    for (int y = 0; y < h; y += stepY) {
      for (int x = 0; x < w; x += stepX) {
        final i = (y * w + x) * 4;
        if (i + 2 >= bytes.length) continue;

        final r = bytes[i] / 255.0;
        final g = bytes[i + 1] / 255.0;
        final b = bytes[i + 2] / 255.0;

        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b);
        count++;
      }
    }

    return count == 0 ? 0.5 : (sum / count).clamp(0.0, 1.0);
  }

  Future<double> _avgLuminanceInRect(ui.Image image, Rect rect) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0.5;

    final bytes = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    final safe = rect.intersect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    if (safe.isEmpty) return 0.5;

    final stepX = (safe.width / 18).clamp(6, 26).toInt();
    final stepY = (safe.height / 18).clamp(6, 26).toInt();

    double sum = 0.0;
    int count = 0;

    for (int y = safe.top.toInt(); y < safe.bottom.toInt(); y += stepY) {
      for (int x = safe.left.toInt(); x < safe.right.toInt(); x += stepX) {
        final i = (y * w + x) * 4;
        if (i + 2 >= bytes.length) continue;

        final r = bytes[i] / 255.0;
        final g = bytes[i + 1] / 255.0;
        final b = bytes[i + 2] / 255.0;

        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b);
        count++;
      }
    }

    return count == 0 ? 0.5 : (sum / count).clamp(0.0, 1.0);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    int index = 0;

    for (int row = 0; row < height; row++) {
      final yRowStart = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[index++] = yPlane[yRowStart + col];
      }
    }

    for (int row = 0; row < height ~/ 2; row++) {
      final uvRowStart = row * uvRowStride;
      for (int col = 0; col < width ~/ 2; col++) {
        final uvIndex = uvRowStart + col * uvPixelStride;
        nv21[index++] = vPlane[uvIndex];
        nv21[index++] = uPlane[uvIndex];
      }
    }

    return nv21;
  }

  InputImage _inputImageFromCameraImageNv21(CameraImage image) {
    final bytes = _yuv420ToNv21(image);

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _liveRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  double _estimateBrightness(CameraImage image) {
    final yPlane = image.planes[0].bytes;
    if (yPlane.isEmpty) return 0;

    const step = 50;
    int sum = 0;
    int count = 0;

    for (int i = 0; i < yPlane.length; i += step) {
      sum += yPlane[i];
      count++;
    }

    return count == 0 ? 0 : sum / count;
  }

  List<String> _buildLiveWarnings({
    required Face? face,
    required int imgW,
    required int imgH,
    required double brightness,
  }) {
    final warnings = <String>[];

    if (brightness < 60) {
      warnings.add('Too dark. Move to a brighter area or face a light source.');
    } else if (brightness < 90) {
      warnings.add('Lighting is dim. Try brighter and even lighting.');
    }

    if (face == null) {
      warnings.add('No face detected. Face the camera and remove obstructions.');
      return warnings;
    }

    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imgArea = imgW * imgH;
    final ratio = faceArea / imgArea;

    if (ratio < 0.04) {
      warnings.add('Move closer. Your face is too small in the frame.');
    }

    return warnings;
  }

  String _liveQualityFromWarnings(List<String> w) {
    if (w.isEmpty) return 'Good ✅';
    if (w.length == 1) return 'Moderate ⚠️';
    return 'Low ⚠️';
  }

  String _brightnessLabel(double b) {
    if (b < 60) return 'Too dark';
    if (b < 90) return 'Dim';
    if (b < 170) return 'Good';
    return 'Very bright';
  }

  Future<void> _startLiveQuality(CameraController controller) async {
    if (_liveRunning) return;

    _liveRunning = true;

    await controller.startImageStream((CameraImage image) async {
      if (!_liveRunning) return;

      final now = DateTime.now();
      if (now.difference(_lastLiveTick) < _liveInterval) return;
      _lastLiveTick = now;

      try {
        final brightness = _estimateBrightness(image);
        final input = _inputImageFromCameraImageNv21(image);
        final faces = await _liveFaceDetector.processImage(input);

        Face? face;

        if (faces.isNotEmpty) {
          faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));

          face = faces.first;
          _lastDetectedFace = face;
          _noFaceStreak = 0;
        } else {
          _noFaceStreak++;

          if (_noFaceStreak < 3 && _lastDetectedFace != null) {
            face = _lastDetectedFace;
          }
        }

        final warnings = _buildLiveWarnings(
          face: _noFaceStreak >= 3 ? null : face,
          imgW: image.width,
          imgH: image.height,
          brightness: brightness,
        );

        if (mounted) {
          setState(() {
            _liveWarnings = warnings;
            _liveQualityLabel =
                '${_liveQualityFromWarnings(warnings)} • ${_brightnessLabel(brightness)}';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _liveQualityLabel = 'Live Scan Quality: Error';
            _liveWarnings = ['Live analyzer error: $e'];
          });
        }
      }
    });
  }

  Future<void> _stopLiveQuality() async {
    _liveRunning = false;

    try {
      await _controller?.stopImageStream();
    } catch (_) {}
  }

  bool _canCaptureNow() {
    final severe = _liveWarnings.any((w) {
      final text = w.toLowerCase();
      return text.contains('too dark') ||
          text.contains('move closer') ||
          text.contains('no face detected');
    });

    return !severe;
  }

  void _showCaptureBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fix live scan tips first before capturing.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showQuotaReachedDialog(ScanUsage usage) async {
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.bolt_rounded, color: Color(0xFFFF4D97)),
            SizedBox(width: 10),
            Expanded(child: Text('Daily scan limit reached')),
          ],
        ),
        content: Text(
          "You've used all ${usage.dailyLimit} of today's free scans. "
          'Upgrade to Pro or Premium for unlimited face scans and '
          'cloud-saved looks across your devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('See plans'),
          ),
        ],
      ),
    );
    if (upgrade == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserSubscriptionPage()),
      );
    }
  }

  void _handlePreviewTap() {
    if (_busy) return;

    if (!_canCaptureNow()) {
      _showCaptureBlockedMessage();
      return;
    }

    _captureAndScan();
  }

  Future<void> _captureAndScan() async {
    if (!_canCaptureNow()) {
      _showCaptureBlockedMessage();
      return;
    }

    // Daily scan-quota gate (5/day for Free, unlimited for Pro/Premium).
    final usage = await ScanQuotaService.instance.getUsage();
    if (!usage.hasRemaining) {
      if (mounted) await _showQuotaReachedDialog(usage);
      return;
    }

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() {
      _busy = true;
      _status = 'Capturing…';
      _capturedFile = null;
      _capturedUiImage = null;
      _detectedFace = null;
      _faceProfile = null;
      _look = null;
      _intensity = 0.75;
      _sceneLuminance = 0.50;
      _leftCheekLum = 0.50;
      _rightCheekLum = 0.50;
    });

    try {
      await _stopLiveQuality();

      final file = await controller.takePicture();
      final uiImage = await _loadUiImageFromFile(file.path);
      final sceneLum = await _estimateSceneLuminance(uiImage);

      setState(() {
        _capturedFile = file;
        _capturedUiImage = uiImage;
        _sceneLuminance = sceneLum;
        _status = 'Detecting face…';
      });

      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Try better lighting.');
        return;
      }

      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));

      final face = faces.first;

      final box = face.boundingBox;
      final fw = box.width;
      final fh = box.height;

      final leftCheekRect = Rect.fromLTWH(
        box.left + fw * 0.08,
        box.top + fh * 0.45,
        fw * 0.28,
        fh * 0.22,
      );

      final rightCheekRect = Rect.fromLTWH(
        box.left + fw * 0.64,
        box.top + fh * 0.45,
        fw * 0.28,
        fh * 0.22,
      );

      final leftLum = await _avgLuminanceInRect(uiImage, leftCheekRect);
      final rightLum = await _avgLuminanceInRect(uiImage, rightCheekRect);

      setState(() {
        _leftCheekLum = leftLum;
        _rightCheekLum = rightLum;
        _status = 'Analyzing skin tone…';
      });

      final skin = await SkinAnalyzer.analyze(uiImage, face);
      final profile = FaceProfile.fromAnalysis(face, skin);

      final look = LookEngine.generateLook(
        profile: profile,
        preset: _selectedLook,
      );

      setState(() {
        _detectedFace = face;
        _faceProfile = profile;
        _look = look;
        _status = 'Done ✅ Navigating to results…';
      });

      // Count this successful scan against today's quota and, if the
      // user's plan supports it, auto-save the result to the cloud
      // `scans` table so it appears under Saved Looks on every device.
      // This runs in the background — failures must not block the UI.
      // ignore: discarded_futures
      ScanQuotaService.instance.consumeScan();
      // ignore: discarded_futures
      ScanQuotaService.instance.autoSaveScan(
        lookName: _selectedLook.name,
        imagePath: _capturedFile?.path,
        skinTone: profile.skinTone.name,
        faceShape: profile.faceShape.name,
        faceData: {
          'preset': _selectedLook.name,
          'undertone': profile.undertone.name,
          'scene_luminance': _sceneLuminance,
          'left_cheek_lum': _leftCheekLum,
          'right_cheek_lum': _rightCheekLum,
        },
      );

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScanResultPage(
              scannedImagePath: _capturedFile?.path,
              scannedItem: widget.scannedItem,
              detectedFace: face,
              faceProfile: profile,
              look: look,
              selectedPreset: _selectedLook,
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _capturedFile = null;
            _capturedUiImage = null;
            _detectedFace = null;
            _faceProfile = null;
            _look = null;
            _status = 'Tap the preview to capture & scan.';
          });

          final c = _controller;
          if (c != null && c.value.isInitialized) {
            await _startLiveQuality(c);
          }
        }
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }

      final c = _controller;
      if (c != null && c.value.isInitialized) {
        await _startLiveQuality(c);
      }
    }
  }

  // ignore: unused_element
  void _openInstructions() {
    final look = _look;
    if (look == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstructionsPage(
          look: look,
          faceProfile: _faceProfile,
          scannedImagePath: _capturedFile?.path,
          detectedFace: _detectedFace,
          selectedPreset: _selectedLook,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final bool showPreview =
        _capturedUiImage != null && _detectedFace != null && _look != null;

    final bool showSlider = showPreview && _faceProfile != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 18),

              _GoodLightingCard(
                qualityLabel: _liveQualityLabel,
                warnings: _liveWarnings,
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: _handlePreviewTap,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF4D97),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D97).withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: controller == null || !controller.value.isInitialized
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF4D97),
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: controller.value.previewSize!.height,
                                  height: controller.value.previewSize!.width,
                                  child: CameraPreview(controller),
                                ),
                              ),

                              if (!_busy && _capturedUiImage == null)
                                CustomPaint(
                                  painter: FaceGuidePainter(),
                                ),

                              Positioned(
                                top: 14,
                                left: 14,
                                child: _CameraBadge(
                                  icon: Icons.wb_sunny_outlined,
                                  text: 'Good lighting',
                                  showDot: _liveWarnings.isEmpty,
                                ),
                              ),

                              Positioned(
                                top: 14,
                                right: 14,
                                child: GestureDetector(
                                  onTap: _handlePreviewTap,
                                  child: _CameraBadge(
                                    icon: Icons.camera_alt_rounded,
                                    text: 'Capture',
                                  ),
                                ),
                              ),

                              Positioned(
                                bottom: 18,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.62),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Position your face in the oval',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (_busy)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF4D97),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _LookDropdownWrapper(
                child: LookPicker(
                  value: _selectedLook,
                  onChanged: (v) => setState(() => _selectedLook = v),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              if (_capturedUiImage == null)
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _handlePreviewTap,
                    icon: const Icon(Icons.camera_alt_rounded, size: 26),
                    label: const Text(
                      'Scan Face',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D97),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFFFF4D97).withOpacity(0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (showPreview)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      if (showSlider)
                        Row(
                          children: [
                            const Text('Opacity', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: _intensity,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label: '${(_intensity * 100).round()}%',
                                onChanged: (v) => setState(() => _intensity = v),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== HELPER WIDGETS ==========

class _GoodLightingCard extends StatelessWidget {
  final String qualityLabel;
  final List<String> warnings;

  const _GoodLightingCard({
    required this.qualityLabel,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    final lower = qualityLabel.toLowerCase();

    final bool isGood = // ignore: unused_local_variable
        warnings.isEmpty || lower.contains('good') || qualityLabel.contains('✅');

    final bool isModerate =
        lower.contains('moderate') || lower.contains('dim') || lower.contains('⚠️');

    final bool isLow =
        lower.contains('low') ||
        lower.contains('too dark') ||
        lower.contains('no face') ||
        lower.contains('move closer');

    String title;
    String subtitle;
    String statusText;
    IconData statusIcon;

    if (isLow) {
      title = 'Lighting Needs Fix';
      subtitle = warnings.isNotEmpty
          ? warnings.first
          : 'Move to a brighter area and face the camera.';
      statusText = 'Fix';
      statusIcon = Icons.warning_amber_rounded;
    } else if (isModerate) {
      title = 'Lighting Is Okay';
      subtitle = warnings.isNotEmpty
          ? warnings.first
          : 'Try brighter and more even lighting.';
      statusText = 'Okay';
      statusIcon = Icons.info_rounded;
    } else {
      title = 'Good Lighting';
      subtitle = 'Natural light gives the most accurate results.';
      statusText = 'Good';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9E9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEF6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLow ? Icons.warning_amber_rounded : Icons.wb_sunny_outlined,
              color: const Color(0xFFFF4D97),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF171725),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF74747A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  statusIcon,
                  color: const Color(0xFFFF4D97),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Color(0xFFFF4D97),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool showDot;

  const _CameraBadge({
    required this.icon,
    required this.text,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showDot) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF30D158),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LookDropdownWrapper extends StatelessWidget {
  final Widget child;

  const _LookDropdownWrapper({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
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
                'Choose Your Look',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171725),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFB6D4),
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'You can change your look later',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Keep existing FaceGuidePainter unchanged
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const dotRadius = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final positions = [0, 45, 90, 135, 180, 225, 270, 315];

    for (final angle in positions) {
      final radian = angle * 3.14159 / 180;
      final x = center.dx + radius * cos(radian);
      final y = center.dy + radius * sin(radian);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
// main.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' show cos, sin;

import 'skin_analyzer.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

import 'instructions_page.dart';
import 'look_engine.dart';
import 'look_picker.dart';
import 'painters/makeup_overlay_painter.dart';
import 'scan_result_page.dart';
import 'auth/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  CameraDescription? frontCamera;
  try {
    final cameras = await availableCameras();
    frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  } catch (e) {
    // Camera not available (common on web or emulators)
    debugPrint('Camera access error: $e');
  }

  runApp(App(frontCamera: frontCamera));
}

class App extends StatelessWidget {
  final CameraDescription? frontCamera;
  const App({super.key, required this.frontCamera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceTune - Beauty & Style',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFFF4D97),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D97),
          primary: const Color(0xFFFF4D97),
        ),
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Camera Screen widget for use in navigation
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;
  const CameraScreen({super.key, required this.camera, this.scannedItem});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return FaceScanPage(camera: widget.camera, scannedItem: widget.scannedItem);
  }
}

class FaceScanPage extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;
  const FaceScanPage({super.key, required this.camera, this.scannedItem});

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage> {
  CameraController? _controller;
  bool _busy = false;
  bool _isFrontCamera = true;

  // ignore: unused_field
  XFile? _capturedFile;
  ui.Image? _capturedUiImage;
  Face? _detectedFace;

  FaceProfile? _faceProfile;
  LookResult? _look;

  // ✅ User-controlled intensity (opacity) for makeup overlay
  double _intensity = 0.75;

  // ✅ Day 2: Post-scan quality feedback

  // ✅ Global luminance
  double _sceneLuminance = 0.50;

  // ✅ NEW: per-cheek luminance (0..1)
  double _leftCheekLum = 0.50;
  double _rightCheekLum = 0.50;

  // ===== Live scan quality (Day 2 upgrade) =====
  bool _liveRunning = false;
  DateTime _lastLiveTick = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _liveInterval = Duration(milliseconds: 450);

  String _liveQualityLabel = 'Point camera at your face…';
  List<String> _liveWarnings = [];
  // ignore: unused_field
  double _liveBrightness = 0.0;

  // ✅ Rotation + UV Swap toggles
  InputImageRotation _liveRotation = InputImageRotation.rotation270deg;
  bool _swapUV = false;

  // ✅ Auto-capture when lighting is good
  bool _autoCapture = false;
  int _goodQualityFrameCount = 0;
  static const int _goodQualityThreshold = 3; // Require 3+ consecutive good frames

  // ✅ Persistence for face detection
  int _noFaceStreak = 0;
  Face? _lastDetectedFace;

  // ✅ NEW: Look picker state
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

  String _status = 'Tap "Capture & Scan" to start.';

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
        _isFrontCamera = widget.camera.lensDirection == CameraLensDirection.front;
      });
      await _startLiveQuality(controller);
    } catch (e) {
      setState(() => _status = 'Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      // Dispose old controller
      await _controller?.dispose();
      _stopLiveQuality();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera available');
        return;
      }

      CameraDescription newCamera;

      if (_isFrontCamera) {
        // Switch to back camera
        final backCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras[0],
        );
        newCamera = backCam;
      } else {
        // Switch to front camera
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras[0],
        );
        newCamera = frontCam;
      }

      final controller = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isFrontCamera = newCamera.lensDirection == CameraLensDirection.front;
        _status = _isFrontCamera ? 'Switched to Front Camera' : 'Switched to Back Camera';
      });

      await _startLiveQuality(controller);
    } catch (e) {
      setState(() => _status = 'Camera switch error: $e');
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

  // ✅ Global scene luminance estimation (0..1)
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

        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b);
        sum += lum;
        count++;
      }
    }

    if (count == 0) return 0.5;
    return (sum / count).clamp(0.0, 1.0);
  }

  // ✅ NEW: average luminance inside a rectangle (0..1)
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

        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b);
        sum += lum;
        count++;
      }
    }

    if (count == 0) return 0.5;
    return (sum / count).clamp(0.0, 1.0);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List nv21 = Uint8List(width * height + (width * height ~/ 2));
    int index = 0;

    for (int row = 0; row < height; row++) {
      final int yRowStart = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[index++] = yPlane[yRowStart + col];
      }
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      final int uvRowStart = row * uvRowStride;
      for (int col = 0; col < uvWidth; col++) {
        final int uvIndex = uvRowStart + col * uvPixelStride;
        final u = uPlane[uvIndex];
        final v = vPlane[uvIndex];

        if (_swapUV) {
          nv21[index++] = u;
          nv21[index++] = v;
        } else {
          nv21[index++] = v;
          nv21[index++] = u;
        }
      }
    }

    return nv21;
  }

  InputImage _inputImageFromCameraImageNv21(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length != 3) {
      throw Exception('Unsupported camera stream: group=${image.format.group}, planes=${image.planes.length}');
    }

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
    return count == 0 ? 0 : (sum / count);
  }

  String _brightnessLabel(double b) {
    if (b < 60) return 'Too dark';
    if (b < 90) return 'Dim';
    if (b < 170) return 'Good';
    return 'Very bright';
  }

  bool _isFaceNearEdge(Face face, int imgW, int imgH) {
    final b = face.boundingBox;

    final cx = (b.left + b.right) / 2;
    final cy = (b.top + b.bottom) / 2;

    final marginX = imgW * 0.15;
    final marginY = imgH * 0.15;

    final insideX = cx > marginX && cx < (imgW - marginX);
    final insideY = cy > marginY && cy < (imgH - marginY);

    return !(insideX && insideY);
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
    } else if (brightness > 210) {
      warnings.add('Very bright. Avoid harsh light directly hitting the face.');
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

    if (_isFaceNearEdge(face, imgW, imgH)) {
      warnings.add("Center your face. It's too close to the edge.");
    }

    return warnings;
  }

  String _liveQualityFromWarnings(List<String> w) {
    if (w.isEmpty) return 'Good ✅';
    if (w.length == 1) return 'Moderate ⚠️';
    return 'Low ⚠️';
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

        debugPrint('LIVE faces: ${faces.length}  img=${image.width}x${image.height}  rotation=$_liveRotation  swapUV=$_swapUV');

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

        final showNoFace = _noFaceStreak >= 3;
        final faceForWarnings = showNoFace ? null : face;

        final warnings = _buildLiveWarnings(
          face: faceForWarnings,
          imgW: image.width,
          imgH: image.height,
          brightness: brightness,
        );

        // ✅ Auto-capture when quality is good and auto-capture is enabled
        bool isQualityGood = warnings.isEmpty && brightness >= 90 && brightness <= 210;

        if (_autoCapture && isQualityGood && !_busy) {
          _goodQualityFrameCount++;
          if (_goodQualityFrameCount >= _goodQualityThreshold) {
            _goodQualityFrameCount = 0;
            _autoCapture = false; // Disable auto-capture after triggering
            _stopLiveQuality(); // Stop the stream before capturing
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              _captureAndScan();
            }
            return;
          }
        } else {
          _goodQualityFrameCount = 0;
        }

        if (mounted) {
          setState(() {
            _liveBrightness = brightness;
            _liveWarnings = warnings;
            _liveQualityLabel =
                '${_liveQualityFromWarnings(warnings)} • ${_brightnessLabel(brightness)}';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _liveQualityLabel = 'Live Scan Quality: Error (see logs)';
            _liveWarnings = ['Live analyzer error: $e'];
          });
        }
        debugPrint('LIVE ANALYZER ERROR: $e');
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
    final severe = _liveWarnings.any((w) =>
        w.toLowerCase().contains('too dark') ||
        w.toLowerCase().contains('center your face') ||
        w.toLowerCase().contains('move closer') ||
        w.toLowerCase().contains('no face detected'));

    return !severe;
  }

  void _showCaptureBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fix live scan tips first (lighting/center/closer) before capturing.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleUVSwap() {
    setState(() {
      _swapUV = !_swapUV;
    });
  }

  void _toggleAutoCapture() {
    setState(() {
      _autoCapture = !_autoCapture;
      _goodQualityFrameCount = 0; // Reset counter
    });
  }

  Future<void> _captureAndScan() async {
    if (!_canCaptureNow()) {
      _showCaptureBlockedMessage();
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_busy) return;

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
        setState(() => _status = 'No face detected. Try better lighting and face the camera.');
        return;
      }

      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;

      // ✅ NEW: per-cheek luminance sampling
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
      final look = LookEngine.fromPreset(_selectedLook, profile: profile);

      setState(() {
        _detectedFace = face;
        _faceProfile = profile;
        _look = look;
        _status = 'Done ✅ Navigating to results…';
      });

      // ✅ Navigate immediately to results after successful detection
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanResultPage(
              scannedImagePath: _capturedFile?.path,
              scannedItem: widget.scannedItem,
              detectedFace: face,
              faceProfile: profile,
              look: look,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        await _startLiveQuality(c);
      }
    }
  }

  void _openInstructions() {
    final look = _look;
    if (look == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstructionsPage(look: look),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final bool showPreview = _capturedUiImage != null && _detectedFace != null && _look != null;
    final bool showSlider = showPreview && _faceProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Scan', style: TextStyle(fontSize: 16)),
        toolbarHeight: 48,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Controls at top
            Container(
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quality: $_liveQualityLabel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                            if (_liveWarnings.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _liveWarnings.take(1).join(' • '),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _toggleAutoCapture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _autoCapture ? const Color(0xFFFF4D97) : Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              minimumSize: const Size(0, 0),
                            ),
                            child: Text(
                              'Auto: ${_autoCapture ? 'ON' : 'OFF'}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: _toggleUVSwap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              minimumSize: const Size(0, 0),
                            ),
                            child: Text(
                              'UV: ${_swapUV ? 'Swap' : 'Norm'}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _switchCamera,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D97),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              minimumSize: const Size(0, 0),
                            ),
                            icon: Icon(
                              _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                              size: 12,
                            ),
                            label: Text(
                              _isFrontCamera ? 'Front' : 'Back',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Camera in bordered container
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF4D97), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: controller == null || !controller.value.isInitialized
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)))
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
                              
                              if (_busy)
                                const Align(
                                  alignment: Alignment.center,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF4D97),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Makeup Look Picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LookPicker(
                value: _selectedLook,
                onChanged: (v) => setState(() => _selectedLook = v),
              ),
            ),

            // Preview (if available)
            if (showPreview)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _capturedUiImage!.width.toDouble(),
                            height: _capturedUiImage!.height.toDouble(),
                            child: Builder(
                              builder: (context) {
                                final bool isDebug = _selectedLook == MakeupLookPreset.debugPainterTest;
                                return CustomPaint(
                                  painter: MakeupOverlayPainter(
                                    image: _capturedUiImage!,
                                    face: _detectedFace!,
                                    lipstickColor: _look!.lipstickColor,
                                    blushColor: _look!.blushColor,
                                    eyeshadowColor: _look!.eyeshadowColor,
                                    intensity: _intensity,
                                    faceShape: _faceProfile!.faceShape,
                                    preset: _selectedLook,
                                    debugMode: isDebug,
                                    isLiveMode: false,
                                    eyelinerStyle: LookEngine
                                        .configFromPreset(_selectedLook, profile: _faceProfile)
                                        .eyelinerStyle,
                                    skinColor: Color.fromARGB(
                                      255,
                                      _faceProfile!.avgR,
                                      _faceProfile!.avgG,
                                      _faceProfile!.avgB,
                                    ),
                                    sceneLuminance: _sceneLuminance,
                                    leftCheekLuminance: _leftCheekLum,
                                    rightCheekLuminance: _rightCheekLum,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showSlider)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
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
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: FilledButton.icon(
                              onPressed: (_faceProfile != null && _look != null) ? _openInstructions : null,
                              icon: const Icon(Icons.list_alt, size: 16),
                              label: const Text('View Instructions', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanResultPage(scannedItem: widget.scannedItem),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.preview, size: 16),
                              label: const Text('View Result Screen', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF4D97),
                                side: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(_status, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
              ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _busy || !_canCaptureNow() ? null : _captureAndScan,
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('Capture & Scan', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Face Guide Painter - draws guide dots around the face circle
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw guide dots around the circle
    const dotRadius = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dots at key positions (top, bottom, left, right, and diagonals)
    final positions = [
      0, 45, 90, 135, 180, 225, 270, 315
    ];

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

// Camera Frame Painter - draws corner borders
class CameraFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 40.0;
    const margin = 20.0;

    // Top-left corner
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin + cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin, margin + cornerLength),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - cornerLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
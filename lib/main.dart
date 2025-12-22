import 'dart:io';
import 'dart:ui' as ui;
import 'skin_analyzer.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'instructions_page.dart';
import 'look_engine.dart';
import 'makeup_overlay_painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  final cameras = await availableCameras();
  final front = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  runApp(App(frontCamera: front));
}

class App extends StatelessWidget {
  final CameraDescription frontCamera;
  const App({super.key, required this.frontCamera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makeup AI Capstone',
      theme: ThemeData(useMaterial3: true),
      home: FaceScanPage(camera: frontCamera),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FaceScanPage extends StatefulWidget {
  final CameraDescription camera;
  const FaceScanPage({super.key, required this.camera});

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

  // ✅ NEW: user-controlled intensity (opacity) for makeup overlay
  double _intensity = 0.75;

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
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _status = 'Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _captureAndScan() async {
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

      // optional: reset intensity when scanning again
      _intensity = 0.75;
    });

    try {
      // Capture
      final file = await controller.takePicture();
      final uiImage = await _loadUiImageFromFile(file.path);

      setState(() {
        _capturedFile = file;
        _capturedUiImage = uiImage;
        _status = 'Detecting face…';
      });

      // ML Kit detection
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Try better lighting and face the camera.');
        return;
      }

      // Choose largest face
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;

      // ===========================================
      // Skin Analysis Integration
      // ===========================================
      setState(() => _status = 'Analyzing skin tone…');

      final skin = await SkinAnalyzer.analyze(uiImage, face);
      final profile = FaceProfile.fromAnalysis(face, skin);
      final look = LookEngine.recommendLook(profile);
      // ===========================================

      setState(() {
        _detectedFace = face;
        _faceProfile = profile;
        _look = look;
        _status = 'Done ✅ Tap "View Instructions".';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _openInstructions() {
    final profile = _faceProfile;
    final look = _look;
    if (profile == null || look == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstructionsPage(profile: profile, look: look),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final bool showPreview = _capturedUiImage != null && _detectedFace != null && _look != null;
    final bool showSlider = showPreview && _faceProfile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Scan → Makeup Preview')),
      body: Column(
        children: [
          Expanded(
            child: controller == null || !controller.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      CameraPreview(controller),
                      if (_busy)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
          ),

          // Preview section (captured image + overlay)
          if (showPreview)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 280,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _capturedUiImage!.width.toDouble(),
                          height: _capturedUiImage!.height.toDouble(),
                          child: CustomPaint(
                            painter: MakeupOverlayPainter(
                              image: _capturedUiImage!,
                              face: _detectedFace!,
                              lipstickColor: _look!.lipstickColor,
                              blushColor: _look!.blushColor,
                              eyeshadowColor: _look!.eyeshadowColor,

                              // ✅ NEW: pass intensity + face shape
                              intensity: _intensity,
                              faceShape: _faceProfile?.faceShape ?? FaceShape.unknown,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ✅ NEW: slider
                  if (showSlider)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Text('Opacity'),
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
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status),
            ),

          if (_faceProfile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ProfileChipRow(profile: _faceProfile!),
            ),

          // Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _captureAndScan,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture & Scan'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: (_faceProfile != null && _look != null) ? _openInstructions : null,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View Instructions'),
                    ),
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

class _ProfileChipRow extends StatelessWidget {
  final FaceProfile profile;
  const _ProfileChipRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Chip(label: Text('Tone: ${profile.skinTone.name}')),
        Chip(label: Text('Undertone: ${profile.undertone.name}')),
        Chip(label: Text('Face shape: ${profile.faceShape.name}')),
        Chip(label: Text('RGB: ${profile.avgR},${profile.avgG},${profile.avgB}')),
        Chip(label: Text('Skin conf: ${(profile.skinConfidence * 100).toStringAsFixed(0)}%')),
      ],
    );
  }
}

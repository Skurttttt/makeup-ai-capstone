// lib/screens/scan_tab.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  CameraDescription? _frontCamera;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      if (!mounted) return;
      setState(() {
        _frontCamera = front;
        _cameraError = null;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera preview is not available on this platform yet.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Unable to open camera: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan Face',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _cameraError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.black45),
                    const SizedBox(height: 12),
                    Text(
                      _cameraError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : _frontCamera == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)))
              : CameraScreen(camera: _frontCamera!, scannedItem: null),
    );
  }
}

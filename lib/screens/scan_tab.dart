// lib/screens/scan_tab.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../main.dart';

class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  CameraDescription? _frontCamera;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    setState(() {
      _frontCamera = front;
    });
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
      body: _frontCamera == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)))
          : CameraScreen(camera: _frontCamera!, scannedItem: null),
    );
  }
}

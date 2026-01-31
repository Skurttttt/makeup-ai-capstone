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
  String? _scanType; // 'face', 'product', or null
  String? _selectedProduct; // for product scans

  final List<Map<String, dynamic>> makeupItems = [
    {'name': 'Lips', 'icon': Icons.color_lens, 'color': Colors.red},
    {'name': 'Eyes', 'icon': Icons.remove_red_eye, 'color': Colors.purple},
    {'name': 'Foundation', 'icon': Icons.face, 'color': Colors.amber},
    {'name': 'Blush', 'icon': Icons.favorite, 'color': Colors.pink},
    {'name': 'Eyebrow', 'icon': Icons.edit, 'color': Colors.brown},
    {'name': 'Eyeliner', 'icon': Icons.brush, 'color': Colors.black},
  ];

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
    // Main selection screen
    if (_scanType == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Face Scanner',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What would you like to scan?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose between scanning your face for makeup looks or individual products',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scan Face Option
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _scanType = 'face';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF4D97),
                              const Color(0xFFFF4D97).withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D97).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan Face',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Get personalized makeup looks for your face',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Scan Product Option
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _scanType = 'product';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF4D97),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D97).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.shopping_bag,
                                size: 60,
                                color: Color(0xFFFF4D97),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan Product',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find similar products based on your makeup items',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Scan Face - go directly to camera
    if (_scanType == 'face') {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              setState(() {
                _scanType = null;
              });
            },
          ),
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

    // Scan Product - show product selection
    if (_scanType == 'product' && _selectedProduct == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              setState(() {
                _scanType = null;
              });
            },
          ),
          title: const Text(
            'Scan Product',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What would you like to scan?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select a makeup item to get personalized recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: makeupItems.length,
                  itemBuilder: (context, index) {
                    final item = makeupItems[index];
                    return _buildMakeupItemCard(
                      name: item['name'],
                      icon: item['icon'],
                      color: item['color'],
                      onTap: () {
                        setState(() {
                          _selectedProduct = item['name'];
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Scan Product with item selected - show camera
    if (_scanType == 'product' && _selectedProduct != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              setState(() {
                _selectedProduct = null;
              });
            },
          ),
          title: Text(
            'Scan $_selectedProduct',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: _frontCamera == null
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)))
            : CameraScreen(camera: _frontCamera!, scannedItem: _selectedProduct),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMakeupItemCard({
    required String name,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

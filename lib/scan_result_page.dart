// lib/scan_result_page.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'look_engine.dart';
import 'instructions_page.dart';
import 'painters/makeup_overlay_painter.dart';
import 'skin_analyzer.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ScanResultPage extends StatefulWidget {
  final String? scannedImagePath;
  final String? scannedItem;
  final Face? detectedFace;
  final FaceProfile? faceProfile;
  final LookResult? look;

  const ScanResultPage({
    super.key,
    this.scannedImagePath,
    this.scannedItem,
    this.detectedFace,
    this.faceProfile,
    this.look,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  String selectedFilter = 'Natural';
  final List<String> filters = ['Natural', 'Everyday', 'Glam'];
  ui.Image? _uiImage;
  double _intensity = 0.75;
  final MakeupLookPreset _currentPreset = MakeupLookPreset.softGlam;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.scannedImagePath != null) {
      final bytes = await File(widget.scannedImagePath!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _uiImage = frame.image;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Style Preview',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scanned Photo Container
                  _buildPhotoContainer(),
                  const SizedBox(height: 12),

                  // Opacity slider (after capture)
                  if (_uiImage != null && widget.look != null)
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
                  const SizedBox(height: 24),

                  // Why this look suits you
                  _buildWhyThisLookSection(),
                  const SizedBox(height: 24),

                  // Recommended Products Section
                  if (widget.scannedItem != null) ...[
                    Text(
                      'Recommended Products for ${widget.scannedItem}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRecommendedProducts(),
                  ],

                  const SizedBox(height: 80), // Space for bottom button
                ],
              ),
            ),
          ),

          // Fixed Bottom Buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildPhotoContainer() {
    final double? aspect = _uiImage != null
        ? (_uiImage!.width.toDouble() / _uiImage!.height.toDouble())
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D97).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: AspectRatio(
        aspectRatio: aspect ?? (3 / 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _uiImage != null && widget.detectedFace != null && widget.look != null
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _uiImage!.width.toDouble(),
                      height: _uiImage!.height.toDouble(),
                      child: CustomPaint(
                        painter: MakeupOverlayPainter(
                          image: _uiImage!,
                          face: widget.detectedFace!,
                          lipstickColor: widget.look!.lipstickColor,
                          blushColor: widget.look!.blushColor,
                          eyeshadowColor: widget.look!.eyeshadowColor,
                          intensity: _intensity,
                          faceShape: widget.faceProfile?.faceShape ?? FaceShape.oval,
                          preset: MakeupLookPreset.softGlam,
                          debugMode: false,
                          isLiveMode: false,
                          eyelinerStyle: LookEngine.configFromPreset(_currentPreset, profile: widget.faceProfile).eyelinerStyle,
                          skinColor: widget.faceProfile != null
                              ? Color.fromARGB(
                                  255,
                                  widget.faceProfile!.avgR,
                                  widget.faceProfile!.avgG,
                                  widget.faceProfile!.avgB,
                                )
                              : Colors.transparent,
                          sceneLuminance: 0.5,
                          leftCheekLuminance: 0.5,
                          rightCheekLuminance: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
              : widget.scannedImagePath != null
                  ? Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.file(
                          File(widget.scannedImagePath!),
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      ),
                    )
                  : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.face_retouching_natural,
            size: 80,
            color: const Color(0xFFFF4D97).withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Photo Preview',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyThisLookSection() {
    final profile = widget.faceProfile;
    final look = widget.look;

    if (profile == null || look == null) {
      return const SizedBox.shrink();
    }

    String toneLabel(SkinTone tone) {
      switch (tone) {
        case SkinTone.light:
          return 'light';
        case SkinTone.medium:
          return 'medium';
        case SkinTone.tan:
          return 'tan';
        case SkinTone.deep:
          return 'deep';
      }
    }

    String undertoneLabel(Undertone undertone) {
      switch (undertone) {
        case Undertone.warm:
          return 'warm';
        case Undertone.cool:
          return 'cool';
        case Undertone.neutral:
          return 'neutral';
      }
    }

    String faceShapeLabel(FaceShape shape) {
      switch (shape) {
        case FaceShape.oval:
          return 'oval';
        case FaceShape.round:
          return 'round';
        case FaceShape.square:
          return 'square';
        case FaceShape.heart:
          return 'heart';
        case FaceShape.unknown:
          return 'balanced';
      }
    }

    final bullets = <String>[
      'Designed to complement your ${undertoneLabel(profile.undertone)} undertone.',
      'Balanced for your ${toneLabel(profile.skinTone)} skin tone.',
      'Placement flatters your ${faceShapeLabel(profile.faceShape)} face shape.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD3E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why this look suits you',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFFFF4D97)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilterOptions() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF4D97) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF4D97) : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHowToApplySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to Apply',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildApplyCard(
          step: '1',
          title: 'Prep Your Skin',
          description: 'Start with a clean, moisturized face for best results.',
          icon: Icons.face,
        ),
        const SizedBox(height: 12),
        _buildApplyCard(
          step: '2',
          title: 'Apply Foundation',
          description: 'Use a beauty blender to apply foundation evenly.',
          icon: Icons.brush,
        ),
        const SizedBox(height: 12),
        _buildApplyCard(
          step: '3',
          title: 'Set with Powder',
          description: 'Lightly dust powder to set your makeup for all-day wear.',
          icon: Icons.star,
        ),
      ],
    );
  }

  Widget _buildApplyCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D97).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFFFF4D97),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D97),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFFFF4D97),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 18, color: Color(0xFFFF4D97)),
                      SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF4D97),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.look != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InstructionsPage(look: widget.look!),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF4D97),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Tutorial',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showBuyProductDialog();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFFF4D97),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Buy Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProducts() {
    final products = _getProductsByItem(widget.scannedItem ?? '');
    
    return Column(
      children: List.generate(
        products.length,
        (index) {
          final product = products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: (product['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      product['icon'] as IconData,
                      size: 40,
                      color: product['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product['brand'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              product['rating'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              product['price'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF4D97),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product['name']} added to cart'),
                          backgroundColor: const Color(0xFFFF4D97),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D97),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  List<Map<String, dynamic>> _getProductsByItem(String item) {
    final productMap = {
      'Lips': [
        {
          'name': 'Ruby Red Lipstick',
          'brand': 'Glamour Beauty',
          'price': '\$24.99',
          'rating': '4.8',
          'icon': Icons.color_lens,
          'color': Colors.red,
        },
        {
          'name': 'Rosy Pink Matte',
          'brand': 'Elegant Cosmetics',
          'price': '\$19.99',
          'rating': '4.7',
          'icon': Icons.color_lens,
          'color': Colors.pink,
        },
        {
          'name': 'Nude Bliss',
          'brand': 'Natural Beauty',
          'price': '\$22.99',
          'rating': '4.6',
          'icon': Icons.color_lens,
          'color': Colors.brown,
        },
      ],
      'Eyes': [
        {
          'name': 'Shimmer Eyeshadow Palette',
          'brand': 'Eye Couture',
          'price': '\$34.99',
          'rating': '4.9',
          'icon': Icons.remove_red_eye,
          'color': Colors.purple,
        },
        {
          'name': 'Golden Hour Palette',
          'brand': 'Sun Glow',
          'price': '\$29.99',
          'rating': '4.8',
          'icon': Icons.remove_red_eye,
          'color': Colors.amber,
        },
        {
          'name': 'Smokey Noir Set',
          'brand': 'Dark Matter',
          'price': '\$27.99',
          'rating': '4.7',
          'icon': Icons.remove_red_eye,
          'color': Colors.grey,
        },
      ],
      'Foundation': [
        {
          'name': 'Perfect Coverage Foundation',
          'brand': 'Pro Base',
          'price': '\$39.99',
          'rating': '4.8',
          'icon': Icons.face,
          'color': Colors.amber,
        },
        {
          'name': 'Flawless Finish',
          'brand': 'Skin Perfect',
          'price': '\$35.99',
          'rating': '4.7',
          'icon': Icons.face,
          'color': Colors.orange,
        },
        {
          'name': 'Natural Glow Base',
          'brand': 'Pure Beauty',
          'price': '\$32.99',
          'rating': '4.6',
          'icon': Icons.face,
          'color': Colors.brown,
        },
      ],
      'Blush': [
        {
          'name': 'Rose Blush',
          'brand': 'Cheek Perfection',
          'price': '\$22.99',
          'rating': '4.8',
          'icon': Icons.favorite,
          'color': Colors.pink,
        },
        {
          'name': 'Coral Peach Blush',
          'brand': 'Warm Tones',
          'price': '\$21.99',
          'rating': '4.7',
          'icon': Icons.favorite,
          'color': Colors.deepOrange,
        },
        {
          'name': 'Sunset Bronze',
          'brand': 'Bronzer Blend',
          'price': '\$24.99',
          'rating': '4.9',
          'icon': Icons.favorite,
          'color': Colors.brown,
        },
      ],
      'Eyebrow': [
        {
          'name': 'Brow Defining Pencil',
          'brand': 'Brow Expert',
          'price': '\$18.99',
          'rating': '4.7',
          'icon': Icons.edit,
          'color': Colors.brown,
        },
        {
          'name': 'Micro Brow Pen',
          'brand': 'Precision Beauty',
          'price': '\$21.99',
          'rating': '4.8',
          'icon': Icons.edit,
          'color': Colors.grey,
        },
        {
          'name': 'Brow Filler Gel',
          'brand': 'Hold Strong',
          'price': '\$17.99',
          'rating': '4.6',
          'icon': Icons.edit,
          'color': Colors.blueGrey,
        },
      ],
      'Eyeliner': [
        {
          'name': 'Waterproof Liquid Eyeliner',
          'brand': 'Line Perfect',
          'price': '\$16.99',
          'rating': '4.8',
          'icon': Icons.brush,
          'color': Colors.black,
        },
        {
          'name': 'Gel Eyeliner',
          'brand': 'Smooth Lines',
          'price': '\$19.99',
          'rating': '4.7',
          'icon': Icons.brush,
          'color': Colors.indigo,
        },
        {
          'name': 'Felt Tip Eyeliner',
          'brand': 'Precision Ink',
          'price': '\$18.99',
          'rating': '4.9',
          'icon': Icons.brush,
          'color': Colors.black87,
        },
      ],
    };

    return productMap[item] ?? [];
  }

  void _showBuyProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Buy Products',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will take you to our recommended products for your selected look.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to product page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

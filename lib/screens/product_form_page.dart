import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive.dart';
import '../helpers/color_classification_helper.dart';

class ProductFormPage extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic>? existingProduct;

  const ProductFormPage({
    super.key,
    required this.businessId,
    this.existingProduct,
  });

  bool get isEditing => existingProduct != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const Color primaryPink = Color(0xFFFF4D97);
  static const Color bgColor = Color(0xFFFFF9FB);

  static const List<String> _skinTypeOptions = ['Dry', 'Oily', 'Combination', 'Sensitive', 'Normal'];
  static const List<String> _finishTypeOptions = ['Matte', 'Dewy', 'Natural', 'Glossy', 'Velvet', 'Soft Matte'];
  static const List<String> _coverageLevelOptions = ['Light', 'Medium', 'Full', 'Buildable'];

  static const List<String> _fallbackCategories = [
    'Primer',
    'Lipstick',
    'Blush',
    'Contour',
    'Setting Spray',
    'Eyebrow',
    'Eyeliner',
    'Eyeshadow',
    'Concealer',
    'Tools & Brushes',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _currencyController = TextEditingController(text: 'PHP');
  final _stockController = TextEditingController(text: '0');
  final _imageUrlController = TextEditingController();
  final _shadeNameController = TextEditingController(text: 'Bliss');
  final _hexCodeController = TextEditingController(text: '#D88C9A');
  final Set<String> _selectedSkinTypes = {};
  final Set<String> _selectedFinishTypes = {};
  final Set<String> _selectedCoverageLevels = {};

  final _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final List<Color> _extractedColors = [];
  bool _extractingColors = false;

  String _category = '';
  List<String> _categoryOptions = [];
  bool _loadingCategories = true;
  String _colorFamily = 'Rosy Pink';
  bool _morenaFriendly = false;
  bool _beginnerFriendly = false;
  bool _budgetFriendly = false;
  bool _studentFriendly = false;
  final Set<String> _selectedLookTags = {};
  bool _saving = false;

  // ADDED: Clean production-level getter for auto-detected undertones
  List<String> get _autoDetectedUndertones {
    return ColorClassificationHelper
        .classify(_hexCodeController.text)
        .undertones;
  }

  // Auto-detected shade depth (no manual selection needed)
  String _getAutoDetectedShadeDepth() {
    return _detectShadeDepthFromHex(_hexCodeController.text);
  }

  // Uses ColorClassificationHelper
  String _detectShadeDepthFromHex(String hexCode) {
    return ColorClassificationHelper.classify(hexCode).shadeDepth;
  }

  // Uses ColorClassificationHelper
  List<String> _detectCompatibleUndertonesFromHex(String hexCode) {
    return ColorClassificationHelper.classify(hexCode).undertones;
  }

  // Uses ColorClassificationHelper
  String _detectColorFamilyFromHex(String hexCode) {
    return ColorClassificationHelper.classify(hexCode).colorFamily;
  }

  // Strict target area detection
  String _detectTargetArea(String category) {
    final c = category.toLowerCase();

    if (c.contains('lipstick') ||
        c.contains('lip tint') ||
        c.contains('lip gloss') ||
        c.contains('lip')) {
      return 'lips';
    }

    if (c.contains('blush')) return 'blush';
    if (c.contains('contour')) return 'contour';
    if (c.contains('eyeshadow') || c.contains('eye shadow')) return 'eyeshadow';
    if (c.contains('eyeliner') || c.contains('eye liner')) return 'eyeliner';
    if (c.contains('eyebrow') || c.contains('brow')) return 'brows';
    if (c.contains('primer')) return 'primer';
    if (c.contains('setting') || c.contains('mist') || c.contains('fix')) {
      return 'setting';
    }
    if (c.contains('foundation')) return 'foundation';
    if (c.contains('concealer')) return 'concealer';
    if (c.contains('powder')) return 'powder';

    return 'general';
  }

  void _syncColorFamilyFromHex() {
    final hex = _hexCodeController.text.trim();

    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return;

    final detectedFamily = _detectColorFamilyFromHex(hex);

    if (_colorFamily != detectedFamily) {
      setState(() {
        _colorFamily = detectedFamily;
      });
    }
  }

  int _channelTo255(num channel) {
    if (channel <= 1) {
      return (channel * 255).round().clamp(0, 255);
    }
    return channel.round().clamp(0, 255);
  }

  @override
  void initState() {
    super.initState();
    _hexCodeController.addListener(_syncColorFamilyFromHex);
    _loadCategoryOptions();
    if (widget.isEditing) _populateFromExisting();

    // Add listener to auto-detect shade depth when hex code changes
    _hexCodeController.addListener(_onHexCodeChanged);
  }

  void _onHexCodeChanged() {
    // Just trigger a rebuild to update any UI that shows the detected depth
    if (mounted) setState(() {});
  }

  void _populateFromExisting() {
    final p = widget.existingProduct!;
    _nameController.text = (p['name'] ?? '').toString();
    _descriptionController.text = (p['description'] ?? '').toString();
    final price = p['price'];
    if (price != null) _priceController.text = price.toString();
    final currency = (p['currency'] ?? '').toString();
    if (currency.isNotEmpty) _currencyController.text = currency;
    final stock = p['stock_quantity'];
    if (stock != null) _stockController.text = stock.toString();
    _imageUrlController.text = (p['image_url'] ?? '').toString();
    final shade = (p['shade_name'] ?? '').toString();
    if (shade.isNotEmpty) _shadeNameController.text = shade;
    final hex = (p['hex_code'] ?? '').toString();
    if (hex.isNotEmpty) _hexCodeController.text = hex;
    final family = (p['color_family'] ?? '').toString();
    if (family.isNotEmpty) _colorFamily = family;
    _morenaFriendly = p['morena_friendly'] == true;
    _beginnerFriendly = p['beginner_friendly'] == true;
    _budgetFriendly = p['budget_friendly'] == true;
    _studentFriendly = p['student_friendly'] == true;

    _selectedSkinTypes
      ..clear()
      ..addAll(_splitCsv(p['compatible_skin_tone']));
    _selectedFinishTypes
      ..clear()
      ..addAll(_splitCsv(p['finish_type']));
    _selectedCoverageLevels
      ..clear()
      ..addAll(_splitCsv(p['coverage_level']));
    _selectedLookTags
      ..clear()
      ..addAll(_splitCsv(p['compatible_looks']));
  }

  Iterable<String> _splitCsv(dynamic value) {
    if (value == null) return const [];
    return value
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
  }

  @override
  void dispose() {
    _hexCodeController.removeListener(_syncColorFamilyFromHex);
    _hexCodeController.removeListener(_onHexCodeChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    _shadeNameController.dispose();
    _hexCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryOptions() async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('category')
          .eq('business_id', widget.businessId);

      final merged = <String>{..._fallbackCategories};
      for (final row in response) {
        final category = (row['category'] ?? '').toString().trim();
        if (category.isNotEmpty) {
          merged.add(category);
        }
      }
      final existingCategory =
          (widget.existingProduct?['category'] ?? '').toString().trim();
      if (existingCategory.isNotEmpty) merged.add(existingCategory);
      final categories = merged.toList();
      categories.sort();

      if (mounted) {
        setState(() {
          _categoryOptions = categories;
          _category = existingCategory.isNotEmpty
              ? existingCategory
              : (_categoryOptions.isNotEmpty ? _categoryOptions.first : '');
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryOptions = List<String>.from(_fallbackCategories);
          _category = _categoryOptions.isNotEmpty ? _categoryOptions.first : '';
          _loadingCategories = false;
        });
      }
    }
  }

  // Helper method to auto-generate compatible looks
  String _generateCompatibleLooks() {
    final category = _category.toLowerCase();
    // UPDATED: Now uses the getter for undertones
    final undertones = _autoDetectedUndertones.map((e) => e.toLowerCase()).toList();
    final colorFamily = _colorFamily.toLowerCase();
    final finishTypes = _selectedFinishTypes.map((e) => e.toLowerCase()).toList();

    final looks = <String>{};

    final isGlossy = finishTypes.contains('glossy') || finishTypes.contains('dewy');
    final isMatte = finishTypes.contains('matte') || finishTypes.contains('soft matte');

    if (category.contains('lip') || category.contains('tint') || category.contains('gloss')) {
      if (colorFamily.contains('pink') || colorFamily.contains('rose') || colorFamily.contains('mauve')) {
        looks.addAll(['K-Beauty', 'Douyin', 'Clean Girl', 'Soft Glam']);
      }

      if (colorFamily.contains('berry') || colorFamily.contains('plum')) {
        looks.addAll(['Emo', 'E-Girl', 'Cherry Cola', 'Bold Editorial']);
      }

      if (colorFamily.contains('nude') || colorFamily.contains('beige') || colorFamily.contains('brown')) {
        looks.addAll(['Soft Glam', 'Natural Nude', 'Old Money', 'Latte Makeup']);
      }

      if (colorFamily.contains('red')) {
        looks.addAll(['Party Glam', 'Arab Glam', 'Bold Editorial', 'Cherry Cola']);
      }
    }

    if (category.contains('blush')) {
      if (colorFamily.contains('pink') || colorFamily.contains('rose')) {
        looks.addAll(['K-Beauty', 'Douyin', 'Coquette', 'Strawberry Makeup']);
      }

      if (colorFamily.contains('peach') || colorFamily.contains('coral')) {
        looks.addAll(['Peach Girl', 'Clean Girl', 'Soft Glam', 'Bronzed Goddess']);
      }

      if (colorFamily.contains('brown') || colorFamily.contains('terracotta')) {
        looks.addAll(['Latte Makeup', 'Old Money', 'Bronzed Goddess']);
      }
    }

    if (category.contains('eyeshadow') || category.contains('eyeliner')) {
      if (colorFamily.contains('brown') || colorFamily.contains('nude') || colorFamily.contains('beige')) {
        looks.addAll(['Soft Glam', 'Latte Makeup', 'Old Money', 'Bronzed Goddess']);
      }

      if (colorFamily.contains('black') || colorFamily.contains('plum') || colorFamily.contains('berry')) {
        looks.addAll(['Emo', 'Smokey Eyes', 'E-Girl', 'Bold Editorial']);
      }

      if (colorFamily.contains('gold') || colorFamily.contains('bronze')) {
        looks.addAll(['Golden Goddess', 'Party Glam', 'Bronzed Goddess']);
      }
    }

    if (category.contains('foundation') ||
        category.contains('concealer') ||
        category.contains('primer') ||
        category.contains('setting spray')) {
      if (isGlossy) {
        looks.addAll(['Glass Skin', 'K-Beauty', 'Clean Girl']);
      }

      if (isMatte) {
        looks.addAll(['Soft Glam', 'Old Money', 'Party Glam']);
      }

      looks.addAll(['Natural Nude', 'No Makeup Makeup']);
    }

    if (undertones.contains('warm')) {
      looks.addAll(['Bronzed Goddess', 'Latte Makeup', 'Golden Goddess', 'Peach Girl']);
    }

    if (undertones.contains('cool')) {
      looks.addAll(['K-Beauty', 'Douyin', 'Cold Girl Makeup', 'Monochrome Pink']);
    }

    if (undertones.contains('neutral')) {
      looks.addAll(['Soft Glam', 'Clean Girl', 'Natural Nude', 'Old Money']);
    }

    if (looks.isEmpty) {
      looks.addAll(['Soft Glam', 'Clean Girl', 'Natural Nude']);
    }

    return looks.take(6).join(', ');
  }

  int _getRecommendationPriority() {
    final category = _category.toLowerCase();

    if (category.contains('lip')) return 90;
    if (category.contains('blush')) return 85;
    if (category.contains('eyeshadow')) return 80;
    if (category.contains('eyeliner')) return 75;
    if (category.contains('eyebrow')) return 70;
    if (category.contains('foundation')) return 65;
    if (category.contains('concealer')) return 60;

    return 50;
  }

  double _getConfidenceWeight() {
    double weight = 1.0;

    if (_hexCodeController.text.trim().isNotEmpty) weight += 0.2;
    if (_colorFamily.trim().isNotEmpty) weight += 0.2;
    if (_getAutoDetectedShadeDepth().trim().isNotEmpty) weight += 0.2;
    if (_selectedFinishTypes.isNotEmpty) weight += 0.1;
    if (_selectedCoverageLevels.isNotEmpty) weight += 0.1;

    return weight.clamp(1.0, 2.0);
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = pickedFile.name;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _extractColorsFromImage() async {
    if (_selectedImageBytes == null) {
      _showSnackBar('Please select an image first', isError: true);
      return;
    }

    setState(() => _extractingColors = true);

    try {
      final image = img.decodeImage(_selectedImageBytes!);
      if (image == null) throw Exception('Failed to decode image');

      final colorCounts = <String, int>{};
      const int step = 15;

      for (int y = 0; y < image.height; y += step) {
        for (int x = 0; x < image.width; x += step) {
          final pixel = image.getPixelSafe(x, y);
          final a = _channelTo255(pixel.a);
          if (a < 128) continue;

          final r = _channelTo255(pixel.r);
          final g = _channelTo255(pixel.g);
          final b = _channelTo255(pixel.b);
          final hex = '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}${g.toRadixString(16).padLeft(2, '0').toUpperCase()}${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';

          colorCounts[hex] = (colorCounts[hex] ?? 0) + 1;
        }
      }

      final sortedColors = colorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topColors = sortedColors.take(8).map((e) => Color(int.parse('FF${e.key.substring(1)}', radix: 16))).toList();

      setState(() {
        _extractedColors.clear();
        _extractedColors.addAll(topColors);
      });

      if (mounted && topColors.isNotEmpty) {
        _setHexColor(topColors.first);
      }
    } catch (e) {
      _showSnackBar('Error extracting colors: $e', isError: true);
    } finally {
      if (mounted) setState(() => _extractingColors = false);
    }
  }

  void _setHexColor(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = color.green.toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = color.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
    setState(() => _hexCodeController.text = '#$r$g$b');
  }

  Color get _hexColor {
    try {
      final hex = _hexCodeController.text.replaceFirst('#', '');
      if (hex.length != 6) return Colors.pink;
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.pink;
    }
  }

  void _showColorPaletteDialog() {
    if (_extractedColors.isEmpty) {
      _extractColorsFromImage();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
          itemCount: _extractedColors.length,
          itemBuilder: (context, index) {
            final color = _extractedColors[index];
            return GestureDetector(
              onTap: () {
                _setHexColor(color);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: Colors.black12, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // Categories without a color/shade should not persist color fields.
    final catLower = _category.toLowerCase();
    final hasColor = !(catLower.contains('tool') ||
        catLower.contains('brush') ||
        catLower.contains('sponge') ||
        catLower.contains('applicator') ||
        catLower.contains('accessor') ||
        catLower == 'setting spray');

    try {
      final imageUrl = _selectedImageBytes != null
          ? await _uploadProductImage()
          : _imageUrlController.text;

      // Get complete color profile from ColorClassificationHelper
      final colorProfile =
          ColorClassificationHelper.classify(_hexCodeController.text);

      final autoDetectedShadeDepth = colorProfile.shadeDepth;
      final autoDetectedUndertones = colorProfile.undertones;
      final autoDetectedColorFamily = colorProfile.colorFamily;

      final compatibleLooks = _generateCompatibleLooks()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final targetArea = _detectTargetArea(_category);
      final recommendationPriority = _getRecommendationPriority();
      final confidenceWeight = _getConfidenceWeight();

      final payload = <String, dynamic>{
        'business_id': widget.businessId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'category': _category,
        'price': double.parse(_priceController.text),
        'currency': _currencyController.text,
        'stock_quantity': int.parse(_stockController.text),
        'image_url': imageUrl,
        'shade_name': hasColor ? _shadeNameController.text : '',
        'hex_code': hasColor ? _hexCodeController.text : '',
        
        // Backward compatibility CSV fields
        'undertone': hasColor ? autoDetectedUndertones.join(', ') : '',
        'color_family': hasColor ? autoDetectedColorFamily : '',
        'shade_depth': hasColor ? autoDetectedShadeDepth : '',
        'compatible_looks': compatibleLooks.join(', '),
        'compatible_skin_type': _selectedSkinTypes.join(', '),
        'finish_type': _selectedFinishTypes.join(', '),
        'coverage_level': _selectedCoverageLevels.join(', '),
        
        // New JSON fields for production-level recommendation matching
        'undertones': hasColor ? autoDetectedUndertones : [],
        'compatible_looks_json': compatibleLooks,
        'skin_types': _selectedSkinTypes.toList(),
        'finish_types': _selectedFinishTypes.toList(),
        'coverage_levels': _selectedCoverageLevels.toList(),
        
        // Recommendation metadata
        'target_area': targetArea,
        'recommendation_priority': recommendationPriority,
        'confidence_weight': confidenceWeight,
        
        // Flags
        'auto_generated_looks': true,
        'morena_friendly': _morenaFriendly,
        'beginner_friendly': _beginnerFriendly,
        'budget_friendly': _budgetFriendly,
        'student_friendly': _studentFriendly,
      };

      if (widget.isEditing) {
        final id = widget.existingProduct!['id'];
        await Supabase.instance.client
            .from('products')
            .update(payload)
            .eq('id', id);
      } else {
        await Supabase.instance.client.from('products').insert(payload);
      }

      if (mounted) {
        _showSnackBar(widget.isEditing
            ? 'Product updated successfully!'
            : 'Product saved successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('violates foreign key constraint') || msg.contains('order_items_product_id_fkey')) {
        _showSnackBar('Cannot update product while it is referenced by order items. Remove dependent order items first or enable cascading deletes in the database.', isError: true);
      } else {
        _showSnackBar('Error saving product: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _uploadProductImage() async {
    if (_selectedImageBytes == null) return '';

    try {
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'products/$fileName';

      await Supabase.instance.client.storage.from('products').uploadBinary(
            path,
            _selectedImageBytes!,
          );

      return Supabase.instance.client.storage.from('products').getPublicUrl(path);
    } catch (e) {
      _showSnackBar('Error uploading image: $e', isError: true);
      return '';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String? _requiredValidator(String? value) => value?.isEmpty ?? true ? 'This field is required' : null;
  String? _priceValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Price is required';
    try {
      double.parse(value!);
      return null;
    } catch (e) {
      return 'Enter a valid price';
    }
  }

  String? _stockValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Stock is required';
    try {
      int.parse(value!);
      return null;
    } catch (e) {
      return 'Enter a valid number';
    }
  }

  String? _hexValidator(String? value) => (value?.isEmpty ?? true) || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value ?? '') ? 'Enter valid hex (#RRGGBB)' : null;

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPink, width: 2)),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildCategoryField() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _category.isNotEmpty ? _category : null,
      items: _categoryOptions.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
      onChanged: (value) => setState(() => _category = value ?? ''),
      decoration: InputDecoration(
        labelText: 'Category *',
        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      validator: (value) => (value?.isEmpty ?? true) ? 'Category is required' : null,
    );
  }

  Widget _buildAutoDetectedShadeDepthCard() {
    final detectedDepth = _detectShadeDepthFromHex(_hexCodeController.text);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryPink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: primaryPink, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-Powered Shade Detection',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                    children: [
                      const TextSpan(text: 'Detected depth: '),
                      TextSpan(
                        text: detectedDepth,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: primaryPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDetectedColorFamilyCard() {
    final detectedFamily = _detectColorFamilyFromHex(_hexCodeController.text);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryPink.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: primaryPink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI detected color family: $detectedFamily',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDetectedUndertoneCard() {
    final undertones = _detectCompatibleUndertonesFromHex(_hexCodeController.text);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryPink.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: primaryPink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI detected compatible undertone: ${undertones.join(', ')}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewPlaceholder() => GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: primaryPink, width: 2),
          ),
          child: _selectedImageBytes != null
              ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover))
              : Center(
                  child: Icon(Icons.add_photo_alternate_outlined, color: primaryPink, size: 48),
                ),
        ),
      );

  Widget _buildColorPaletteChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _extractedColors
              .map(
                (color) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _setHexColor(color),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hexColor == color ? Colors.black : Colors.black12,
                          width: _hexColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );

  Widget _buildChipSelector(
    String label,
    List<String> options,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onToggle(option),
              selectedColor: primaryPink.withOpacity(0.15),
              checkmarkColor: primaryPink,
              labelStyle: TextStyle(
                color: isSelected ? primaryPink : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? primaryPink : Colors.grey.shade300,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryPink, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _buildSummaryCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryPink.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryPink.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.info_outline, color: primaryPink, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Complete all fields marked with * to save the product.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Determine if coverage level should be shown based on category
    final supportsCoverage = [
      'Foundation',
      'Concealer',
      'Skin Tint',
      'Cushion',
      'Powder',
      'Blush',
      'Lipstick',
      'Lip Tint',
      'Lip Gloss',
    ].contains(_category);

    // Categories that don't have a color/shade (tools, accessories, etc.)
    final categoryLower = _category.toLowerCase();
    final supportsColor = !(categoryLower.contains('tool') ||
        categoryLower.contains('brush') ||
        categoryLower.contains('sponge') ||
        categoryLower.contains('applicator') ||
        categoryLower.contains('accessor') ||
        categoryLower == 'setting spray');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing
              ? (context.isCompact ? 'Edit Product' : 'Edit Product • Fashion 21')
              : (context.isCompact ? 'Add Product' : 'Add Product • Fashion 21'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryPink.withOpacity(0.18)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.storefront_outlined, color: primaryPink),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Client: Fashion 21',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    _buildSectionCard('Basic Information', Icons.assignment_outlined, [
                      _buildTextField('Product Name *', _nameController, validator: _requiredValidator),
                      const SizedBox(height: 16),
                      _buildTextField('Description', _descriptionController, maxLines: 3),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildCategoryField()),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Stock *',
                              _stockController,
                              keyboardType: TextInputType.number,
                              validator: _stockValidator,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                    ]),
                    _buildSectionCard('Images', Icons.image_outlined, [
                      const Text('Main Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _selectedImageBytes == null ? _pickImage : _showColorPaletteDialog,
                            child: _buildImagePreviewPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: primaryPink.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: primaryPink.withOpacity(0.1), style: BorderStyle.solid),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, color: primaryPink, size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedImageName ?? 'Upload Main Image',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_selectedImageBytes != null) ...[
                        const Text(
                          'Tap a color from the image',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        _buildColorPaletteChips(),
                      ],
                      const SizedBox(height: 16),
                      _buildTextField('Image URL (optional)', _imageUrlController),
                    ]),
                    if (supportsColor)
                      _buildSectionCard('Color & Shade', Icons.water_drop_outlined, [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Shade Name *', _shadeNameController, validator: _requiredValidator)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Hex Code *',
                              _hexCodeController,
                              validator: _hexValidator,
                              suffix: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _showColorPaletteDialog,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: _hexColor,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.black12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAutoDetectedShadeDepthCard(),
                      const SizedBox(height: 16),
                      _buildAutoDetectedColorFamilyCard(),
                      const SizedBox(height: 16),
                      _buildAutoDetectedUndertoneCard(),
                      const SizedBox(height: 16),
                      _buildChipSelector(
                        'Skin Type Compatibility',
                        _skinTypeOptions,
                        _selectedSkinTypes,
                        (option) => setState(() {
                          if (_selectedSkinTypes.contains(option)) {
                            _selectedSkinTypes.remove(option);
                          } else {
                            _selectedSkinTypes.add(option);
                          }
                        }),
                      ),
                      const SizedBox(height: 16),
                      _buildChipSelector(
                        'Finish Type',
                        _finishTypeOptions,
                        _selectedFinishTypes,
                        (option) => setState(() {
                          if (_selectedFinishTypes.contains(option)) {
                            _selectedFinishTypes.remove(option);
                          } else {
                            _selectedFinishTypes.add(option);
                          }
                        }),
                      ),
                      if (supportsCoverage) ...[
                        const SizedBox(height: 16),
                        _buildChipSelector(
                          'Coverage Level',
                          _coverageLevelOptions,
                          _selectedCoverageLevels,
                          (option) => setState(() {
                            if (_selectedCoverageLevels.contains(option)) {
                              _selectedCoverageLevels.remove(option);
                            } else {
                              _selectedCoverageLevels.add(option);
                            }
                          }),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryPink.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          '✨ AI automatically detects shade depth, color family, and compatible undertone from hex code. No manual selection needed.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ]),
                    _buildSectionCard('Pricing', Icons.shopping_bag_outlined, [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Price *',
                              _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: _priceValidator,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Currency *',
                              value: _currencyController.text,
                              items: const ['PHP'],
                              onChanged: (value) => setState(() => _currencyController.text = value!),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProduct,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : (widget.isEditing ? 'Update Product' : 'Save Product'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isNotEmpty ? value : null,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}
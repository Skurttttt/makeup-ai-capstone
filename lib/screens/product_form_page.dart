import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive.dart';

class ProductFormPage extends StatefulWidget {
  final String businessId;

  const ProductFormPage({super.key, required this.businessId});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const Color primaryPink = Color(0xFFFF4D97);
  static const Color bgColor = Color(0xFFFFF9FB);

  static const List<String> _skinTypeOptions = ['Dry', 'Oily', 'Combination', 'Sensitive', 'Normal'];
  static const List<String> _finishTypeOptions = ['Matte', 'Dewy', 'Natural', 'Glossy', 'Velvet', 'Soft Matte'];
  static const List<String> _coverageLevelOptions = ['Light', 'Medium', 'Full', 'Buildable'];
  static const List<String> _lookTagOptions = ['Soft Glam', 'Clean Girl', 'Douyin', 'Latte Makeup', 'Emo', 'Natural', 'Korean', 'Party Glam'];

  static const List<String> _fallbackCategories = [
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
  final Set<String> _selectedLookTags = {};

  final _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final List<Color> _extractedColors = [];
  bool _extractingColors = false;

  String _category = '';
  List<String> _categoryOptions = [];
  bool _loadingCategories = true;
  String _undertone = 'Cool';
  String _colorFamily = 'Rosy Pink';
  bool _morenaFriendly = true;
  bool _beginnerFriendly = true;
  bool _budgetFriendly = false;
  bool _studentFriendly = true;
  bool _saving = false;

  int _channelTo255(num channel) {
    if (channel <= 1) {
      return (channel * 255).round().clamp(0, 255);
    }
    return channel.round().clamp(0, 255);
  }

  @override
  void initState() {
    super.initState();
    _loadCategoryOptions();
  }

  @override
  void dispose() {
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
      final categories = merged.toList();
      categories.sort();

      if (mounted) {
        setState(() {
          _categoryOptions = categories;
          _category = _categoryOptions.isNotEmpty ? _categoryOptions.first : '';
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
    final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    setState(() => _hexCodeController.text = hex);
  }

  Color get _hexColor {
    try {
      return Color(int.parse(_hexCodeController.text.replaceFirst('#', '0x')));
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

  void _copyHexToClipboard() {
    Clipboard.setData(ClipboardData(text: _hexCodeController.text));
    _showSnackBar('Hex copied to clipboard!');
  }

  Future<void> _pasteHexFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      if (data.text!.startsWith('#') && data.text!.length == 7) {
        setState(() => _hexCodeController.text = data.text!);
        _showSnackBar('Hex pasted!');
      } else {
        _showSnackBar('Invalid hex format', isError: true);
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final imageUrl = _selectedImageBytes != null ? await _uploadProductImage() : _imageUrlController.text;

      await Supabase.instance.client.from('products').insert({
        'business_id': widget.businessId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'category': _category,
        'price': double.parse(_priceController.text),
        'currency': _currencyController.text,
        'stock': int.parse(_stockController.text),
        'image_url': imageUrl,
        'shade_name': _shadeNameController.text,
        'hex_code': _hexCodeController.text,
        'undertone': _undertone,
        'color_family': _colorFamily,
        'compatible_looks': _selectedLookTags.join(', '),
        'compatible_skin_tone': _selectedSkinTypes.join(', '),
        'finish_type': _selectedFinishTypes.join(', '),
        'coverage_level': _selectedCoverageLevels.join(', '),
        'morena_friendly': _morenaFriendly,
        'beginner_friendly': _beginnerFriendly,
        'budget_friendly': _budgetFriendly,
        'student_friendly': _studentFriendly,
      });

      if (mounted) {
        _showSnackBar('Product saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error saving product: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _uploadProductImage() async {
    if (_selectedImageBytes == null) return '';

    try {
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'products/$fileName';

      await Supabase.instance.client.storage.from('product-images').uploadBinary(
            path,
            _selectedImageBytes!,
          );

      return Supabase.instance.client.storage.from('product-images').getPublicUrl(path);
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
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines ?? 1,
      readOnly: readOnly,
      onTap: onTap,
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

  Widget _buildColorSquare(Color color) => Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black12)),
        ),
      );

  Widget _buildCategoryField() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      value: _category.isNotEmpty ? _category : null,
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

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
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

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: primaryPink,
            ),
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
          context.isCompact ? 'Add Product' : 'Add Product • Fashion 21',
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
                        Row(
                          children: [
                            const Text(
                              'Tap a color from the image',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _extractingColors
                                  ? null
                                  : _showColorPaletteDialog,
                              child: Text(
                                _extractingColors
                                    ? 'Extracting...'
                                    : 'Open picker',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildColorPaletteChips(),
                      ],
                      const SizedBox(height: 16),
                      _buildTextField('Image URL (optional)', _imageUrlController),
                    ]),
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
                              readOnly: true,
                              onTap: _showColorPaletteDialog,
                              suffix: _buildColorSquare(_hexColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyHexToClipboard,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Hex'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryPink,
                                side: BorderSide(color: primaryPink.withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pasteHexFromClipboard,
                              icon: const Icon(Icons.content_paste, size: 16),
                              label: const Text('Paste Hex'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryPink,
                                side: BorderSide(color: primaryPink.withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Undertone', _undertone, const ['Cool', 'Warm', 'Neutral'], (value) => setState(() => _undertone = value!))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              'Color Family',
                              _colorFamily,
                              const [
                                'Rosy Pink',
                                'Nude',
                                'Beige',
                                'Peach',
                                'Coral',
                                'Pink',
                                'Rose',
                                'Mauve',
                                'Berry',
                                'Red',
                                'Plum',
                                'Brown',
                                'Terracotta',
                                'Orange',
                              ],
                              (value) => setState(() => _colorFamily = value!),
                            ),
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 16),
                      _buildChipSelector(
                        'Recommended Look Tags',
                        _lookTagOptions,
                        _selectedLookTags,
                        (option) => setState(() {
                          if (_selectedLookTags.contains(option)) {
                            _selectedLookTags.remove(option);
                          } else {
                            _selectedLookTags.add(option);
                          }
                        }),
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
                            child: _buildDropdown(
                              'Currency *',
                              _currencyController.text,
                              const ['PHP'],
                              (value) => setState(() => _currencyController.text = value!),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    _buildSectionCard('Filipino Market Tags', Icons.local_offer_outlined, [
                      _buildSwitchRow('Morena Friendly', _morenaFriendly, (value) => setState(() => _morenaFriendly = value)),
                      _buildSwitchRow('Beginner Friendly', _beginnerFriendly, (value) => setState(() => _beginnerFriendly = value)),
                      _buildSwitchRow('Budget Friendly', _budgetFriendly, (value) => setState(() => _budgetFriendly = value)),
                      _buildSwitchRow('Student Friendly', _studentFriendly, (value) => setState(() => _studentFriendly = value)),
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
                    _saving ? 'Saving...' : 'Save Product',
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
}

// lib/auth/register_supabase_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/verification_service.dart';
import '../services/supabase_service.dart';
import 'email_verification_page.dart';
import 'login_supabase_page.dart';

class RegisterSupabasePage extends StatefulWidget {
  const RegisterSupabasePage({super.key});

  @override
  State<RegisterSupabasePage> createState() => _RegisterSupabasePageState();
}

class _RegisterSupabasePageState extends State<RegisterSupabasePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _businessRegNumberController = TextEditingController();
  final _productLineController = TextEditingController();
  final _supabaseService = SupabaseService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;
  String _accountType = 'individual'; // 'individual' or 'business'
  String _businessType = 'makeup_brand'; // makeup_brand, salon, artist, distributor, other

  // Makeup product categories (business only)
  final Set<String> _selectedProductCategories = {};
  static const _productCategories = [
    ('foundation', Icons.circle, 'Foundation & Concealer'),
    ('lips', Icons.favorite, 'Lipstick & Lip Products'),
    ('eyes', Icons.remove_red_eye, 'Eyeshadow & Eye Products'),
    ('mascara', Icons.auto_fix_high, 'Mascara & Lashes'),
    ('blush', Icons.blur_circular, 'Blush, Bronzer & Highlighter'),
    ('primer', Icons.layers, 'Primer & Setting Spray'),
    ('skincare', Icons.face, 'Skincare with Makeup'),
    ('tools', Icons.brush, 'Brushes & Tools'),
    ('nails', Icons.colorize, 'Nail Products'),
    ('fragrance', Icons.local_florist, 'Fragrance'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessAddressController.dispose();
    _businessDescriptionController.dispose();
    _businessRegNumberController.dispose();
    _productLineController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms and conditions')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Validate business fields if business account
    if (_accountType == 'business') {
      if (_businessNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter business name')),
        );
        return;
      }
      if (_businessPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter business phone')),
        );
        return;
      }
      if (_businessAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter business address')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final fullName = _nameController.text.trim();
      final password = _passwordController.text;

      // Check if email already exists
      try {
        final exists = await _supabaseService.emailExists(email);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email already exists. Please use another email or delete the old account.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (_) {
        // Continue with signup even if check fails
      }

      // Signup with trigger creating account automatically
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'account_type': _accountType,
          'client_type': _accountType,
          if (_accountType == 'business') ...{
            'business_name': _businessNameController.text.trim(),
            'business_type': _businessType,
            'business_phone': _businessPhoneController.text.trim(),
            'business_address': _businessAddressController.text.trim(),
            'business_description': _businessDescriptionController.text.trim(),
            'business_reg_number': _businessRegNumberController.text.trim(),
            'product_line': _productLineController.text.trim(),
            'product_categories': _selectedProductCategories.toList().join(','),
          }
        },
      );

      if (!mounted) return;

      // Sign out so user must confirm email
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      // Send confirmation email (no 4-digit code)
      try {
        await VerificationService().sendConfirmationEmail(email);
      } catch (_) {}

      // Navigate to verification page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(email: email),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final horizontalPadding = isLargeScreen ? 32.0 : 20.0;
    final maxWidth = isLargeScreen ? 500.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
            );
          },
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Join FaceTune Beauty',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to start scanning and discovering makeup looks',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Account Type Selection
                    const Text(
                      'Account Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    setState(() => _accountType = 'individual');
                                  },
                            child: MouseRegion(
                              cursor: _isLoading
                                  ? SystemMouseCursors.forbidden
                                  : SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _accountType == 'individual'
                                        ? const Color(0xFFFF4D97)
                                        : Colors.grey[300]!,
                                    width: _accountType == 'individual' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: _accountType == 'individual'
                                      ? const Color(0xFFFF4D97).withOpacity(0.1)
                                      : Colors.grey[50],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _accountType == 'individual'
                                            ? const Color(0xFFFF4D97).withOpacity(0.2)
                                            : Colors.grey[200],
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: _accountType == 'individual'
                                            ? const Color(0xFFFF4D97)
                                            : Colors.grey[600],
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Individual',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: _accountType == 'individual'
                                            ? Colors.black87
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    setState(() => _accountType = 'business');
                                  },
                            child: MouseRegion(
                              cursor: _isLoading
                                  ? SystemMouseCursors.forbidden
                                  : SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _accountType == 'business'
                                        ? const Color(0xFFFF4D97)
                                        : Colors.grey[300]!,
                                    width: _accountType == 'business' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: _accountType == 'business'
                                      ? const Color(0xFFFF4D97).withOpacity(0.1)
                                      : Colors.grey[50],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _accountType == 'business'
                                            ? const Color(0xFFFF4D97).withOpacity(0.2)
                                            : Colors.grey[200],
                                      ),
                                      child: Icon(
                                        Icons.business,
                                        color: _accountType == 'business'
                                            ? const Color(0xFFFF4D97)
                                            : Colors.grey[600],
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Business',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: _accountType == 'business'
                                            ? Colors.black87
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Full Name Field
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'John Doe',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF4D97)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        labelStyle: const TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF4D97)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        labelStyle: const TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFFFF4D97)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        suffixIcon: Container(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        labelStyle: const TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFFFF4D97)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        suffixIcon: Container(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        labelStyle: const TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Business Fields (shown only if business account)
                    if (_accountType == 'business') ...[
                      const SizedBox(height: 8),
                      Divider(color: Colors.grey[300], thickness: 1, height: 32),
                      const Text(
                        'Business Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Business Name
                      TextFormField(
                        controller: _businessNameController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Business Name *',
                          hintText: 'e.g., Glamour Cosmetics',
                          prefixIcon: const Icon(Icons.store, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (_accountType == 'business' && (value == null || value.isEmpty)) {
                            return 'Please enter business name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Business Type Dropdown
                      const Text(
                        'Business Type *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _businessType,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            dropdownColor: Colors.white,
                            items: [
                              DropdownMenuItem(
                                value: 'makeup_brand',
                                child: Row(
                                  children: [
                                    const Icon(Icons.palette, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Makeup Brand', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'salon',
                                child: Row(
                                  children: [
                                    const Icon(Icons.spa, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Salon/Makeup Studio', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'artist',
                                child: Row(
                                  children: [
                                    const Icon(Icons.brush, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Makeup Artist', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'distributor',
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Distributor', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'retailer',
                                child: Row(
                                  children: [
                                    const Icon(Icons.shopping_bag, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Retailer', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Row(
                                  children: [
                                    const Icon(Icons.category, color: Color(0xFFFF4D97), size: 20),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                      child: Text('Other', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _businessType = value ?? 'makeup_brand';
                                    });
                                  },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Business Phone
                      TextFormField(
                        controller: _businessPhoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Business Phone *',
                          hintText: '+1 (555) 123-4567',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (_accountType == 'business' && (value == null || value.isEmpty)) {
                            return 'Please enter business phone';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Business Address
                      TextFormField(
                        controller: _businessAddressController,
                        enabled: !_isLoading,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Business Address *',
                          hintText: '123 Main Street, City, State 12345',
                          prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (_accountType == 'business' && (value == null || value.isEmpty)) {
                            return 'Please enter business address';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Business Description
                      TextFormField(
                        controller: _businessDescriptionController,
                        enabled: !_isLoading,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Business Description',
                          hintText: 'Tell us about your makeup business...',
                          prefixIcon: const Icon(Icons.description, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 16),

                      // Business Registration Number (Optional)
                      TextFormField(
                        controller: _businessRegNumberController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Business Registration Number',
                          hintText: 'e.g., REG-123456 (optional)',
                          prefixIcon: const Icon(Icons.assignment, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),

                      // ── Makeup Products Section ──────────────────────────────────
                      const SizedBox(height: 8),
                      Divider(color: Colors.grey[300], thickness: 1, height: 32),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D97).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.palette, color: Color(0xFFFF4D97), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Makeup Products',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D97),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Business Only',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select the makeup product categories your business offers.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 14),

                      // Product Line / Brand Name
                      TextFormField(
                        controller: _productLineController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Product Line / Brand Name',
                          hintText: 'e.g., LuxeGlow Collection',
                          prefixIcon: const Icon(Icons.inventory_2, color: Color(0xFFFF4D97)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 14),

                      // Product Category Chips Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _productCategories.map((cat) {
                          final (key, icon, label) = cat;
                          final selected = _selectedProductCategories.contains(key);
                          return GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selectedProductCategories.remove(key);
                                      } else {
                                        _selectedProductCategories.add(key);
                                      }
                                    });
                                  },
                            child: MouseRegion(
                              cursor: _isLoading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFFF4D97)
                                      : Colors.grey[100],
                                  border: Border.all(
                                    color: selected ? const Color(0xFFFF4D97) : Colors.grey[300]!,
                                    width: selected ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 14,
                                      color: selected ? Colors.white : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: selected ? Colors.white : Colors.grey[700],
                                      ),
                                    ),
                                    if (selected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check, size: 13, color: Colors.white),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 16),

                    // Terms Checkbox
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() => _acceptTerms = !_acceptTerms);
                            },
                      child: MouseRegion(
                        cursor: _isLoading
                            ? SystemMouseCursors.forbidden
                            : SystemMouseCursors.click,
                        child: Row(
                          children: [
                            Checkbox(
                              value: _acceptTerms,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() => _acceptTerms = value ?? false);
                                    },
                              activeColor: const Color(0xFFFF4D97),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Flexible(
                              child: Text(
                                'I agree to Terms & Conditions',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Up Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D97),
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 2,
                          shadowColor: const Color(0xFFFF4D97).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginSupabasePage(),
                                    ),
                                  );
                                },
                          child: MouseRegion(
                            cursor: _isLoading
                                ? SystemMouseCursors.forbidden
                                : SystemMouseCursors.click,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: _isLoading
                                    ? Colors.grey
                                    : const Color(0xFFFF4D97),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

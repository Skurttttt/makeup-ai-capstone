// lib/auth/register_supabase_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabaseService = SupabaseService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;
  double _passwordStrength = 0;

  void _onPasswordChanged(String v) {
    double s = 0;
    if (v.length >= 8) s += 0.25;
    if (v.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (v.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;
    setState(() => _passwordStrength = s);
  }

  Color get _strengthColor {
    if (_passwordStrength <= 0.25) return Colors.red;
    if (_passwordStrength <= 0.5) return Colors.orange;
    if (_passwordStrength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String get _strengthLabel {
    if (_passwordStrength <= 0.25) return 'Weak';
    if (_passwordStrength <= 0.5) return 'Fair';
    if (_passwordStrength <= 0.75) return 'Good';
    return 'Strong';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = '$firstName $lastName'.trim();
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final postal = _postalController.text.trim();
      final password = _passwordController.text;

      // Check if email already exists
      try {
        final exists = await _supabaseService.emailExists(email);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Email already exists. Please use another email or delete the old account.',
                ),
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
      final authRes = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'phone_number': phone,
          'address': address,
          'city': city,
          'postal_code': postal,
          'account_type': 'individual',
          'client_type': 'individual',
        },
      );

      // Write all profile fields into accounts row directly (in case the
      // trigger didn't pick them up from metadata).
      try {
        final newUser = authRes.user;
        if (newUser != null) {
          await Supabase.instance.client.from('accounts').upsert({
            'id': newUser.id,
            'email': email,
            'full_name': fullName,
            'phone': phone,
          }, onConflict: 'id');
        }
      } catch (_) {
        // Trigger may already have inserted the row — ignore.
      }

      if (!mounted) return;

      // Sign out so user must confirm email
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      // Navigate to verification page
      // Note: Supabase already sent the confirmation email during signUp() above.
      // Calling resend() here is redundant and can hit the free-tier rate limit (2/hr).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EmailVerificationPage(email: email)),
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

  InputDecoration _inputDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFFFF4D97)),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 48, minHeight: 48),
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(fontSize: 14),
    );
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
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D97).withOpacity(0.30),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/brand_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 24),

                    // Personal info section header
                    Row(
                      children: [
                        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF4D97), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Personal Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // First Name + Last Name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration('First Name', Icons.person_outline, hint: 'Juan'),
                            style: const TextStyle(fontSize: 16),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (v.trim().length < 2) return 'Too short';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration('Last Name', Icons.person_outline, hint: 'Dela Cruz'),
                            style: const TextStyle(fontSize: 16),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (v.trim().length < 2) return 'Too short';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration('Email Address', Icons.email_outlined, hint: 'example@email.com'),
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

                    const SizedBox(height: 12),

                    // Phone Number Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\- ]')),
                      ],
                      decoration: _inputDecoration('Phone Number', Icons.phone_outlined, hint: '+63 912 345 6789'),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null; // optional
                        }
                        final digits = value.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7) {
                          return 'Phone number is too short';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Address section header
                    Row(
                      children: [
                        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF4D97), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Address (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Address Field
                    TextFormField(
                      controller: _addressController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                      decoration: _inputDecoration('Street Address', Icons.location_on_outlined),
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 12),

                    // City + Postal row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration('City', Icons.location_city_outlined),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _postalController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration('Postal', Icons.markunread_mailbox_outlined),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Password section header
                    Row(
                      children: [
                        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFF4D97), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Security', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      onChanged: _onPasswordChanged,
                      decoration: _inputDecoration(
                        'Password', Icons.lock_outlined,
                        hint: 'Min. 8 chars with uppercase, number & symbol',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[600],
                            size: 22,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!value.contains(RegExp(r'[A-Z]'))) {
                          return 'Add at least one uppercase letter';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'Add at least one number';
                        }
                        if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                          return 'Add at least one symbol (e.g. !@#\$)';
                        }
                        return null;
                      },
                    ),

                    // Password strength bar
                    if (_passwordController.text.isNotEmpty) ...[  
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _passwordStrength,
                                minHeight: 6,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _strengthLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _strengthColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Min. 8 characters with uppercase, lowercase, number & symbol for a strong password.',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      decoration: _inputDecoration(
                        'Confirm Password', Icons.lock_outlined,
                        hint: 'Re-enter your password',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[600],
                            size: 22,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
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
                                      setState(
                                        () => _acceptTerms = value ?? false,
                                      );
                                    },
                              activeColor: const Color(0xFFFF4D97),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Flexible(
                              child: Text(
                                'I agree to Terms & Conditions',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
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
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
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

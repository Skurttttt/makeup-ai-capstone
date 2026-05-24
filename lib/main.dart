import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_supabase_page.dart';
import 'auth/change_password_page.dart';
import 'home_screen.dart';
import 'screens/admin_screen_new.dart';
import 'screens/client_screen.dart';

/// Global navigator key used to push routes even when the originating
/// widget (AuthGate) is no longer mounted (e.g. deep-link race condition).
final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress the spurious "Attempted to send a key down event when no keys
  // are in keysPressed" assertion that fires on Windows when Alt/Shift is
  // held while the window receives focus.
  RawKeyboard.instance.addListener((_) {});
  await dotenv.load(fileName: 'assets/.env');

  try {
    final envUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    final envAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

    const fallbackUrl = 'https://iqaiebnoodjnoyaiyoez.supabase.co';

    const fallbackAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYWllYm5vb2Rqbm95YWl5b2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwMzAzNDEsImV4cCI6MjA4NTYwNjM0MX0.'
        '2Jvt3WMFpaTYIAE_wff-wlmZfrJNJdXku76cF1x4MFY';

    await Supabase.initialize(
      url: envUrl.isNotEmpty ? envUrl : fallbackUrl,
      anonKey: envAnonKey.isNotEmpty ? envAnonKey : fallbackAnonKey,
    );
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceTune - Beauty & Style',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFFF4D97),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D97),
          primary: const Color(0xFFFF4D97),
        ),
      ),
      navigatorKey: _navigatorKey,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _redirect();
    // Listen for password recovery deep link (mobile & web).
    // Use the global navigator key so this works even if AuthGate has
    // already been replaced by the login page (deep-link timing race).
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ChangePasswordPage(),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    // Require login on web, but force admin UI as the destination.
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (kIsWeb) {
      // If the user didn't choose 'remember me', force login page.
      if (!rememberMe) {
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
        );
        return;
      }

      // If there is a saved session, go to admin regardless of stored role.
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
        );
        return;
      }

      // Verify the user's role — only allow admins on web.
      try {
        final profile = await Supabase.instance.client
            .from('accounts')
            .select('role')
            .eq('id', session.user.id)
            .maybeSingle();
        final role = profile != null && profile['role'] != null
            ? (profile['role'] as String).toLowerCase()
            : null;

        if (role == 'admin' || role == 'super_admin') {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminScreenNew()),
          );
          return;
        }
      } catch (e) {
        // If fetching role fails, fall through to sign-out path below.
      }

      // Not an admin: sign out and return to login with a message.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only admin accounts may sign in to the web app.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
      );
      return;
    }

    if (!mounted) return;

    if (!rememberMe) {
      // Remember Me was not checked — sign out any saved session
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
      );
      return;
    }

    // Remember Me was checked — skip login if there is a valid session
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
      );
      return;
    }

    String? role;
    String? accountType;
    try {
      final profile = await Supabase.instance.client
          .from('accounts')
          .select('role, account_type')
          .eq('id', session.user.id)
          .single();
      role = profile['role'] as String?;
      accountType = profile['account_type'] as String?;
    } catch (_) {
      role = 'user';
    }

    if (!mounted) return;

    if (role?.toLowerCase() == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminScreenNew()),
      );
    } else if (accountType == 'business' || role?.toLowerCase() == 'client') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientScreen()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF7FA),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class NoCameraScreen extends StatelessWidget {
  const NoCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No camera available on this device.\n'
            'Please run the app on a physical device with a front camera.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_supabase_page.dart';
import 'auth/change_password_page.dart';
import 'home_screen.dart';
import 'screens/admin_screen_new.dart';
import 'screens/client_screen.dart';

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
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        // Handle deep link for password reset
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.path == '/reset-password') {
          final accessToken = uri.queryParameters['access_token'];
          if (accessToken != null && accessToken.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ChangePasswordPage(accessToken: accessToken),
            );
          }
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

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

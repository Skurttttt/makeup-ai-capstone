import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint("DOTENV LOAD ERROR: $e");
  }

  try {
    final envUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    final envAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

    const fallbackUrl = 'https://iqaiebnoodjnoyaiyoez.supabase.co';
    const fallbackAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYWllYm5vb2Rqbm95YWl5b2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwMzAzNDEsImV4cCI6MjA4NTYwNjM0MX0.2Jvt3WMFpaTYIAE_wff-wlmZfrJNJdXku76cF1x4MFY';

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
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFFF4D97),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D97),
          primary: const Color(0xFFFF4D97),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
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
            'No camera available on this device.\nPlease run the app on a physical device with a front camera.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
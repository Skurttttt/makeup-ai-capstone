import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/supabase_service.dart';

void main() async {
  final supabaseUrl = 'https://iqaiebnoodjnoyaiyoez.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYWllYm5vb2Rqbm95YWl5b2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwMzAzNDEsImV4cCI6MjA4NTYwNjM0MX0.2Jvt3WMFpaTYIAE_wff-wlmZfrJNJdXku76cF1x4MFY';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabaseService = SupabaseService();

  print('Creating Regular plan...');
  try {
    final regularResult = await supabaseService.createPlan(
      name: 'regular',
      displayName: 'Regular',
      price: 199.0,
      description: 'Standard access with moderate limits.',
      dailyScanLimit: 10,
      removeWatermark: false,
    );
    print('Regular plan result: $regularResult');
  } catch (e) {
    print('Error creating Regular plan: $e');
  }

  print('Creating Premium plan...');
  try {
    final premiumResult = await supabaseService.createPlan(
      name: 'premium',
      displayName: 'Premium',
      price: 499.0,
      description: 'Unlimited access with all features.',
      dailyScanLimit: -1,
      removeWatermark: true,
      canSaveResults: true,
      canExportHd: true,
    );
    print('Premium plan result: $premiumResult');
  } catch (e) {
    print('Error creating Premium plan: $e');
  }
}

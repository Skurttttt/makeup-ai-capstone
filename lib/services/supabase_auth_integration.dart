// lib/services/supabase_auth_integration.dart
import 'supabase_service.dart';
import 'auth_service.dart';

class SupabaseAuthIntegration {
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService;

  SupabaseAuthIntegration(this._authService);

  /// Integrate Supabase with existing AuthService
  Future<void> initialize() async {
    try {
      // SupabaseService is already initialized via Supabase.initialize() in main
      await Future.value();
    } catch (e) {
      throw 'Failed to initialize Supabase: $e';
    }
  }

  /// Sign up with Supabase
  Future<void> signUpWithSupabase({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create Supabase user
      final authResponse = await _supabaseService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (authResponse.user != null) {
        // Create profile in Supabase
        await _supabaseService.createUserProfile(
          userId: authResponse.user!.id,
          email: email,
          fullName: fullName,
        );

        // Update local auth service
        await _authService.login(
          email: email,
          password: password,
          role: UserRole.user,
        );
      }
    } catch (e) {
      throw 'Signup failed: $e';
    }
  }

  /// Sign in with Supabase
  Future<void> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Supabase
      final authResponse = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Get user profile
        final profile = await _supabaseService.getUserProfile(
          authResponse.user!.id,
        );

        // Update local auth service with role
        UserRole role;
        switch (profile['role']) {
          case 'admin':
            role = UserRole.admin;
            break;
          case 'client':
            role = UserRole.client;
            break;
          default:
            role = UserRole.user;
        }

        await _authService.login(
          email: email,
          password: password,
          role: role,
        );
      }
    } catch (e) {
      throw 'Login failed: $e';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
      await _authService.logout();
    } catch (e) {
      throw 'Logout failed: $e';
    }
  }

  /// Save scan to Supabase
  Future<String?> saveScanToSupabase({
    required String lookName,
    required String imagePath,
    required Map<String, dynamic> faceData,
  }) async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) throw 'User not authenticated';

      // TODO: Upload image to storage when Supabase is ready
      // const imageUrl = null;

      // Save scan record
      final scan = await _supabaseService.saveScan(
        userId: user.id,
        lookName: lookName,
        imagePath: imagePath,
        faceData: faceData,
      );

      return scan['id'];
    } catch (e) {
      throw 'Failed to save scan: $e';
    }
  }

  /// Get user's scan history
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) throw 'User not authenticated';

      return await _supabaseService.getScanHistory(user.id);
    } catch (e) {
      throw 'Failed to fetch scan history: $e';
    }
  }

  /// Add scan to favorites
  Future<void> addFavorite(String lookName) async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) throw 'User not authenticated';

      await _supabaseService.addFavoriteLook(
        userId: user.id,
        lookName: lookName,
      );
    } catch (e) {
      throw 'Failed to add favorite: $e';
    }
  }

  /// Get user's favorite looks
  Future<List<Map<String, dynamic>>> getFavoriteLooks() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) throw 'User not authenticated';

      return await _supabaseService.getFavoriteLooks(user.id);
    } catch (e) {
      throw 'Failed to fetch favorites: $e';
    }
  }

  /// Get admin analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      if (!_authService.isAdmin) {
        throw 'Only admins can access analytics';
      }

      return await _supabaseService.getAnalyticsData();
    } catch (e) {
      throw 'Failed to fetch analytics: $e';
    }
  }

  /// Get all users (admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      if (!_authService.isAdmin) {
        throw 'Only admins can access users list';
      }

      return await _supabaseService.getAllUsers();
    } catch (e) {
      throw 'Failed to fetch users: $e';
    }
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _supabaseService.isAuthenticated();
  }

  /// Get current user
  String? getCurrentUserId() {
    return _supabaseService.getCurrentUser()?.id;
  }
}

// lib/router/app_router.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../auth/login_page.dart';
import '../screens/admin_screen_new.dart';
import '../home_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings, AuthService authService) {
    switch (settings.name) {
      case '/':
        // Route to appropriate screen based on authentication and role
        if (!authService.isAuthenticated) {
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }
        if (authService.isAdmin) {
          return MaterialPageRoute(builder: (_) => const AdminScreenNew());
        }
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case '/home':
        if (!authService.isAuthenticated) {
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case '/admin':
        if (!authService.isAdmin) {
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }
        return MaterialPageRoute(builder: (_) => const AdminScreenNew());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

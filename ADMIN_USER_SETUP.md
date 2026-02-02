// ADMIN & USER ROLE-BASED SYSTEM - HOW IT WORKS

## File Structure & Connections

```
lib/
├── services/
│   └── auth_service.dart          ← Central authentication service (tracks user role)
├── router/
│   └── app_router.dart            ← Routes users/admins to correct screens
├── auth/
│   └── role_login_page.dart       ← Login page with role selection (User/Admin)
├── screens/
│   ├── admin_screen.dart          ← Admin dashboard (only for admins)
│   └── home_screen.dart           ← User home (only for users)
└── main.dart                      ← App entry point
```

## How It Works - Step by Step

### 1. LOGIN FLOW
- User opens app → `RoleLoginPage` is displayed
- User selects role (User or Admin)
- Enters email & password
- Auth service validates and stores role in `AuthService`

### 2. ROLE-BASED ROUTING
- After login, `AppRouter` checks user role
- Admin → routes to `AdminScreen` 
- User → routes to `HomeScreen`
- Guest → routes back to `RoleLoginPage`

### 3. PERSISTENT STATE
- `AuthService` (using Provider) maintains user state globally
- All pages can access current user role via:
  ```dart
  context.read<AuthService>().userRole
  context.read<AuthService>().isAdmin
  ```

### 4. LOGOUT
- Each screen has logout button
- Clears auth state in `AuthService`
- Routes back to login page

## Key Features

✅ **Separate Admin & User Dashboards**
  - Admin: Users management, analytics, settings
  - User: Face scanning, tutorials, marketplace

✅ **Role-Based Access Control**
  - Admins can't access user features
  - Users can't access admin features
  - Protected routes check role before allowing access

✅ **Single Source of Truth**
  - `AuthService` is the only place storing user state
  - All pages listen to changes via Provider

✅ **Demo Credentials**
  - User: user@example.com / password123
  - Admin: admin@example.com / password123

## Usage Examples

### Check if user is admin
```dart
if (context.read<AuthService>().isAdmin) {
  // Show admin-only features
}
```

### Navigate to correct screen after login
```dart
await authService.login(email, password, role);
if (authService.isAdmin) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen()));
} else {
  Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
}
```

### Logout
```dart
await context.read<AuthService>().logout();
Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
```

## To Update Main.dart (Use Provider)

Add to pubspec.yaml:
```yaml
dependencies:
  provider: ^6.0.0
```

Then wrap app with:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
  ],
  child: MaterialApp(
    home: Consumer<AuthService>(
      builder: (_, auth, __) {
        if (!auth.isAuthenticated) {
          return const RoleLoginPage();
        }
        return auth.isAdmin ? const AdminScreen() : const HomeScreen();
      },
    ),
    onGenerateRoute: (settings) => AppRouter.generateRoute(settings, auth),
  ),
)
```

## Files Connected:
1. `auth_service.dart` ← manages authentication state
2. `role_login_page.dart` ← login with role selection
3. `app_router.dart` ← routes based on role
4. `admin_screen.dart` ← admin dashboard (12 pages of admin features)
5. `home_screen.dart` ← user dashboard (already exists)

Now Admin & User flows are completely connected! 🎉

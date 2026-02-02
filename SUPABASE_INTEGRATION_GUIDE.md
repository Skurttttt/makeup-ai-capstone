// COMPLETE SUPABASE INTEGRATION GUIDE

## Quick Start (5 Steps)

### Step 1: Install Dependencies
In your pubspec.yaml:
```yaml
dependencies:
  supabase_flutter: ^1.10.0
  supabase: ^1.10.0
  http: ^1.1.0
```

Run: `flutter pub get`

### Step 2: Get Supabase Credentials
1. Go to https://supabase.com → Create account
2. Create project (wait ~2 min)
3. Go to Settings → API
4. Copy: Supabase URL and Anon Key

### Step 3: Add to .env file
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

### Step 4: Create Database Tables
In Supabase dashboard:
1. Go to SQL Editor
2. Copy-paste all SQL from: database/schema.sql
3. Click "Run"

### Step 5: Update main.dart
```dart
import 'services/supabase_auth_integration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  
  // Initialize Supabase
  final supabaseIntegration = SupabaseAuthIntegration(AuthService());
  await supabaseIntegration.initialize();
  
  final cameras = await availableCameras();
  final front = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  runApp(App(frontCamera: front));
}
```

---

## Usage Examples

### Authentication

```dart
// Sign up
await supabaseIntegration.signUpWithSupabase(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
);

// Sign in
await supabaseIntegration.signInWithSupabase(
  email: 'user@example.com',
  password: 'password123',
);

// Sign out
await supabaseIntegration.signOut();

// Check if authenticated
bool isAuth = supabaseIntegration.isAuthenticated();
```

### Save Scan
```dart
// After taking photo and detecting face
final scanId = await supabaseIntegration.saveScanToSupabase(
  lookName: 'Soft Glam',
  imagePath: '/path/to/image.jpg',
  faceData: {
    'skin_tone': 'warm',
    'face_shape': 'oval',
    'landmarks': [...],
  },
);
```

### Get Scan History
```dart
final scans = await supabaseIntegration.getScanHistory();
scans.forEach((scan) {
  print('${scan['look_name']} - ${scan['created_at']}');
});
```

### Favorites
```dart
// Add to favorites
await supabaseIntegration.addFavorite('Soft Glam');

// Get favorites
final favorites = await supabaseIntegration.getFavoriteLooks();
```

### Admin Features
```dart
// Get analytics
if (authService.isAdmin) {
  final analytics = await supabaseIntegration.getAnalytics();
  print('Total users: ${analytics['total_users']}');
  print('Total scans: ${analytics['total_scans']}');
}

// Get all users
if (authService.isAdmin) {
  final users = await supabaseIntegration.getAllUsers();
  users.forEach((user) {
    print('${user['full_name']} (${user['email']})');
  });
}
```

---

## File Structure

```
lib/
├── services/
│   ├── supabase_service.dart              ← Low-level Supabase API
│   ├── supabase_auth_integration.dart     ← Integration with AuthService
│   └── auth_service.dart                  ← Your existing auth service
└── main.dart                              ← Initialize Supabase

database/
└── schema.sql                             ← Database schema
```

---

## Database Schema

### profiles table
- id (UUID) - references auth.users
- email - unique
- full_name
- role - 'admin' or 'user'
- avatar_url
- bio
- created_at, updated_at

### scans table
- id (UUID)
- user_id (UUID) - references profiles
- look_name
- image_path
- image_url
- face_data (JSON)
- skin_tone
- face_shape
- created_at, updated_at

### favorites table
- id (UUID)
- user_id (UUID) - references profiles
- look_name
- created_at

---

## Security Features

✅ Row Level Security (RLS)
- Users can only see their own data
- Admins can see all data
- All data is encrypted at rest

✅ Authentication
- Users must be logged in to access their data
- Sessions are managed by Supabase auth

✅ File Storage
- Images stored separately from database
- Public bucket for scan images
- Organized by user ID

---

## Troubleshooting

### "SUPABASE_URL not found"
→ Check your assets/.env file has correct values
→ Make sure flutter_dotenv is initialized before Supabase

### "RLS policy violation"
→ Check you're logged in before accessing data
→ Verify the policy allows your user
→ Admin users should have higher privileges

### "Upload failed"
→ Check bucket exists (scan-images)
→ Verify file permissions
→ Check bucket policies

### "Connection timeout"
→ Check internet connection
→ Verify Supabase URL is correct
→ Check firewall/VPN not blocking

---

## Key Methods Available

### Authentication
- `signUp()` - Create new account
- `signIn()` - Login user
- `signOut()` - Logout user
- `getCurrentUser()` - Get current user
- `isAuthenticated()` - Check if logged in

### User Profile
- `createUserProfile()` - Create profile after signup
- `getUserProfile()` - Fetch user profile
- `updateUserProfile()` - Update user info

### Scans
- `saveScan()` - Save scan to database
- `getScanHistory()` - Get all user scans
- `deleteScan()` - Remove scan

### Favorites
- `addFavoriteLook()` - Save favorite
- `getFavoriteLooks()` - Get all favorites
- `removeFavoriteLook()` - Remove favorite

### Admin
- `getAllUsers()` - Get all users (admin only)
- `getAnalyticsData()` - Get stats (admin only)

### File Storage
- `uploadScanImage()` - Upload image to bucket
- `getPublicImageUrl()` - Get public URL

### Real-time
- `subscribeToUserProfile()` - Listen to profile changes
- `subscribeToNewScans()` - Listen to new scans
- `unsubscribeFromChannel()` - Stop listening

---

## Next Steps

1. Set up Supabase project
2. Run database schema SQL
3. Add Supabase credentials to .env
4. Initialize in main.dart
5. Replace your auth system with SupabaseAuthIntegration
6. Test login/signup/save scan features
7. Deploy when ready!

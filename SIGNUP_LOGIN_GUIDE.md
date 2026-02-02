// SIGNUP & LOGIN SETUP GUIDE

## ✅ Complete Signup/Login System Ready!

### Files Created:
1. ✅ [lib/auth/login_supabase_page.dart](lib/auth/login_supabase_page.dart) - Supabase login
2. ✅ [lib/auth/register_supabase_page.dart](lib/auth/register_supabase_page.dart) - Supabase signup
3. ✅ [database/emails.sql](database/emails.sql) - Emails table
4. ✅ [lib/services/supabase_auth_integration.dart](lib/services/supabase_auth_integration.dart) - Integration
5. ✅ [lib/services/supabase_service.dart](lib/services/supabase_service.dart) - Core Supabase

### Updated Files:
- ✅ [lib/main.dart](lib/main.dart) - Now uses LoginSupabasePage + Provider

---

## 🚀 Setup Steps (3 minutes)

### 1. Ensure Supabase Credentials in .env
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

### 2. Run Database Schema in Supabase
Go to Supabase → SQL Editor → Run this:

**First, run the main schema** [database/schema.sql](database/schema.sql):
```sql
(copy entire file)
```

**Then, run the emails table** [database/emails.sql](database/emails.sql):
```sql
(copy entire file)
```

### 3. Add Provider to pubspec.yaml
```yaml
dependencies:
  provider: ^6.0.0
  supabase_flutter: ^1.10.0
```

Run: `flutter pub get`

---

## ✨ Features

### Login Page ([login_supabase_page.dart](lib/auth/login_supabase_page.dart))
✅ Email/Password login
✅ Password visibility toggle
✅ Remember me checkbox
✅ Forgot password link
✅ Sign up link
✅ Auto-routes to Home (user) or Admin (admin)
✅ Error handling

### Sign Up Page ([register_supabase_page.dart](lib/auth/register_supabase_page.dart))
✅ Full name, email, password
✅ Password confirmation
✅ Terms acceptance
✅ Creates Supabase account
✅ Creates user profile
✅ Auto-login after signup
✅ Link to login page

### Database ([database/schema.sql](database/schema.sql) + [emails.sql](emails.sql))
✅ Profiles table (users with roles)
✅ Emails table (track signups)
✅ Scans table (face scan history)
✅ Favorites table (saved looks)
✅ Row Level Security (RLS) on all tables
✅ Automatic updated_at timestamps

---

## 🎯 How It Works

### Signup Flow:
```
RegisterSupabasePage
  ↓
Enter: Name, Email, Password
  ↓
SupabaseAuthIntegration.signUpWithSupabase()
  ↓
Create Supabase auth user
Create profile in profiles table
Add email to emails table
  ↓
Auto-login & navigate to HomeScreen
```

### Login Flow:
```
LoginSupabasePage
  ↓
Enter: Email, Password
  ↓
SupabaseAuthIntegration.signInWithSupabase()
  ↓
Authenticate with Supabase
Fetch user profile (with role)
Update local AuthService
  ↓
Route to HomeScreen (user) or AdminScreen (admin)
```

---

## 🔐 Security Features

✅ **Row Level Security (RLS)**
- Users can only see their own data
- Admins can see all user data

✅ **Encrypted Passwords**
- Supabase handles password hashing
- Never stored as plaintext

✅ **Session Management**
- Supabase auth tokens
- Automatic refresh
- Secure storage

✅ **Email Validation**
- Required field validation
- Format checking
- Unique email constraint

---

## 🧪 Test the System

### Test Signup:
1. Open app → Sign Up page
2. Enter: Name "John Doe", Email "john@example.com", Password "Test123"
3. Accept terms → Create Account
4. Should go to HomeScreen

### Test Login:
1. Go back → Sign In
2. Email: john@example.com, Password: Test123
3. Should login and go to HomeScreen

### Check in Supabase:
- Go to SQL Editor
- Run: `SELECT * FROM auth.users;` → See your user
- Run: `SELECT * FROM public.profiles;` → See your profile
- Run: `SELECT * FROM public.emails;` → See your email

---

## 📱 User Flow

```
App Starts
  ↓
LoginSupabasePage (First Time)
  ↓
New User? → RegisterSupabasePage → Sign Up
Existing User? → LoginSupabasePage → Sign In
  ↓
Create Supabase Account
  ↓
HomeScreen (Regular User) or AdminScreen (Admin)
  ↓
Scan Faces → Save to database
Add Favorites → Save to database
View History → Load from database
```

---

## 🔧 Troubleshooting

### "Invalid Credentials" on Login
→ Check email exists in Supabase
→ Verify password is correct
→ Check user profile exists

### "Email already registered"
→ User already has account
→ Go to Login page instead

### "Failed to create profile"
→ Check profiles table exists
→ Run database/schema.sql again

### Signup not working
→ Verify .env credentials
→ Check Supabase project is active
→ Check RLS policies allow INSERT

---

## 📊 Database Schema

### profiles table
- id (UUID) → auth.users.id
- email
- full_name
- role ('admin' or 'user')
- created_at

### emails table
- id (UUID)
- email (unique)
- created_at

### scans table
- id (UUID)
- user_id (references profiles)
- look_name
- created_at

### favorites table
- id (UUID)
- user_id (references profiles)
- look_name
- created_at

---

## ✅ What's Ready:

✅ Signup/Login pages
✅ Supabase integration
✅ Database schema
✅ Email tracking
✅ Role-based routing
✅ Error handling
✅ Provider state management

**Everything is set up! Just run the SQL and test. 🚀**

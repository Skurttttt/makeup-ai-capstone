# FaceTune Beauty - Supabase Database Setup

## Quick Setup

### 1. Run the Complete Schema
Copy and paste the entire contents of `supabase_complete_schema.sql` into your Supabase SQL Editor and execute it.

This will create:
- ✅ Tables: profiles, scans, favorites
- ✅ Row Level Security (RLS) policies
- ✅ Indexes for performance
- ✅ Triggers for auto-updating timestamps
- ✅ Trigger for auto-creating profiles on signup
- ✅ Storage bucket for scan images

### 2. Create Your First Admin User

**Option A: Through the App (Recommended)**
1. Sign up through your Flutter app with your admin email
2. Go to Supabase SQL Editor and run:
```sql
UPDATE public.profiles 
SET role = 'admin' 
WHERE email = 'your-admin-email@example.com';
```

**Option B: Manually in Supabase**
1. Create user in Supabase Authentication
2. Run the query above to set their role to admin

### 3. Verify Setup
```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';

-- View all users and roles
SELECT id, email, full_name, role, created_at 
FROM public.profiles 
ORDER BY created_at DESC;

-- Count users by role
SELECT role, COUNT(*) as count 
FROM public.profiles 
GROUP BY role;
```

## Role-Based Access Control

### Roles
- **admin**: Full access to all data, can change user roles
- **user**: Regular app user (default for new signups)
- **client**: Business/client account (managed by admin)

### How Roles Work
1. **New signups** automatically get `role = 'user'`
2. **Only admins** can change roles (enforced by RLS policies)
3. **Users cannot change their own role** (security enforced at database level)

### Changing User Roles (Admin Only)

```sql
-- Make user an admin
UPDATE public.profiles SET role = 'admin' WHERE email = 'user@example.com';

-- Make user a client
UPDATE public.profiles SET role = 'client' WHERE email = 'business@example.com';

-- Revert to regular user
UPDATE public.profiles SET role = 'user' WHERE email = 'someone@example.com';
```

## Security Features

### Row Level Security (RLS)
- ✅ Users can only see/edit their own data
- ✅ Admins can see all data
- ✅ Users CANNOT change their own role
- ✅ Only admins can modify roles

### Profile Updates
Users can update:
- ✅ full_name
- ✅ avatar_url
- ✅ bio
- ✅ phone

Users CANNOT update:
- ❌ role (only admin can)
- ❌ email (managed by Supabase Auth)
- ❌ id
- ❌ created_at

## Migration from Old Schema

If you already have data:

```sql
-- Backup existing data first!
-- Then run add_client_role_migration.sql

-- Drop old constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Add new constraint with client role
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'user', 'client', 'guest'));
```

## Common Admin Queries

```sql
-- View all users
SELECT id, email, full_name, role, created_at 
FROM public.profiles 
ORDER BY created_at DESC;

-- Find users by role
SELECT email, full_name, created_at 
FROM public.profiles 
WHERE role = 'admin';

-- View user activity
SELECT p.email, COUNT(s.id) as scan_count, MAX(s.created_at) as last_scan
FROM public.profiles p
LEFT JOIN public.scans s ON p.id = s.user_id
GROUP BY p.id, p.email
ORDER BY scan_count DESC;

-- Get storage usage
SELECT 
  (storage.foldername(name))[1] as user_id,
  COUNT(*) as image_count,
  pg_size_pretty(SUM(metadata->>'size')::bigint) as total_size
FROM storage.objects
WHERE bucket_id = 'scan-images'
GROUP BY user_id;
```

## Troubleshooting

### Issue: RLS blocking queries
```sql
-- Temporarily disable RLS for testing (NOT recommended for production)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Re-enable when done
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
```

### Issue: Can't update role
Make sure you're logged in as an admin user in your app, or run SQL directly in Supabase as the postgres user.

### Issue: Trigger not creating profiles
```sql
-- Check if trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Manually create profile for existing user
INSERT INTO public.profiles (id, email, full_name, role)
VALUES ('user-uuid-here', 'email@example.com', 'Full Name', 'user')
ON CONFLICT (id) DO NOTHING;
```

## Environment Variables

Make sure your `.env` file has:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

## Next Steps

1. ✅ Run `supabase_complete_schema.sql` in Supabase SQL Editor
2. ✅ Create your admin user
3. ✅ Test signup through your app
4. ✅ Verify profile was created automatically
5. ✅ Test role-based access in your admin panel

For questions or issues, check the Supabase docs: https://supabase.com/docs

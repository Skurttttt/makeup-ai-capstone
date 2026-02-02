-- ADMIN SETUP GUIDE

-- Step 1: First, create a user account through the app signup
-- (Or manually in Supabase Auth if you prefer)

-- Step 2: Once user is created, set their role to 'admin' using this query:
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'admin@example.com';

-- Step 3: Verify the admin user was created:
SELECT id, email, full_name, role, created_at 
FROM public.profiles 
WHERE email = 'admin@example.com';

-- Step 4: View all users and their roles:
SELECT email, full_name, role, created_at 
FROM public.profiles 
ORDER BY created_at DESC;

-- Step 5: If you need to change someone back to user:
UPDATE public.profiles
SET role = 'user'
WHERE email = 'user@example.com';

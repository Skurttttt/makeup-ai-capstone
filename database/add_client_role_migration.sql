-- Migration: Add 'client' role to profiles table
-- This updates the CHECK constraint to include the new 'client' role

-- Step 1: Drop the existing constraint
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Step 2: Add new constraint with client role
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'user', 'client'));

-- Step 3: Update any existing users who should be clients (if needed)
-- Example: UPDATE public.profiles SET role = 'client' WHERE email LIKE '%@business.com';

-- Verify the change
SELECT constraint_name, check_clause 
FROM information_schema.check_constraints 
WHERE constraint_name = 'profiles_role_check';

-- Show current role distribution
SELECT role, COUNT(*) as count 
FROM public.profiles 
GROUP BY role;

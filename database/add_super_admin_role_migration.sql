-- Migration: Add 'staff' and 'super_admin' roles to accounts/profiles
-- This updates the CHECK constraint to include new roles

-- Step 1: Drop the existing constraint on accounts (if exists)
ALTER TABLE public.accounts 
DROP CONSTRAINT IF EXISTS accounts_role_check;

-- Step 2: Add new constraint including staff and super_admin
ALTER TABLE public.accounts 
ADD CONSTRAINT accounts_role_check 
CHECK (role IN ('admin', 'user', 'client', 'staff', 'super_admin'));

-- For older schema that uses profiles table, update that too
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'user', 'client', 'staff', 'super_admin'));

-- Verify changes
SELECT constraint_name, check_clause 
FROM information_schema.check_constraints 
WHERE constraint_name IN ('accounts_role_check','profiles_role_check');

-- Show role distribution
SELECT role, COUNT(*) as count 
FROM public.accounts 
GROUP BY role;

SELECT role, COUNT(*) as count 
FROM public.profiles 
GROUP BY role;

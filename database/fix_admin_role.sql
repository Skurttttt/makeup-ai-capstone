-- Fix admin role for your account
-- Run this in Supabase SQL Editor

-- First, check your current role
SELECT id, email, role, full_name 
FROM public.accounts 
WHERE email = 'brentreed623@gmail.com';

-- Update your account to admin role
UPDATE public.accounts 
SET role = 'admin' 
WHERE email = 'brentreed623@gmail.com';

-- Verify the change
SELECT id, email, role, full_name 
FROM public.accounts 
WHERE email = 'brentreed623@gmail.com';

-- Also update auth.users metadata for redundancy
UPDATE auth.users
SET raw_user_meta_data = 
  CASE 
    WHEN raw_user_meta_data IS NULL THEN jsonb_build_object('role', 'admin')
    ELSE raw_user_meta_data || jsonb_build_object('role', 'admin')
  END,
  raw_app_meta_data = 
  CASE 
    WHEN raw_app_meta_data IS NULL THEN jsonb_build_object('role', 'admin')
    ELSE raw_app_meta_data || jsonb_build_object('role', 'admin')
  END
WHERE email = 'brentreed623@gmail.com';

-- Verify auth metadata
SELECT id, email, 
  raw_user_meta_data->>'role' as user_meta_role,
  raw_app_meta_data->>'role' as app_meta_role
FROM auth.users 
WHERE email = 'brentreed623@gmail.com';

-- Fix RLS policies to check accounts table instead of JWT for admin status
-- This allows admins to see all accounts and audit logs

-- Update is_admin function to check the accounts table (using CREATE OR REPLACE to preserve dependencies)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.accounts 
    WHERE id = auth.uid() 
    AND role = 'admin'
  );
$$;

-- Now recreate the policies for accounts to allow admins to see all accounts

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own account" ON public.accounts;
DROP POLICY IF EXISTS "Users can insert their own account" ON public.accounts;
DROP POLICY IF EXISTS "Users can update their own account" ON public.accounts;

-- Recreate with admin access
CREATE POLICY "Users can view their own account or admins can view all"
  ON public.accounts
  FOR SELECT
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users can insert their own account"
  ON public.accounts
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own account or admins can update any"
  ON public.accounts
  FOR UPDATE
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Admins can delete accounts"
  ON public.accounts
  FOR DELETE
  USING (public.is_admin());

-- Verify the function works
SELECT 
  auth.uid() as current_user_id,
  public.is_admin() as is_admin,
  (SELECT role FROM public.accounts WHERE id = auth.uid()) as role_in_table;

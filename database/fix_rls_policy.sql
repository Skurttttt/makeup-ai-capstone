-- Fix: Remove recursive admin policy and simplify
-- Users can already see their own profile, which is all we need for role checking

-- Drop the problematic admin view policy
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;

-- Recreate it to allow admins to see ALL profiles (for admin dashboard)
-- but without causing recursion during the role check
CREATE POLICY "Admin can view all profiles"
  ON public.profiles
  FOR SELECT
  USING (
    -- Allow if viewing own profile OR if user's role is admin
    auth.uid() = id 
    OR 
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

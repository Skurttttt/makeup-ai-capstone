-- Fix RLS policies to allow users to create subscriptions and log their actions

-- 1. Allow users to insert their own subscriptions
DROP POLICY IF EXISTS "Users can create their own subscriptions" ON public.user_subscriptions;
CREATE POLICY "Users can create their own subscriptions"
  ON public.user_subscriptions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 2. Allow all authenticated users to insert audit logs (not just admins)
DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Authenticated users can insert audit logs" ON public.audit_logs;
CREATE POLICY "Authenticated users can insert audit logs"
  ON public.audit_logs
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Users can view their own audit logs
DROP POLICY IF EXISTS "Users can view their own audit logs" ON public.audit_logs;
CREATE POLICY "Users can view their own audit logs"
  ON public.audit_logs
  FOR SELECT
  USING (auth.uid() = actor_id OR public.is_admin());

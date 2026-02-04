-- SUPABASE DATABASE SCHEMA

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Create accounts table (extends auth.users)
CREATE TABLE public.accounts (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email text UNIQUE NOT NULL,
  full_name text,
  role text DEFAULT 'user' CHECK (role IN ('admin', 'user', 'client')),
  avatar_url text,
  bio text,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS on accounts
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Helper: admin check using JWT claims (no table recursion)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role')::text,
    (auth.jwt() -> 'user_metadata' ->> 'role')::text,
    ''
  ) = 'admin';
$$;

-- Create policies for accounts
CREATE POLICY "Users can view their own account"
  ON public.accounts
  FOR SELECT
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users can insert their own account"
  ON public.accounts
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own account"
  ON public.accounts
  FOR UPDATE
  USING (auth.uid() = id);

-- 2. Create scans table
CREATE TABLE public.scans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  look_name text NOT NULL,
  image_path text,
  image_url text,
  face_data jsonb,
  skin_tone text,
  face_shape text,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS on scans
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

-- Create policies for scans
CREATE POLICY "Users can view their own scans"
  ON public.scans
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own scans"
  ON public.scans
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own scans"
  ON public.scans
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own scans"
  ON public.scans
  FOR DELETE
  USING (auth.uid() = user_id);

-- 3. Create favorites table
CREATE TABLE public.favorites (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  look_name text NOT NULL,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, look_name)
);

-- Enable RLS on favorites
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Create policies for favorites
CREATE POLICY "Users can view their own favorites"
  ON public.favorites
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites"
  ON public.favorites
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
  ON public.favorites
  FOR DELETE
  USING (auth.uid() = user_id);

-- 4. Create plans table (for subscription plan definitions - managed by admin)
CREATE TABLE public.plans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  description text,
  price numeric(10,2) NOT NULL,
  currency text DEFAULT 'PHP',
  billing_period text DEFAULT 'month',
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view plans"
  ON public.plans
  FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage plans"
  ON public.plans
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 5. Create subscriptions table (for user purchases)
CREATE TABLE public.subscriptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  plan_id uuid REFERENCES public.plans(id) ON DELETE RESTRICT NOT NULL,
  status text NOT NULL CHECK (status IN ('trial', 'active', 'past_due', 'canceled', 'expired')),
  current_period_end timestamp with time zone,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscriptions"
  ON public.subscriptions
  FOR SELECT
  USING (auth.uid() = account_id);

CREATE POLICY "Admins can manage subscriptions"
  ON public.subscriptions
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 6. Create profits table
CREATE TABLE public.profits (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profit_date date NOT NULL,
  amount numeric(12,2) NOT NULL,
  source text NOT NULL,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.profits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage profits"
  ON public.profits
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 6. Create audit logs table
CREATE TABLE public.audit_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  actor_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  action text NOT NULL,
  target text,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs"
  ON public.audit_logs
  FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can insert audit logs"
  ON public.audit_logs
  FOR INSERT
  WITH CHECK (public.is_admin());

-- 7. Create verification codes table
CREATE TABLE public.verification_codes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  email text NOT NULL UNIQUE,
  code text NOT NULL,
  attempts int DEFAULT 0,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  expires_at timestamp with time zone DEFAULT (CURRENT_TIMESTAMP + interval '15 minutes'),
  verified_at timestamp with time zone
);

ALTER TABLE public.verification_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert verification codes"
  ON public.verification_codes
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Anyone can read verification codes"
  ON public.verification_codes
  FOR SELECT
  USING (true);

CREATE POLICY "Anyone can update verification codes"
  ON public.verification_codes
  FOR UPDATE
  USING (true);

-- 8. Create storage bucket for scan images
INSERT INTO storage.buckets (id, name, public)
VALUES ('scan-images', 'scan-images', true)
ON CONFLICT (id) DO NOTHING;

-- Create policies for storage
DROP POLICY IF EXISTS "Users can upload their own scan images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own scan images" ON storage.objects;

CREATE POLICY "Users can upload their own scan images"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'scan-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own scan images"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'scan-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- 5. Create indexes for better performance
CREATE INDEX scans_user_id_idx ON public.scans(user_id);
CREATE INDEX scans_created_at_idx ON public.scans(created_at);
CREATE INDEX favorites_user_id_idx ON public.favorites(user_id);
CREATE INDEX accounts_role_idx ON public.accounts(role);
CREATE INDEX subscriptions_account_id_idx ON public.subscriptions(account_id);
CREATE INDEX profits_profit_date_idx ON public.profits(profit_date);
CREATE INDEX audit_logs_created_at_idx ON public.audit_logs(created_at);
CREATE INDEX verification_codes_email_idx ON public.verification_codes(email);
CREATE INDEX verification_codes_expires_at_idx ON public.verification_codes(expires_at);

-- 6. Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop trigger and function if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create function to auto-create account and subscription on signup
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create account record
  INSERT INTO public.accounts (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'user'
  );
  
  -- Create default "regular" (free) subscription for new user
  INSERT INTO public.subscriptions (account_id, plan, status, current_period_end)
  VALUES (
    NEW.id,
    'regular',
    'active',
    NOW() + INTERVAL '100 years'
  );
  
  RETURN NEW;
END;
$$;

-- Create trigger to auto-create account and subscription when user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Apply trigger to accounts
CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to scans
CREATE TRIGGER update_scans_updated_at BEFORE UPDATE ON public.scans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

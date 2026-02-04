-- ============================================
-- DEPRECATED: Use schema.sql instead
-- FACETUNE BEAUTY - OLD SCHEMA (DO NOT USE)
-- This file uses 'profiles' table - outdated
-- Run schema.sql instead which uses 'accounts'
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PROFILES TABLE (User accounts)
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email text UNIQUE NOT NULL,
  full_name text,
  role text DEFAULT 'user' CHECK (role IN ('admin', 'user', 'client')),
  avatar_url text,
  bio text,
  phone text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile (not role)" ON public.profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admin can update any profile" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;

-- RLS Policies for profiles
-- Users can view their own profile
CREATE POLICY "Users can view their own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile BUT NOT their role
CREATE POLICY "Users can update their own profile (not role)"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    role = (SELECT role FROM public.profiles WHERE id = auth.uid())
  );

-- Admin can view all profiles
CREATE POLICY "Admin can view all profiles"
  ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admin can update any profile including roles
CREATE POLICY "Admin can update any profile"
  ON public.profiles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 2. SCANS TABLE (Face scans history)
-- ============================================
CREATE TABLE IF NOT EXISTS public.scans (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  look_name text NOT NULL,
  image_path text,
  image_url text,
  face_data jsonb,
  skin_tone text,
  face_shape text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can insert their own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can update their own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can delete their own scans" ON public.scans;
DROP POLICY IF EXISTS "Admin can view all scans" ON public.scans;

-- RLS Policies for scans
CREATE POLICY "Users can view their own scans"
  ON public.scans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own scans"
  ON public.scans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own scans"
  ON public.scans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own scans"
  ON public.scans FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Admin can view all scans"
  ON public.scans FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 3. FAVORITES TABLE (User favorite looks)
-- ============================================
CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  look_name text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, look_name)
);

-- Enable RLS
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can insert their own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can delete their own favorites" ON public.favorites;

-- RLS Policies for favorites
CREATE POLICY "Users can view their own favorites"
  ON public.favorites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites"
  ON public.favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
  ON public.favorites FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 4. INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS scans_user_id_idx ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS scans_created_at_idx ON public.scans(created_at DESC);
CREATE INDEX IF NOT EXISTS favorites_user_id_idx ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);

-- ============================================
-- 5. TRIGGER FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'user' -- Default role is 'user'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. TRIGGERS
-- ============================================

-- Drop existing triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
DROP TRIGGER IF EXISTS scans_updated_at ON public.scans;

-- Trigger to create profile when user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger to update updated_at on profiles
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger to update updated_at on scans
CREATE TRIGGER scans_updated_at
  BEFORE UPDATE ON public.scans
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- 7. STORAGE BUCKETS
-- ============================================

-- Create storage bucket for scan images (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('scan-images', 'scan-images', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Users can upload their own scan images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own scan images" ON storage.objects;
DROP POLICY IF EXISTS "Public scan images are viewable" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;

-- Storage policies
CREATE POLICY "Users can upload their own scan images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'scan-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own scan images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'scan-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Public scan images are viewable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'scan-images');

CREATE POLICY "Users can delete their own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'scan-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================
-- 8. CREATE INITIAL ADMIN USER (OPTIONAL)
-- ============================================
-- After running this schema, manually create an admin user:
-- 1. Sign up through your app
-- 2. Run this SQL to make them admin:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your-admin-email@example.com';

-- Or insert directly (must have matching auth.users entry):
-- INSERT INTO public.profiles (id, email, full_name, role)
-- VALUES ('your-uuid-here', 'admin@example.com', 'Admin User', 'admin');

-- ============================================
-- 9. HELPFUL QUERIES
-- ============================================

-- View all users and their roles
-- SELECT id, email, full_name, role, created_at FROM public.profiles ORDER BY created_at DESC;

-- Count users by role
-- SELECT role, COUNT(*) as count FROM public.profiles GROUP BY role;

-- Change a user's role (admin only)
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'user@example.com';

-- View all scans with user info
-- SELECT s.*, p.email, p.full_name 
-- FROM public.scans s 
-- JOIN public.profiles p ON s.user_id = p.id 
-- ORDER BY s.created_at DESC;

-- ============================================
-- SCHEMA COMPLETE
-- ============================================

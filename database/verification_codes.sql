-- Add verification codes table
CREATE TABLE IF NOT EXISTS public.verification_codes (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  email text NOT NULL,
  code text NOT NULL,
  attempts int DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  expires_at timestamp with time zone DEFAULT timezone('utc'::text, now() + interval '15 minutes') NOT NULL,
  verified_at timestamp with time zone,
  UNIQUE(email)
);

-- Enable RLS
ALTER TABLE public.verification_codes ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert verification codes (for signup)
CREATE POLICY "Anyone can insert verification codes"
  ON public.verification_codes
  FOR INSERT
  WITH CHECK (true);

-- Allow users to check their own verification codes
CREATE POLICY "Users can check their own verification codes"
  ON public.verification_codes
  FOR SELECT
  USING (true);

-- Allow users to update their own verification codes (mark as verified)
CREATE POLICY "Users can update their own verification codes"
  ON public.verification_codes
  FOR UPDATE
  USING (true);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS verification_codes_email_idx ON public.verification_codes(email);
CREATE INDEX IF NOT EXISTS verification_codes_expires_at_idx ON public.verification_codes(expires_at);

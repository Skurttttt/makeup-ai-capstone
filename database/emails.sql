-- EMAILS TABLE (BASIC)

-- Create emails table
CREATE TABLE public.emails (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  email text UNIQUE NOT NULL,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS
ALTER TABLE public.emails ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert their own email
CREATE POLICY "Users can insert their own email"
  ON public.emails
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Allow authenticated users to read emails
CREATE POLICY "Users can read emails"
  ON public.emails
  FOR SELECT
  USING (auth.uid() IS NOT NULL);


-- Support requests table: captures in-app contact-support submissions
-- so the admin panel can display them as notifications.

CREATE TABLE IF NOT EXISTS public.support_requests (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  email       text,
  subject     text NOT NULL DEFAULT 'Support Request',
  message     text NOT NULL,
  status      text NOT NULL DEFAULT 'open'
              CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  created_at  timestamp with time zone DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_support_requests_user_id    ON public.support_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_support_requests_created_at ON public.support_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_requests_status     ON public.support_requests(status);

-- Row-level security
ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can submit a request
CREATE POLICY "Users can insert their own support requests"
  ON public.support_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Only admins can read/update/delete
CREATE POLICY "Admins can manage support requests"
  ON public.support_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.accounts
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

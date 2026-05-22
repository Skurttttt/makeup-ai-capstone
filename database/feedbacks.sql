-- Feedbacks table: stores in-app feedback from users

CREATE TABLE IF NOT EXISTS public.feedbacks (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  email       text,
  rating      integer CHECK (rating >= 1 AND rating <= 5),
  message     text NOT NULL,
  status      text NOT NULL DEFAULT 'open'
               CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  created_at  timestamp with time zone DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_feedbacks_user_id    ON public.feedbacks(user_id);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON public.feedbacks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedbacks_status     ON public.feedbacks(status);

-- Row-level security
ALTER TABLE public.feedbacks ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can insert feedback
CREATE POLICY "Users can insert their own feedback"
  ON public.feedbacks FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Only admins can read/update/delete
CREATE POLICY "Admins can manage feedbacks"
  ON public.feedbacks FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.accounts
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

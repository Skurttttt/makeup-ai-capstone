-- ============================================================
-- Migration: Delivery Proof System (full)
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. Storage bucket ─────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('delivery-proofs', 'delivery-proofs', true)
ON CONFLICT (id) DO NOTHING;

-- ── 2. Add delivery tracking columns to orders ────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_confirmed_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS delivery_proof_id     uuid,
  ADD COLUMN IF NOT EXISTS delivery_confidence   numeric DEFAULT 0;

-- ── 3. Create delivery_proofs table ──────────────────────────
CREATE TABLE IF NOT EXISTS public.delivery_proofs (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id         text,
  tracking_number  text,
  user_id          uuid REFERENCES public.accounts(id) ON DELETE CASCADE,
  image_path       text,
  image_url        text,
  exif_lat         numeric,
  exif_lng         numeric,
  exif_timestamp   timestamp with time zone,
  -- Confidence components (each contributes to overall score)
  score_carrier    numeric DEFAULT 0,  -- carrier API says delivered   (+0.50)
  score_photo      numeric DEFAULT 0,  -- photo uploaded               (+0.25)
  score_gps        numeric DEFAULT 0,  -- GPS within radius            (+0.25)
  score_otp        numeric DEFAULT 0,  -- OTP verified                 (+0.40)
  score_confirm    numeric DEFAULT 0,  -- one-tap customer confirm     (+0.20)
  confidence       numeric GENERATED ALWAYS AS (
    LEAST(1.0, COALESCE(score_carrier,0)
            + COALESCE(score_photo,0)
            + COALESCE(score_gps,0)
            + COALESCE(score_otp,0)
            + COALESCE(score_confirm,0))
  ) STORED,
  status           text DEFAULT 'pending'
                   CHECK (status IN ('pending','verified','rejected','auto_verified')),
  rejection_reason text,
  created_at       timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at       timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ── 4. OTP codes table (packing-slip OTPs) ────────────────────
CREATE TABLE IF NOT EXISTS public.delivery_otps (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id        text NOT NULL,
  code            text NOT NULL,
  used            boolean DEFAULT false,
  expires_at      timestamp with time zone NOT NULL,
  created_at      timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ── 5. Auto-scoring trigger function ─────────────────────────
CREATE OR REPLACE FUNCTION public.auto_verify_delivery_proof()
RETURNS TRIGGER AS $$
DECLARE
  total_confidence numeric;
BEGIN
  total_confidence :=
    LEAST(1.0,
      COALESCE(NEW.score_carrier, 0) +
      COALESCE(NEW.score_photo,   0) +
      COALESCE(NEW.score_gps,     0) +
      COALESCE(NEW.score_otp,     0) +
      COALESCE(NEW.score_confirm, 0)
    );

  -- Auto-verify if confidence >= 0.75
  IF total_confidence >= 0.75 AND NEW.status = 'pending' THEN
    NEW.status := 'auto_verified';
  END IF;

  -- Sync order status to delivered when auto-verified or manually verified
  IF NEW.status IN ('auto_verified', 'verified') AND NEW.order_id IS NOT NULL THEN
    UPDATE public.orders
    SET
      status                  = 'delivered',
      delivery_confirmed_at   = timezone('utc'::text, now()),
      delivery_proof_id       = NEW.id,
      delivery_confidence     = total_confidence,
      delivered_at            = COALESCE(delivered_at, timezone('utc'::text, now()))
    WHERE id::text = NEW.order_id
      AND status != 'delivered';
  END IF;

  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_verify_delivery_proof ON public.delivery_proofs;
CREATE TRIGGER trg_auto_verify_delivery_proof
  BEFORE INSERT OR UPDATE ON public.delivery_proofs
  FOR EACH ROW EXECUTE FUNCTION public.auto_verify_delivery_proof();

-- ── 6. OTP verify function ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_delivery_otp(
  p_order_id text,
  p_code     text
)
RETURNS boolean AS $$
DECLARE
  v_otp_id uuid;
BEGIN
  SELECT id INTO v_otp_id
  FROM public.delivery_otps
  WHERE order_id = p_order_id
    AND code = p_code
    AND used = false
    AND expires_at > timezone('utc'::text, now())
  LIMIT 1;

  IF v_otp_id IS NULL THEN
    RETURN false;
  END IF;

  -- Mark OTP as used
  UPDATE public.delivery_otps SET used = true WHERE id = v_otp_id;

  -- Award OTP score to any pending proof for this order
  UPDATE public.delivery_proofs
  SET score_otp = 0.40
  WHERE order_id = p_order_id AND status = 'pending';

  -- If no proof row exists yet, create one with just the OTP score
  IF NOT EXISTS (
    SELECT 1 FROM public.delivery_proofs WHERE order_id = p_order_id
  ) THEN
    INSERT INTO public.delivery_proofs (order_id, score_otp)
    VALUES (p_order_id, 0.40);
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 7. Customer one-tap confirm function ─────────────────────
CREATE OR REPLACE FUNCTION public.confirm_delivery(
  p_order_id text,
  p_user_id  uuid
)
RETURNS void AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.delivery_proofs WHERE order_id = p_order_id
  ) THEN
    UPDATE public.delivery_proofs
    SET score_confirm = 0.20
    WHERE order_id = p_order_id;
  ELSE
    INSERT INTO public.delivery_proofs (order_id, user_id, score_confirm)
    VALUES (p_order_id, p_user_id, 0.20);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 8. RLS policies ───────────────────────────────────────────
ALTER TABLE public.delivery_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_otps    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own delivery proofs" ON public.delivery_proofs;
DROP POLICY IF EXISTS "Users can view their own delivery proofs"   ON public.delivery_proofs;
DROP POLICY IF EXISTS "Admins can view delivery proofs"            ON public.delivery_proofs;
DROP POLICY IF EXISTS "Admins can update delivery proof status"    ON public.delivery_proofs;

CREATE POLICY "Users can insert their own delivery proofs"
  ON public.delivery_proofs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own delivery proofs"
  ON public.delivery_proofs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view delivery proofs"
  ON public.delivery_proofs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.accounts WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

CREATE POLICY "Admins can update delivery proof status"
  ON public.delivery_proofs FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.accounts WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- OTPs: only service role can insert; anyone can call verify_delivery_otp()
CREATE POLICY "Service role manages OTPs"
  ON public.delivery_otps FOR ALL
  USING (true);

-- ── 9. Indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS delivery_proofs_user_id_idx  ON public.delivery_proofs(user_id);
CREATE INDEX IF NOT EXISTS delivery_proofs_order_id_idx ON public.delivery_proofs(order_id);
CREATE INDEX IF NOT EXISTS delivery_proofs_status_idx   ON public.delivery_proofs(status);
CREATE INDEX IF NOT EXISTS delivery_otps_order_id_idx   ON public.delivery_otps(order_id);

-- ── 10. Storage policy ────────────────────────────────────────
DROP POLICY IF EXISTS "Users can upload their own delivery proof images" ON storage.objects;
CREATE POLICY "Users can upload their own delivery proof images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'delivery-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── Done ──────────────────────────────────────────────────────
-- Verify:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'delivery_proofs' ORDER BY ordinal_position;

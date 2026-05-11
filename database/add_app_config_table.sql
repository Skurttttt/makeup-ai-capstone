-- Migration: Create app_config table for storing runtime configuration

CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text
);

COMMENT ON TABLE public.app_config IS 'Key/value configuration used by edge functions when environment variables are not available';

-- Example inserts (DO NOT commit secrets in code):
-- INSERT INTO public.app_config (key, value) VALUES ('PAYMONGO_SECRET_KEY', 'sk_live_xxx');
-- INSERT INTO public.app_config (key, value) VALUES ('PAYMONGO_SUCCESS_URL', 'https://your-domain.com/payment/success');
-- INSERT INTO public.app_config (key, value) VALUES ('PAYMONGO_CANCEL_URL', 'https://your-domain.com/payment/cancel');

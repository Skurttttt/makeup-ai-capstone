-- PayMongo integration schema for marketplace orders and subscriptions

-- 1. Add PayMongo metadata fields to subscription tables
ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS payment_provider text DEFAULT 'paymongo',
  ADD COLUMN IF NOT EXISTS provider_plan_id text,
  ADD COLUMN IF NOT EXISTS provider_plan_code text;

ALTER TABLE public.user_subscriptions
  ADD COLUMN IF NOT EXISTS payment_provider text DEFAULT 'paymongo',
  ADD COLUMN IF NOT EXISTS provider_subscription_id text,
  ADD COLUMN IF NOT EXISTS provider_customer_id text,
  ADD COLUMN IF NOT EXISTS provider_payment_id text,
  ADD COLUMN IF NOT EXISTS provider_payment_method_id text,
  ADD COLUMN IF NOT EXISTS provider_checkout_session_id text;

-- 2. Orders table (marketplace purchases)
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  buyer_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'canceled', 'refunded')),
  currency text NOT NULL DEFAULT 'PHP',
  subtotal numeric(10,2) NOT NULL DEFAULT 0,
  tax numeric(10,2) NOT NULL DEFAULT 0,
  shipping numeric(10,2) NOT NULL DEFAULT 0,
  total numeric(10,2) NOT NULL DEFAULT 0,
  payment_provider text NOT NULL DEFAULT 'paymongo',
  provider_checkout_session_id text,
  provider_payment_id text,
  provider_status text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  product_id uuid REFERENCES public.products(id) ON DELETE RESTRICT NOT NULL,
  business_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  unit_price numeric(10,2) NOT NULL DEFAULT 0,
  total_price numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Payment sessions table (PayMongo checkout tracking)
CREATE TABLE IF NOT EXISTS public.payment_sessions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  session_type text NOT NULL CHECK (session_type IN ('order', 'subscription')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'canceled')),
  amount numeric(10,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'PHP',
  payment_provider text NOT NULL DEFAULT 'paymongo',
  provider_checkout_session_id text,
  provider_checkout_url text,
  provider_payment_id text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 4. Payment events log (webhooks)
CREATE TABLE IF NOT EXISTS public.payment_events (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  payment_provider text NOT NULL DEFAULT 'paymongo',
  event_type text NOT NULL,
  provider_event_id text,
  payload jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Ensure updated_at helper exists
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Updated_at trigger reuse
DROP TRIGGER IF EXISTS trg_set_updated_at_orders ON public.orders;
CREATE TRIGGER trg_set_updated_at_orders
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at_payment_sessions ON public.payment_sessions;
CREATE TRIGGER trg_set_updated_at_payment_sessions
BEFORE UPDATE ON public.payment_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

-- Orders policies
CREATE POLICY "Users can view their own orders"
  ON public.orders
  FOR SELECT
  USING (auth.uid() = buyer_id);

CREATE POLICY "Users can create their own orders"
  ON public.orders
  FOR INSERT
  WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Admins can manage orders"
  ON public.orders
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Order items policies
CREATE POLICY "Users can view their own order items"
  ON public.order_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id AND o.buyer_id = auth.uid()
    )
  );

CREATE POLICY "Business owners can view their order items"
  ON public.order_items
  FOR SELECT
  USING (auth.uid() = business_id);

CREATE POLICY "Admins can manage order items"
  ON public.order_items
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Payment sessions policies
CREATE POLICY "Users can view their own payment sessions"
  ON public.payment_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage payment sessions"
  ON public.payment_sessions
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Payment events policies (admin only)
CREATE POLICY "Admins can view payment events"
  ON public.payment_events
  FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can manage payment events"
  ON public.payment_events
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_business_id ON public.order_items(business_id);
CREATE INDEX IF NOT EXISTS idx_payment_sessions_user_id ON public.payment_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_sessions_provider_id ON public.payment_sessions(provider_checkout_session_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_type ON public.payment_events(event_type);

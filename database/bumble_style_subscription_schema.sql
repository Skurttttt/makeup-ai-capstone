-- BUMBLE-STYLE SUBSCRIPTION SYSTEM FOR MAKEUP APP
-- Inspired by Bumble's tiered subscription model with feature gating

-- Drop existing plans and subscriptions tables if needed (for migration)
-- DROP TABLE IF EXISTS public.subscriptions CASCADE;
-- DROP TABLE IF EXISTS public.plans CASCADE;

-- 1. Create subscription plans table (like Bumble Boost/Premium)
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE, -- 'Free', 'Pro', 'Premium', 'Lifetime Premium'
  display_name text NOT NULL, -- 'FaceTune Pro', 'FaceTune Premium'
  description text,
  price numeric(10,2) NOT NULL DEFAULT 0,
  currency text DEFAULT 'PHP',
  billing_period text NOT NULL DEFAULT 'month', -- 'week', 'month', '3months', '6months', 'year', 'lifetime'
  
  -- Feature limits (like Bumble's feature gating)
  daily_scan_limit integer DEFAULT -1, -- -1 = unlimited, 0 = none, >0 = daily limit
  total_scan_limit integer DEFAULT -1, -- -1 = unlimited for lifetime
  available_looks jsonb DEFAULT '[]'::jsonb, -- Array of look names user can access
  can_save_results boolean DEFAULT false,
  can_export_hd boolean DEFAULT false,
  can_use_filters boolean DEFAULT false,
  priority_processing boolean DEFAULT false,
  remove_watermark boolean DEFAULT false,
  access_exclusive_looks boolean DEFAULT false,
  
  -- Display settings
  badge_color text, -- Color for the subscription badge
  badge_text text, -- 'BEST VALUE', 'POPULAR', etc.
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create user subscriptions table (tracks what users have purchased)
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  plan_id uuid REFERENCES public.subscription_plans(id) ON DELETE RESTRICT NOT NULL,
  
  -- Subscription status (like Bumble's active/expired states)
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'past_due', 'canceled', 'expired', 'paused')),
  
  -- Billing cycle tracking
  started_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  current_period_start timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  current_period_end timestamp with time zone,
  canceled_at timestamp with time zone,
  
  -- Payment tracking
  payment_method text, -- 'gcash', 'paymaya', 'credit_card', 'admin_grant'
  transaction_id text,
  amount_paid numeric(10,2),
  
  -- Auto-renewal (like Bumble's subscription management)
  auto_renew boolean DEFAULT false,
  renewal_reminder_sent boolean DEFAULT false,
  
  -- Usage tracking
  scans_used_today integer DEFAULT 0,
  scans_used_total integer DEFAULT 0,
  last_scan_date date,
  
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  
  UNIQUE(user_id, plan_id, current_period_start) -- Prevent duplicate active subscriptions
);

-- 3. Create one-time purchases table (like Bumble's Super Swipes/Spotlight)
CREATE TABLE IF NOT EXISTS public.one_time_purchases (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  
  -- Purchase type
  product_type text NOT NULL CHECK (product_type IN ('look_pack', 'scan_bundle', 'hd_export', 'exclusive_look', 'filter_pack')),
  product_name text NOT NULL,
  
  -- Quantity/usage
  quantity integer DEFAULT 1, -- For consumables like scan bundles
  used_quantity integer DEFAULT 0,
  
  -- Pricing
  price numeric(10,2) NOT NULL,
  currency text DEFAULT 'PHP',
  
  -- Payment info
  payment_method text,
  transaction_id text,
  
  -- Status
  status text DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
  expires_at timestamp with time zone, -- For time-limited purchases
  
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create usage tracking table (tracks daily limits like Bumble)
CREATE TABLE IF NOT EXISTS public.usage_tracking (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  tracking_date date DEFAULT CURRENT_DATE NOT NULL,
  
  -- Daily usage counters
  scans_today integer DEFAULT 0,
  exports_today integer DEFAULT 0,
  
  -- Feature usage flags
  features_used jsonb DEFAULT '{}'::jsonb,
  
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  
  UNIQUE(user_id, tracking_date)
);

-- Enable Row Level Security
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.one_time_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_tracking ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscription_plans
CREATE POLICY "Anyone can view active plans" ON public.subscription_plans
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage plans" ON public.subscription_plans
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- RLS Policies for user_subscriptions
CREATE POLICY "Users can view their own subscriptions" ON public.user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all subscriptions" ON public.user_subscriptions
  FOR SELECT USING (public.is_admin());

CREATE POLICY "Admins can manage subscriptions" ON public.user_subscriptions
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- RLS Policies for one_time_purchases
CREATE POLICY "Users can view their own purchases" ON public.one_time_purchases
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all purchases" ON public.one_time_purchases
  FOR SELECT USING (public.is_admin());

-- RLS Policies for usage_tracking
CREATE POLICY "Users can view their own usage" ON public.usage_tracking
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own usage" ON public.usage_tracking
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all usage" ON public.usage_tracking
  FOR SELECT USING (public.is_admin());

-- Insert default subscription plans (Bumble-style tiers)
INSERT INTO public.subscription_plans (
  name, display_name, description, price, billing_period,
  daily_scan_limit, available_looks, can_save_results, can_export_hd,
  remove_watermark, badge_color, badge_text, sort_order
) VALUES 
  -- Free Tier (like Bumble's free version)
  (
    'free',
    'FaceTune Free',
    'Try basic makeup looks with limited scans',
    0,
    'lifetime',
    3, -- 3 scans per day
    '["softGlam"]'::jsonb, -- Only 1 look available
    false, -- Can't save results
    false, -- No HD export
    false, -- Has watermark
    '#78909C',
    null,
    1
  ),
  
  -- Pro Weekly (like Bumble Boost weekly)
  (
    'pro_weekly',
    'FaceTune Pro',
    'Unlock more looks and unlimited scans',
    99,
    'week',
    -1, -- Unlimited scans
    '["softGlam", "emo", "dollKBeauty"]'::jsonb,
    true,
    false,
    true,
    '#FF4D97',
    null,
    2
  ),
  
  -- Pro Monthly (like Bumble Boost monthly)
  (
    'pro_monthly',
    'FaceTune Pro',
    'Unlock more looks and unlimited scans',
    299,
    'month',
    -1,
    '["softGlam", "emo", "dollKBeauty"]'::jsonb,
    true,
    false,
    true,
    '#FF4D97',
    'POPULAR',
    3
  ),
  
  -- Premium Monthly (like Bumble Premium)
  (
    'premium_monthly',
    'FaceTune Premium',
    'All looks, HD export, and exclusive features',
    599,
    'month',
    -1,
    '["softGlam", "emo", "dollKBeauty", "bronzedGoddess", "boldEditorial"]'::jsonb,
    true,
    true,
    true,
    '#9C27B0',
    null,
    4
  ),
  
  -- Premium Yearly (like Bumble Premium yearly with discount)
  (
    'premium_yearly',
    'FaceTune Premium',
    'All looks, HD export, and exclusive features - Save 50%!',
    3599,
    'year',
    -1,
    '["softGlam", "emo", "dollKBeauty", "bronzedGoddess", "boldEditorial"]'::jsonb,
    true,
    true,
    true,
    '#9C27B0',
    'BEST VALUE',
    5
  ),
  
  -- Lifetime Premium (like Bumble's lifetime option)
  (
    'lifetime_premium',
    'FaceTune Lifetime',
    'One-time payment for lifetime premium access',
    9999,
    'lifetime',
    -1,
    '["softGlam", "emo", "dollKBeauty", "bronzedGoddess", "boldEditorial"]'::jsonb,
    true,
    true,
    true,
    '#FFD700',
    'BEST DEAL',
    6
  )
ON CONFLICT (name) DO NOTHING;

-- Create function to get user's active subscription features
CREATE OR REPLACE FUNCTION public.get_user_features(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_features jsonb;
  v_subscription record;
BEGIN
  -- Get the user's highest tier active subscription
  SELECT sp.* INTO v_subscription
  FROM public.user_subscriptions us
  JOIN public.subscription_plans sp ON us.plan_id = sp.id
  WHERE us.user_id = p_user_id
    AND us.status = 'active'
    AND (us.current_period_end IS NULL OR us.current_period_end > now())
  ORDER BY sp.price DESC, sp.sort_order DESC
  LIMIT 1;
  
  IF v_subscription IS NULL THEN
    -- Return free tier features if no active subscription
    SELECT row_to_json(sp)::jsonb INTO v_features
    FROM public.subscription_plans sp
    WHERE sp.name = 'free'
    LIMIT 1;
  ELSE
    v_features := row_to_json(v_subscription)::jsonb;
  END IF;
  
  RETURN v_features;
END;
$$;

-- Create function to check if user can perform action (like Bumble's feature gates)
CREATE OR REPLACE FUNCTION public.can_user_scan(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_features jsonb;
  v_daily_limit integer;
  v_usage record;
BEGIN
  -- Get user features
  v_features := public.get_user_features(p_user_id);
  v_daily_limit := (v_features->>'daily_scan_limit')::integer;
  
  -- If unlimited (-1), return true
  IF v_daily_limit = -1 THEN
    RETURN true;
  END IF;
  
  -- Get today's usage
  SELECT * INTO v_usage
  FROM public.usage_tracking
  WHERE user_id = p_user_id AND tracking_date = CURRENT_DATE;
  
  -- If no usage record, user can scan
  IF v_usage IS NULL THEN
    RETURN true;
  END IF;
  
  -- Check if under daily limit
  RETURN v_usage.scans_today < v_daily_limit;
END;
$$;

-- Create function to increment scan count
CREATE OR REPLACE FUNCTION public.increment_scan_count(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.usage_tracking (user_id, tracking_date, scans_today)
  VALUES (p_user_id, CURRENT_DATE, 1)
  ON CONFLICT (user_id, tracking_date)
  DO UPDATE SET 
    scans_today = public.usage_tracking.scans_today + 1,
    updated_at = now();
    
  -- Also update subscription scan count
  UPDATE public.user_subscriptions
  SET 
    scans_used_today = scans_used_today + 1,
    scans_used_total = scans_used_total + 1,
    last_scan_date = CURRENT_DATE
  WHERE user_id = p_user_id 
    AND status = 'active'
    AND (current_period_end IS NULL OR current_period_end > now());
END;
$$;

-- Create function to auto-create free subscription for new users
CREATE OR REPLACE FUNCTION public.handle_new_user_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_free_plan_id uuid;
BEGIN
  -- Get free plan ID
  SELECT id INTO v_free_plan_id
  FROM public.subscription_plans
  WHERE name = 'free'
  LIMIT 1;
  
  -- Create account
  INSERT INTO public.accounts (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'user'
  );
  
  -- Create free subscription
  IF v_free_plan_id IS NOT NULL THEN
    INSERT INTO public.user_subscriptions (
      user_id, 
      plan_id, 
      status, 
      current_period_end,
      payment_method
    )
    VALUES (
      NEW.id,
      v_free_plan_id,
      'active',
      NOW() + INTERVAL '100 years',
      'free'
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Replace the old trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user_subscription();

-- Create function to auto-expire subscriptions
CREATE OR REPLACE FUNCTION public.expire_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.user_subscriptions
  SET status = 'expired'
  WHERE status = 'active'
    AND current_period_end IS NOT NULL
    AND current_period_end < now();
END;
$$;

-- Reset daily usage counters at midnight
CREATE OR REPLACE FUNCTION public.reset_daily_limits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.user_subscriptions
  SET scans_used_today = 0
  WHERE last_scan_date < CURRENT_DATE;
END;
$$;

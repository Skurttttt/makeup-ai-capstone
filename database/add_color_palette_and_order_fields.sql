-- Migration: Add product colors table and order/variant fields

-- 1) Product color palette (for variant naming/hex mapping)
CREATE TABLE IF NOT EXISTS public.product_colors (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  hex text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.product_colors ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_colors_name
  ON public.product_colors (lower(name));

CREATE INDEX IF NOT EXISTS idx_product_colors_active
  ON public.product_colors (is_active);

CREATE POLICY "Anyone can view active product colors"
  ON public.product_colors
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Authenticated users can insert product colors"
  ON public.product_colors
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Updated_at trigger reuse
DROP TRIGGER IF EXISTS trg_set_updated_at_product_colors ON public.product_colors;
CREATE TRIGGER trg_set_updated_at_product_colors
BEFORE UPDATE ON public.product_colors
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Seed starter palette (extend with your full shade list)
INSERT INTO public.product_colors (name, hex)
VALUES
  ('Black', '#000000'),
  ('White', '#FFFFFF'),
  ('Red', '#E53935'),
  ('Pink', '#EC4899'),
  ('Rose', '#F43F5E'),
  ('Coral', '#FF6F61'),
  ('Peach', '#FFB085'),
  ('Nude', '#D2A48C'),
  ('Beige', '#E8DCCB'),
  ('Sand', '#D8C3A5'),
  ('Almond', '#C8A27A'),
  ('Caramel', '#B87333'),
  ('Taupe', '#8B7D6B'),
  ('Brown', '#8D6E63'),
  ('Cocoa', '#7B4B2A'),
  ('Chestnut', '#6B3F2A'),
  ('Mocha', '#6D4C41'),
  ('Burgundy', '#7B1E3A'),
  ('Wine', '#722F37'),
  ('Plum', '#7C3AED'),
  ('Mauve', '#C08497'),
  ('Lavender', '#B57EDC'),
  ('Lilac', '#C8A2C8'),
  ('Purple', '#8E24AA'),
  ('Blue', '#1E88E5'),
  ('Matcha', '#9FCB7C'),
  ('Green', '#10B981'),
  ('Yellow', '#F59E0B'),
  ('Orange', '#F97316'),
  ('Terracotta', '#E2725B'),
  ('Bronze', '#CD7F32'),
  ('Copper', '#B87333'),
  ('Gold', '#D4AF37'),
  ('Silver', '#C0C0C0'),
  ('Gray', '#94A3B8')
ON CONFLICT (lower(name)) DO NOTHING;

-- 2) Add buyer/shipping fields to orders (to match checkout UI)
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS buyer_name text,
  ADD COLUMN IF NOT EXISTS buyer_email text,
  ADD COLUMN IF NOT EXISTS buyer_phone text,
  ADD COLUMN IF NOT EXISTS shipping_address text,
  ADD COLUMN IF NOT EXISTS shipping_city text,
  ADD COLUMN IF NOT EXISTS shipping_postal_code text,
  ADD COLUMN IF NOT EXISTS payment_method text;

-- 3) Add variant info to order_items (to show selected variant)
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS variation_name text,
  ADD COLUMN IF NOT EXISTS variation_hex text;

-- Migration: Create Products table for business accounts

-- Create products table
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    price numeric(10,2) NOT NULL DEFAULT 0.00,
    currency text DEFAULT 'PHP',
    image_url text,
    stock_quantity integer NOT NULL DEFAULT 0,
    category text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Add updated_at trigger for products table
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_updated_at_products ON public.products;
CREATE TRIGGER trg_set_updated_at_products
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Product Policies

-- 1. Anyone (public or authenticated) can view active products
CREATE POLICY "Public can view active products"
ON public.products FOR SELECT
USING (is_active = true);

-- 2. Business owners can view all their own products (even inactive ones)
CREATE POLICY "Business owners can view their own products"
ON public.products FOR SELECT
USING (auth.uid() = business_id);

-- 3. Business owners can insert their own products
CREATE POLICY "Business owners can insert their own products"
ON public.products FOR INSERT
WITH CHECK (auth.uid() = business_id);

-- 4. Business owners can update their own products
CREATE POLICY "Business owners can update their own products"
ON public.products FOR UPDATE
USING (auth.uid() = business_id)
WITH CHECK (auth.uid() = business_id);

-- 5. Business owners can delete their own products
CREATE POLICY "Business owners can delete their own products"
ON public.products FOR DELETE
USING (auth.uid() = business_id);

-- Create index for faster querying by business
CREATE INDEX IF NOT EXISTS idx_products_business_id
ON public.products(business_id);

CREATE INDEX IF NOT EXISTS idx_products_is_active
ON public.products(is_active);

CREATE INDEX IF NOT EXISTS idx_products_category
ON public.products(category);

-- Comment documentation
COMMENT ON TABLE public.products IS 'Stores products created by business accounts/clients in the market';
COMMENT ON COLUMN public.products.id IS 'Unique identifier for the product';
COMMENT ON COLUMN public.products.business_id IS 'Reference to the business account (public.accounts.id) that owns the product';
COMMENT ON COLUMN public.products.name IS 'Name of the product';
COMMENT ON COLUMN public.products.price IS 'Price of the product';
COMMENT ON COLUMN public.products.stock_quantity IS 'Available stock for the product';
COMMENT ON COLUMN public.products.is_active IS 'Whether the product is currently visible and available in the market';

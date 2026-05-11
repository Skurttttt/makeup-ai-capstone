-- Migration: Product categories table for DB-driven category dropdowns

CREATE TABLE IF NOT EXISTS public.product_categories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    business_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE,
    name text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    is_global boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_product_categories_name_not_blank CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_categories_unique_global_name
ON public.product_categories(lower(name))
WHERE is_global = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_categories_unique_business_name
ON public.product_categories(business_id, lower(name))
WHERE business_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_product_categories_business_id
ON public.product_categories(business_id);

CREATE INDEX IF NOT EXISTS idx_product_categories_active_sort
ON public.product_categories(is_active, sort_order);

ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Business owners can view product categories" ON public.product_categories;
CREATE POLICY "Business owners can view product categories"
ON public.product_categories FOR SELECT
USING (
    is_global = true OR auth.uid() = business_id
);

DROP POLICY IF EXISTS "Business owners can insert product categories" ON public.product_categories;
CREATE POLICY "Business owners can insert product categories"
ON public.product_categories FOR INSERT
WITH CHECK (
    auth.uid() = business_id
);

DROP POLICY IF EXISTS "Business owners can update product categories" ON public.product_categories;
CREATE POLICY "Business owners can update product categories"
ON public.product_categories FOR UPDATE
USING (auth.uid() = business_id)
WITH CHECK (auth.uid() = business_id);

DROP POLICY IF EXISTS "Business owners can delete product categories" ON public.product_categories;
CREATE POLICY "Business owners can delete product categories"
ON public.product_categories FOR DELETE
USING (auth.uid() = business_id);

-- Seed global categories used by the product form
INSERT INTO public.product_categories (name, sort_order, is_active, is_global)
VALUES
    ('Blush', 1, true, true),
    ('Foundation', 2, true, true),
    ('Lipstick', 3, true, true),
    ('Eyeshadow', 4, true, true)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.product_categories IS 'Database-driven categories for product forms';
COMMENT ON COLUMN public.product_categories.business_id IS 'Owner business account id; NULL means global category';
COMMENT ON COLUMN public.product_categories.is_global IS 'True for shared categories visible to all businesses';

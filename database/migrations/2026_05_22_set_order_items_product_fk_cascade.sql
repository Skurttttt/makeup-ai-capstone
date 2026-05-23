-- Migration: change order_items.product_id FK to ON DELETE CASCADE
-- Run this in Supabase SQL editor or via psql against your database.

BEGIN;

ALTER TABLE IF EXISTS public.order_items
  DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

ALTER TABLE IF EXISTS public.order_items
  ADD CONSTRAINT order_items_product_id_fkey
  FOREIGN KEY (product_id) REFERENCES public.products(id)
  ON DELETE CASCADE
  ON UPDATE CASCADE;

COMMIT;

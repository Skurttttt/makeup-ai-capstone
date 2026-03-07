-- Migration: Add business fields to accounts table for makeup business support
-- This migration adds fields to support business/makeup brand registration and management

-- Add business-related columns to accounts table
ALTER TABLE public.accounts
ADD COLUMN IF NOT EXISTS account_type text DEFAULT 'individual' CHECK (account_type IN ('individual', 'business')),
ADD COLUMN IF NOT EXISTS client_type text DEFAULT 'individual' CHECK (client_type IN ('individual', 'business')),
ADD COLUMN IF NOT EXISTS business_name text,
ADD COLUMN IF NOT EXISTS business_type text CHECK (business_type IN ('makeup_brand', 'salon', 'artist', 'distributor', 'retailer', 'other')),
ADD COLUMN IF NOT EXISTS business_phone text,
ADD COLUMN IF NOT EXISTS business_address text,
ADD COLUMN IF NOT EXISTS business_description text,
ADD COLUMN IF NOT EXISTS business_reg_number text,
ADD COLUMN IF NOT EXISTS business_logo_url text,
ADD COLUMN IF NOT EXISTS business_verified boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS business_verified_at timestamp with time zone;

-- Create index on business_type for queries
CREATE INDEX IF NOT EXISTS idx_accounts_business_type 
ON public.accounts(business_type) 
WHERE account_type = 'business';

-- Create index on account_type for role-based queries
CREATE INDEX IF NOT EXISTS idx_accounts_account_type 
ON public.accounts(account_type);

-- Add comment documenting the new fields
COMMENT ON COLUMN public.accounts.account_type IS 'Type of account: individual user or business';
COMMENT ON COLUMN public.accounts.client_type IS 'Client type for login: individual or business';
COMMENT ON COLUMN public.accounts.business_name IS 'Name of the makeup business';
COMMENT ON COLUMN public.accounts.business_type IS 'Type of business: makeup_brand, salon, artist, distributor, retailer, or other';
COMMENT ON COLUMN public.accounts.business_phone IS 'Contact phone number for the business';
COMMENT ON COLUMN public.accounts.business_address IS 'Physical address of the business';
COMMENT ON COLUMN public.accounts.business_description IS 'Description of the business and its offerings';
COMMENT ON COLUMN public.accounts.business_reg_number IS 'Business registration or license number';
COMMENT ON COLUMN public.accounts.business_logo_url IS 'URL to the business logo image';
COMMENT ON COLUMN public.accounts.business_verified IS 'Whether the business has been verified by admin';
COMMENT ON COLUMN public.accounts.business_verified_at IS 'Timestamp when business was verified';

-- Backfill missing type values and keep both columns consistent
UPDATE public.accounts
SET
	account_type = COALESCE(account_type, client_type, 'individual'),
	client_type = COALESCE(client_type, account_type, 'individual')
WHERE account_type IS NULL OR client_type IS NULL OR account_type <> client_type;

-- Enforce synchronization between account_type and client_type for future writes
CREATE OR REPLACE FUNCTION public.sync_account_client_type()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
	IF NEW.account_type IS NULL AND NEW.client_type IS NULL THEN
		NEW.account_type := 'individual';
		NEW.client_type := 'individual';
	ELSIF NEW.account_type IS NULL THEN
		NEW.account_type := NEW.client_type;
	ELSIF NEW.client_type IS NULL THEN
		NEW.client_type := NEW.account_type;
	ELSIF NEW.account_type <> NEW.client_type THEN
		NEW.client_type := NEW.account_type;
	END IF;

	RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_account_client_type ON public.accounts;
CREATE TRIGGER trg_sync_account_client_type
BEFORE INSERT OR UPDATE ON public.accounts
FOR EACH ROW
EXECUTE FUNCTION public.sync_account_client_type();

-- Drop the unique constraint from place_id so we can store multiple emails for the same place
ALTER TABLE public.marketing_leads DROP CONSTRAINT IF EXISTS marketing_leads_place_id_key;

-- Add a unique constraint on email to prevent sending duplicate emails to the same address
ALTER TABLE public.marketing_leads ADD CONSTRAINT marketing_leads_email_key UNIQUE (email);

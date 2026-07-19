-- Add is_unsubscribed column to marketing_leads table to handle opt-outs
ALTER TABLE public.marketing_leads 
ADD COLUMN IF NOT EXISTS is_unsubscribed BOOLEAN DEFAULT FALSE;

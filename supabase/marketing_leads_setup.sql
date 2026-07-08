-- Create marketing_leads table
CREATE TABLE IF NOT EXISTS public.marketing_leads (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    place_id TEXT UNIQUE, -- Google Maps Place ID to prevent duplicates
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    website TEXT,
    city TEXT,
    address TEXT,
    is_emailed BOOLEAN DEFAULT FALSE,
    emailed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.marketing_leads ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Enable all access for service role on marketing_leads" ON public.marketing_leads
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Allow authenticated admins to view/manage leads (assuming an admin role or just disable for public)
CREATE POLICY "Enable read access for authenticated admins on marketing_leads" ON public.marketing_leads
    FOR SELECT
    TO authenticated
    USING (true);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_marketing_leads_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to call the function
CREATE TRIGGER update_marketing_leads_updated_at
    BEFORE UPDATE ON public.marketing_leads
    FOR EACH ROW
    EXECUTE FUNCTION update_marketing_leads_updated_at_column();

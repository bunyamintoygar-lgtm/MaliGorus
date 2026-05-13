-- İlan Başvuruları Tablosu Oluşturma
CREATE TABLE IF NOT EXISTS public.listing_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  applicant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(listing_id, applicant_id) -- Bir kullanıcı bir ilana sadece bir kez başvurabilir
);

-- RLS Güvenlik Kurallarını Aktifleştir
ALTER TABLE public.listing_applications ENABLE ROW LEVEL SECURITY;

-- Politikalar
-- 1. Herkes kendi başvurusunu oluşturabilir
CREATE POLICY "Users can apply to listings" ON public.listing_applications
  FOR INSERT WITH CHECK (auth.uid() = applicant_id);

-- 2. Kullanıcılar kendi başvurularını görebilir
CREATE POLICY "Users can see their own applications" ON public.listing_applications
  FOR SELECT USING (auth.uid() = applicant_id);

-- 3. İlan sahibi kendi ilanına gelen başvuruları görebilir
CREATE POLICY "Authors can see applications to their listings" ON public.listing_applications
  FOR SELECT USING (
    auth.uid() IN (
      SELECT author_id FROM public.listings WHERE id = listing_id
    )
  );

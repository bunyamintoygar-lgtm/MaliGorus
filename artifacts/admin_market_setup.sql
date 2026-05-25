-- =========================================================================
-- MaliGörüş Admin Market Güncelleme SQL Scripti
-- =========================================================================
-- Bu dosyayı kopyalayıp Supabase -> SQL Editor alanında "Run" diyerek çalıştırın.

-- 1. market_purchases tablosuna status kolonu ekleme
ALTER TABLE public.market_purchases 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';

-- 2. market_purchases tablosuna admin RLS politikaları
DROP POLICY IF EXISTS "Allow admin all access to market_purchases" ON public.market_purchases;
CREATE POLICY "Allow admin all access to market_purchases" 
ON public.market_purchases 
FOR ALL 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  )
);

-- 3. market_products tablosuna admin RLS politikaları
DROP POLICY IF EXISTS "Allow admin all access to market_products" ON public.market_products;
CREATE POLICY "Allow admin all access to market_products" 
ON public.market_products 
FOR ALL 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  )
);

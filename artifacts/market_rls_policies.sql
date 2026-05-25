-- =========================================================================
-- MaliGörüş Market Tabloları RLS (Satır Seviyesi Güvenlik) Politikaları
-- =========================================================================
-- Lütfen bu dosyadaki TÜM satırları kopyalayıp Supabase SQL Editör'e yapıştırın.
-- KODUN TAMAMINI seçtiğinizden emin olun (hiçbir satırı seçili bırakmadan Run butonuna basın).

-- 1. market_products Tablosu RLS & Politikaları
ALTER TABLE public.market_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to market_products" ON public.market_products;
CREATE POLICY "Allow public read access to market_products" ON public.market_products FOR SELECT TO public USING (true);

-- 2. market_cart Tablosu RLS & Politikaları
ALTER TABLE public.market_cart ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow users to view their own cart" ON public.market_cart;
DROP POLICY IF EXISTS "Allow users to insert into their own cart" ON public.market_cart;
DROP POLICY IF EXISTS "Allow users to update their own cart" ON public.market_cart;
DROP POLICY IF EXISTS "Allow users to delete from their own cart" ON public.market_cart;

CREATE POLICY "Allow users to view their own cart" ON public.market_cart FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert into their own cart" ON public.market_cart FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own cart" ON public.market_cart FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete from their own cart" ON public.market_cart FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 3. market_purchases Tablosu RLS & Politikaları
ALTER TABLE public.market_purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow users to view their own purchases" ON public.market_purchases;
DROP POLICY IF EXISTS "Allow users to insert their own purchases" ON public.market_purchases;

CREATE POLICY "Allow users to view their own purchases" ON public.market_purchases FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own purchases" ON public.market_purchases FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

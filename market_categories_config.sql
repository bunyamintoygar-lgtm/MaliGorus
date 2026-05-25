-- Supabase SQL Editor'de çalıştırın
-- Market kategorilerini app_config tablosuna ekler

INSERT INTO public.app_config (key, value)
VALUES (
  'market_categories',
  '["Şablonlar", "Dokümanlar", "Paketler", "Araçlar", "Eğitimler", "Diğer"]'::jsonb
)
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value,
      updated_at = now();

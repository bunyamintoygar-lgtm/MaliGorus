-- =============================================
-- REFERANS SİSTEMİ - PARMAK İZİ TAKİBİ (FINGERPRINTING)
-- =============================================

CREATE TABLE IF NOT EXISTS referral_clicks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ref_code VARCHAR(20) NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  screen_res VARCHAR(50),
  pixel_ratio FLOAT,
  timezone TEXT,
  platform TEXT,
  language TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Ayarları
ALTER TABLE referral_clicks ENABLE ROW LEVEL SECURITY;

-- Herkesin ekleme yapabilmesi için politika (Anonim erişim)
CREATE POLICY "Anyone can insert referral clicks"
  ON referral_clicks FOR INSERT
  WITH CHECK (true);

-- Sadece sistem/admin okuyabilir (veya uygulama tarafı IP ile sorgulayabilir)
CREATE POLICY "Only authenticated or specific matching can select"
  ON referral_clicks FOR SELECT
  USING (auth.role() = 'service_role');

-- İsteğe bağlı: Uygulamanın kendi eşleşmesini bulması için fonksiyon
CREATE OR REPLACE FUNCTION match_referral_click(
  p_ip TEXT,
  p_ua TEXT,
  p_screen TEXT
)
RETURNS TABLE (ref_code VARCHAR) AS $$
BEGIN
  RETURN QUERY
  SELECT rc.ref_code
  FROM referral_clicks rc
  WHERE rc.ip_address = p_ip
    AND rc.user_agent = p_ua
    AND rc.screen_res = p_screen
    AND rc.created_at > NOW() - INTERVAL '2 hours'
  ORDER BY rc.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

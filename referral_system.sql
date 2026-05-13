-- =============================================
-- REFERANS SİSTEMİ - VERİTABANI ŞEMASI
-- =============================================

-- 1. profiles tablosuna referral_code sütunu ekle
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code VARCHAR(20) UNIQUE;

-- 2. Mevcut kullanıcılara referans kodu ata
UPDATE profiles 
SET referral_code = 'MG-' || SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 8)
WHERE referral_code IS NULL;

-- 3. Yeni kullanıcılara otomatik referans kodu ata
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := 'MG-' || SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 8);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_referral_code ON profiles;
CREATE TRIGGER trigger_generate_referral_code
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION generate_referral_code();

-- =============================================
-- USER_REVIEWS TABLOSU
-- =============================================

CREATE TABLE IF NOT EXISTS user_reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  review_text TEXT NOT NULL,
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id) -- Her kullanıcı sadece 1 yorum yapabilir
);

-- RLS
ALTER TABLE user_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all reviews"
  ON user_reviews FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own review"
  ON user_reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own review"
  ON user_reviews FOR UPDATE
  USING (auth.uid() = user_id);

-- =============================================
-- REFERRALS TABLOSU
-- =============================================

CREATE TABLE IF NOT EXISTS referrals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  referrer_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  referral_code VARCHAR(20) NOT NULL,
  candidate_name VARCHAR(255) NOT NULL,
  candidate_profession VARCHAR(100),
  candidate_email VARCHAR(255),
  candidate_phone VARCHAR(50),
  source VARCHAR(20) NOT NULL DEFAULT 'manual', -- 'manual' | 'link'
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending' | 'registered' | 'active'
  email_sent BOOLEAN DEFAULT FALSE,
  credit_granted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- Referrer kendi referanslarını görebilir
CREATE POLICY "Users can view own referrals"
  ON referrals FOR SELECT
  USING (auth.uid() = referrer_id);

-- Giriş yapmış kullanıcılar referans ekleyebilir
CREATE POLICY "Authenticated users can insert referrals"
  ON referrals FOR INSERT
  WITH CHECK (auth.uid() = referrer_id);

-- Anonim kullanıcılar da (landing page'den) referans ekleyebilir
-- Bu politikayı landing page için anon erişime ihtiyacımız olduğunda aktifleştiririz
CREATE POLICY "Anon users can insert referrals via link"
  ON referrals FOR INSERT
  WITH CHECK (source = 'link');

-- =============================================
-- RPC: Landing page'den aday kaydı (auth gerekmez)
-- =============================================

CREATE OR REPLACE FUNCTION register_referral_candidate(
  p_referral_code VARCHAR,
  p_candidate_name VARCHAR,
  p_candidate_profession VARCHAR,
  p_candidate_email VARCHAR
)
RETURNS JSON AS $$
DECLARE
  v_referrer_id UUID;
  v_referral_id UUID;
BEGIN
  -- Referans kodunu doğrula
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = p_referral_code;

  IF v_referrer_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Geçersiz referans kodu');
  END IF;

  -- Aynı email ile daha önce kayıt var mı kontrol et
  IF EXISTS (
    SELECT 1 FROM referrals 
    WHERE candidate_email = p_candidate_email 
    AND referral_code = p_referral_code
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Bu e-posta adresi ile daha önce kayıt yapılmış');
  END IF;

  -- Referans kaydı oluştur
  INSERT INTO referrals (referrer_id, referral_code, candidate_name, candidate_profession, candidate_email, source)
  VALUES (v_referrer_id, p_referral_code, p_candidate_name, p_candidate_profession, p_candidate_email, 'link')
  RETURNING id INTO v_referral_id;

  RETURN json_build_object(
    'success', true, 
    'referral_id', v_referral_id,
    'referrer_id', v_referrer_id,
    'message', 'Kayıt başarılı'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- RPC: Referans linki ile profil bilgisini getir (auth gerekmez)
-- =============================================

CREATE OR REPLACE FUNCTION get_referral_profile(p_referral_code VARCHAR)
RETURNS JSON AS $$
DECLARE
  v_profile JSON;
  v_review JSON;
BEGIN
  -- Profil bilgisini al
  SELECT json_build_object(
    'id', p.id,
    'full_name', p.full_name,
    'profession', p.profession,
    'avatar_url', p.avatar_url,
    'company_name', p.company_name
  ) INTO v_profile
  FROM profiles p
  WHERE p.referral_code = p_referral_code;

  IF v_profile IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Kullanıcı bulunamadı');
  END IF;

  -- Kullanıcının yorumunu al
  SELECT json_build_object(
    'review_text', r.review_text,
    'rating', r.rating
  ) INTO v_review
  FROM user_reviews r
  JOIN profiles p ON r.user_id = p.id
  WHERE p.referral_code = p_referral_code;

  RETURN json_build_object(
    'success', true,
    'profile', v_profile,
    'review', COALESCE(v_review, null)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- app_config credit_prices güncelleme
-- =============================================

-- Mevcut credit_prices'a yeni key'leri ekleyin:
-- UPDATE app_config 
-- SET value = value || '{"app_review": 5, "friend_referral": 2, "link_referral": 20}'::jsonb
-- WHERE key = 'credit_prices';

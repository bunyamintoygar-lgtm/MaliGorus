-- =============================================
-- REFERANS ÖDÜL SİSTEMİ (ÇİFT TARAFLI)
-- =============================================

-- Bu fonksiyon bir kullanıcı profilini tamamladığında çağrılmalıdır.
CREATE OR REPLACE FUNCTION complete_referral_reward(
  p_new_user_id UUID,
  p_ref_code VARCHAR
)
RETURNS JSON AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  -- 1. Referans kodunun sahibini bul
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = p_ref_code;

  IF v_referrer_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Geçersiz referans kodu');
  END IF;

  -- 2. Referans Verene 20 Kredi Ekle
  UPDATE profiles 
  SET credits = COALESCE(credits, 0) + 20 
  WHERE id = v_referrer_id;

  -- 3. Yeni Üyeye 20 Kredi Ekle (Normal 50 kredisine ek olarak)
  UPDATE profiles 
  SET credits = COALESCE(credits, 0) + 20 
  WHERE id = p_new_user_id;

  -- 4. İşlemi referrals tablosuna kaydet (takip için)
  INSERT INTO referrals (referrer_id, referral_code, candidate_name, status, credit_granted, source)
  VALUES (
    v_referrer_id, 
    p_ref_code, 
    (SELECT full_name FROM profiles WHERE id = p_new_user_id), 
    'active', 
    true, 
    'link'
  );

  RETURN json_build_object('success', true, 'message', 'Ödüller başarıyla tanımlandı');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

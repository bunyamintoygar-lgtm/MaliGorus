-- =============================================
-- Anket Oylama RPC Fonksiyonu
-- =============================================
-- Bu fonksiyon atomik olarak:
-- 1. survey_votes tablosuna oy kaydı ekler
-- 2. surveys tablosundaki ilgili seçeneğin oy sayısını artırır
-- 3. Mükerrer oy engellenir (unique constraint)

CREATE OR REPLACE FUNCTION vote_survey(
  p_survey_id UUID,
  p_option_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
  v_options JSONB;
  v_new_options JSONB;
  v_option JSONB;
  v_index INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 1. Oy kaydını ekle (mükerrer oy unique constraint ile engellenir)
  INSERT INTO survey_votes (survey_id, user_id, option_id)
  VALUES (p_survey_id, v_user_id, p_option_id);

  -- 2. Mevcut options JSON'unu al
  SELECT options INTO v_options
  FROM surveys
  WHERE id = p_survey_id;

  -- 3. İlgili seçeneğin votes değerini artır
  v_new_options := '[]'::JSONB;
  FOR v_index IN 0 .. jsonb_array_length(v_options) - 1 LOOP
    v_option := v_options -> v_index;
    IF v_option ->> 'id' = p_option_id THEN
      v_option := jsonb_set(v_option, '{votes}', to_jsonb(COALESCE((v_option ->> 'votes')::INT, 0) + 1));
    END IF;
    v_new_options := v_new_options || jsonb_build_array(v_option);
  END LOOP;

  -- 4. Güncelle
  UPDATE surveys
  SET options = v_new_options
  WHERE id = p_survey_id;

  RETURN TRUE;

EXCEPTION
  WHEN unique_violation THEN
    RETURN FALSE; -- Zaten oy kullanmış
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

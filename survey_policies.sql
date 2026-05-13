-- =============================================
-- Survey Tabloları RLS Politikaları
-- =============================================

-- 1. survey_votes tablosu: Kullanıcılar oy verebilsin
ALTER TABLE survey_votes ENABLE ROW LEVEL SECURITY;

-- Herkes kendi oyunu ekleyebilir
CREATE POLICY "Users can insert their own votes"
ON survey_votes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Herkes kendi oylarını görebilir
CREATE POLICY "Users can view their own votes"
ON survey_votes FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 2. surveys tablosu: Herkes okuyabilsin, sahibi güncelleyebilsin
ALTER TABLE surveys ENABLE ROW LEVEL SECURITY;

-- Herkes aktif anketleri görebilir
CREATE POLICY "Anyone can view active surveys"
ON surveys FOR SELECT
TO authenticated
USING (true);

-- Sadece sahibi güncelleyebilir
CREATE POLICY "Authors can update their surveys"
ON surveys FOR UPDATE
TO authenticated
USING (auth.uid() = author_id);

-- Giriş yapmış kullanıcılar anket oluşturabilir
CREATE POLICY "Authenticated users can create surveys"
ON surveys FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = author_id);

-- Sadece sahibi silebilir
CREATE POLICY "Authors can delete their surveys"
ON surveys FOR DELETE
TO authenticated
USING (auth.uid() = author_id);

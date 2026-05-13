-- =============================================
-- Tartışma Beğeni Alt Yapısı
-- =============================================

-- 1. Beğeni Tablosunu Oluştur
CREATE TABLE IF NOT EXISTS public.discussion_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discussion_id UUID REFERENCES public.discussions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(discussion_id, user_id)
);

-- 2. Discussions Tablosuna Beğeni Sayısı Sütunu Ekle (Eğer yoksa)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='discussions' AND column_name='like_count') THEN
        ALTER TABLE public.discussions ADD COLUMN like_count INT DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='discussions' AND column_name='view_count') THEN
        ALTER TABLE public.discussions ADD COLUMN view_count INT DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='discussion_replies' AND column_name='like_count') THEN
        ALTER TABLE public.discussion_replies ADD COLUMN like_count INT DEFAULT 0;
    END IF;
END $$;

-- 3. Yanıt Beğeni Tablosu
CREATE TABLE IF NOT EXISTS public.reply_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reply_id UUID REFERENCES public.discussion_replies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(reply_id, user_id)
);

-- 4. Atomik Beğeni RPC Fonksiyonları
CREATE OR REPLACE FUNCTION toggle_discussion_like(
    p_discussion_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Beğeni var mı kontrol et
    SELECT EXISTS (
        SELECT 1 FROM discussion_likes 
        WHERE discussion_id = p_discussion_id AND user_id = p_user_id
    ) INTO v_exists;

    IF v_exists THEN
        -- Beğeniyi kaldır
        DELETE FROM discussion_likes 
        WHERE discussion_id = p_discussion_id AND user_id = p_user_id;
        
        -- Sayacı azalt
        UPDATE discussions 
        SET like_count = GREATEST(0, like_count - 1)
        WHERE id = p_discussion_id;
        
        RETURN FALSE;
    ELSE
        -- Beğeni ekle
        INSERT INTO discussion_likes (discussion_id, user_id)
        VALUES (p_discussion_id, p_user_id);
        
        -- Sayacı artır
        UPDATE discussions 
        SET like_count = like_count + 1
        WHERE id = p_discussion_id;
        
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RLS Politikaları
ALTER TABLE public.discussion_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Beğeniler herkes tarafından görülebilir" 
ON public.discussion_likes FOR SELECT 
USING (true);

CREATE POLICY "Kullanıcılar sadece kendi beğenilerini yönetebilir" 
ON public.discussion_likes FOR ALL 
USING (auth.uid() = user_id);

-- 6. Yanıt Beğeni RPC
CREATE OR REPLACE FUNCTION toggle_reply_like(
    p_reply_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM reply_likes 
        WHERE reply_id = p_reply_id AND user_id = p_user_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM reply_likes 
        WHERE reply_id = p_reply_id AND user_id = p_user_id;
        
        UPDATE discussion_replies 
        SET like_count = GREATEST(0, like_count - 1)
        WHERE id = p_reply_id;
        
        RETURN FALSE;
    ELSE
        INSERT INTO reply_likes (reply_id, user_id)
        VALUES (p_reply_id, p_user_id);
        
        UPDATE discussion_replies 
        SET like_count = like_count + 1
        WHERE id = p_reply_id;
        
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Yanıt Beğeni RLS
ALTER TABLE public.reply_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Beğeniler herkes tarafından görülebilir" 
ON public.reply_likes FOR SELECT 
USING (true);

CREATE POLICY "Kullanıcılar sadece kendi beğenilerini yönetebilir" 
ON public.reply_likes FOR ALL 
USING (auth.uid() = user_id);

-- 8. Discussion zlenme SaySN ArtR
CREATE OR REPLACE FUNCTION increment_discussion_view_count(p_discussion_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE discussions
    SET view_count = view_count + 1
    WHERE id = p_discussion_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

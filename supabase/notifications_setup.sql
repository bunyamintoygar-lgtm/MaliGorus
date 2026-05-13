-- 1. FCM TOKENS TABLOSU
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT, -- 'android', 'ios', 'web'
    created_at TIMESTAMPTZ DEFAULT now(),
    last_seen TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, token)
);

-- RLS Ayarları
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own tokens" ON public.fcm_tokens;
CREATE POLICY "Users can insert their own tokens" ON public.fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own tokens" ON public.fcm_tokens;
CREATE POLICY "Users can view their own tokens" ON public.fcm_tokens
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own tokens" ON public.fcm_tokens;
CREATE POLICY "Users can delete their own tokens" ON public.fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own tokens" ON public.fcm_tokens;
CREATE POLICY "Users can update their own tokens" ON public.fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id);


-- 2. BİLDİRİM GÖNDERME FONKSİYONU (Edge Function Çağrısı)
-- Önce TÜM eski versiyonları temizle (Parametre fark etmeksizin hepsini siler)
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT oid::regprocedure as proc_name 
              FROM pg_proc 
              WHERE proname = 'send_push_notification' 
              AND pronamespace = 'public'::regnamespace) 
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.proc_name || ' CASCADE';
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.send_push_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb
) RETURNS VOID AS $$
DECLARE
    v_token_count INT;
BEGIN
    -- Kullanıcının token'ı var mı kontrol et
    SELECT count(*) INTO v_token_count FROM public.fcm_tokens WHERE user_id = p_user_id;
    
    IF v_token_count > 0 THEN
        INSERT INTO public.notifications_queue (user_id, title, body, data)
        VALUES (p_user_id, p_title, p_body, p_data);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. BİLDİRİM KUYRUĞU TABLOSU
CREATE TABLE IF NOT EXISTS public.notifications_queue (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'failed'
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TETİKLEYİCİLER (TRIGGERS)

-- A. Yeni Mesaj Bildirimi
CREATE OR REPLACE FUNCTION public.on_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_push_enabled BOOLEAN;
    v_notify_messages BOOLEAN;
    v_is_blocked BOOLEAN;
    v_is_muted BOOLEAN;
BEGIN
    -- 1. Gönderen adını ve alıcının bildirim tercihlerini al
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    SELECT push_enabled, notify_messages 
    INTO v_push_enabled, v_notify_messages 
    FROM public.profiles WHERE id = NEW.receiver_id;
    
    -- 2. Engelleme kontrolü (Alıcı göndereni engellemiş mi?)
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users 
        WHERE blocker_id = NEW.receiver_id AND blocked_id = NEW.sender_id
    ) INTO v_is_blocked;

    -- 3. Sessize alma kontrolü (Alıcı göndereni sessize almış mı?)
    SELECT EXISTS (
        SELECT 1 FROM public.muted_users 
        WHERE user_id = NEW.receiver_id AND muted_user_id = NEW.sender_id
    ) INTO v_is_muted;

    -- Bildirim gönderimi: 
    -- Global bildirimler açıksa VE mesaj bildirimleri açıksa VE engellenmemişse VE sessize alınmamışsa
    IF v_push_enabled AND v_notify_messages AND NOT v_is_blocked AND NOT v_is_muted THEN
        PERFORM public.send_push_notification(
            NEW.receiver_id,
            v_sender_name || ' yeni bir mesaj gönderdi',
            NEW.body,
            jsonb_build_object('type', 'chat', 'sender_id', NEW.sender_id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.on_new_message_push();

-- B. Yeni Tartışma Bildirimi (Broadcast veya Adminlere)
CREATE OR REPLACE FUNCTION public.on_new_discussion_push()
RETURNS TRIGGER AS $$
BEGIN
    -- Kullanıcı ayarlarını (global ve kategori bazlı) kontrol ederek gönderiyoruz
    INSERT INTO public.notifications_queue (user_id, title, body, data)
    SELECT id, 
           CASE WHEN NEW.type = 'danisma' THEN 'Yeni Danışma Talebi' ELSE 'Yeni Tartışma' END,
           NEW.title,
           jsonb_build_object('type', 'discussion', 'id', NEW.id, 'discussion_type', NEW.type)
    FROM public.profiles 
    WHERE push_enabled = true -- Global kontrol
      AND (
        (NEW.type = 'tartisma' AND notify_discussions = true)
        OR (NEW.type = 'danisma' AND notify_consultations = true AND role = 'admin')
      );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_new_discussion_push ON public.discussions;
CREATE TRIGGER tr_new_discussion_push
    AFTER INSERT ON public.discussions
    FOR EACH ROW EXECUTE FUNCTION public.on_new_discussion_push();

-- C. Tartışmaya Yanıt Bildirimi
CREATE OR REPLACE FUNCTION public.on_new_reply_push()
RETURNS TRIGGER AS $$
DECLARE
    v_discussion_author_id UUID;
    v_replier_name TEXT;
    v_push_enabled BOOLEAN;
    v_notify_discussions BOOLEAN;
BEGIN
    SELECT author_id INTO v_discussion_author_id FROM public.discussions WHERE id = NEW.discussion_id;
    SELECT full_name INTO v_replier_name FROM public.profiles WHERE id = NEW.author_id;
    SELECT push_enabled, notify_discussions 
    INTO v_push_enabled, v_notify_discussions 
    FROM public.profiles WHERE id = v_discussion_author_id;

    -- Global bildirimler açıksa VE Kendi yanıtına bildirim gönderme VE yazarın bildirim ayarı açıksa gönder
    IF v_push_enabled AND v_discussion_author_id != NEW.author_id AND v_notify_discussions THEN
        PERFORM public.send_push_notification(
            v_discussion_author_id,
            'Tartışmanıza yeni yanıt',
            v_replier_name || ': ' || NEW.body,
            jsonb_build_object('type', 'reply', 'discussion_id', NEW.discussion_id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. Yeni Duyuru Bildirimi (Herkese)
CREATE OR REPLACE FUNCTION public.on_new_announcement_push()
RETURNS TRIGGER AS $$
DECLARE
    v_user_record RECORD;
BEGIN
    -- FCM Token'ı olan tüm kullanıcıları bul
    FOR v_user_record IN 
        SELECT DISTINCT t.user_id 
        FROM public.fcm_tokens t
        JOIN public.profiles p ON t.user_id = p.id
        WHERE p.push_enabled = true -- Global kontrol
    LOOP
        PERFORM public.send_push_notification(
            v_user_record.user_id,
            'Yeni Duyuru: ' || NEW.title,
            NEW.body,
            jsonb_build_object('type', 'announcement', 'id', NEW.id)
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_new_announcement_push ON public.announcements;
CREATE TRIGGER tr_new_announcement_push
    AFTER INSERT ON public.announcements
    FOR EACH ROW EXECUTE FUNCTION public.on_new_announcement_push();

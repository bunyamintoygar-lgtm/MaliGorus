-- Sohbet Temizleme Takibi (Sadece kendi ekranından silme için)
CREATE TABLE IF NOT EXISTS public.chat_clears (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    partner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    cleared_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE(user_id, partner_id)
);

-- RLS Aktifleştirme
ALTER TABLE public.chat_clears ENABLE ROW LEVEL SECURITY;

-- Politikalar
CREATE POLICY "Kullanıcılar kendi temizleme kayıtlarını görebilir"
ON public.chat_clears FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Kullanıcılar temizleme kaydı oluşturabilir/güncelleyebilir"
ON public.chat_clears FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

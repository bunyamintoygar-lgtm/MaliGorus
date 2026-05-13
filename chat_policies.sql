-- 1. Tüm eski politikaları temizle
DROP POLICY IF EXISTS "Enable read access for participants" ON "public"."messages";
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON "public"."messages";
DROP POLICY IF EXISTS "Enable delete for participants" ON "public"."messages";

-- 2. Okuma İzni: Sadece gönderen veya alıcı mesajı görebilir
CREATE POLICY "messages_select_policy" ON "public"."messages"
FOR SELECT TO authenticated
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- 3. Yazma İzni: Sadece kendi adına mesaj gönderebilir
CREATE POLICY "messages_insert_policy" ON "public"."messages"
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = sender_id);

-- 4. Silme İzni: Sadece taraflar silebilir
CREATE POLICY "messages_delete_policy" ON "public"."messages"
FOR DELETE TO authenticated
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
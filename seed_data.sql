-- 1. BAĞLI VERİLERİ TEMİZLE (Foreign Key hatalarını önlemek için)
-- Test kullanıcılarımızın ID'lerini kullanarak tüm ilişkili verileri siliyoruz.
DELETE FROM public.survey_votes WHERE user_id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
DELETE FROM public.surveys WHERE author_id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
DELETE FROM public.discussion_replies WHERE author_id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
DELETE FROM public.discussions WHERE author_id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
DELETE FROM public.listings WHERE author_id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
DELETE FROM public.profiles WHERE id IN ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');

-- 2. KULLANICILARI TEMİZLE
DELETE FROM auth.users WHERE email IN ('ahmet.ymm@example.com', 'merve.smmm@example.com', 'can.muhasebe@example.com');

-- 3. Gerekli eklentiyi aktif et
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 4. TEST KULLANICILARINI OLUŞTUR
-- Şifre: password123
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, 
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, 
  confirmation_token, recovery_token, email_change_token_new, email_change
)
VALUES 
  (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '00000000-0000-0000-0000-000000000000', 
    'authenticated', 'authenticated', 'ahmet.ymm@example.com', 
    crypt('password123', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', '{"full_name": "Ahmet Yılmaz"}', 
    now(), now(), '', '', '', ''
  ),
  (
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '00000000-0000-0000-0000-000000000000', 
    'authenticated', 'authenticated', 'merve.smmm@example.com', 
    crypt('password123', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', '{"full_name": "Merve Aydın"}', 
    now(), now(), '', '', '', ''
  );

-- 5. PROFILLERI GÜNCELLE
-- (Not: Trigger ile profiller zaten oluşacaktır, biz sadece detaylarını dolduruyoruz)
UPDATE public.profiles SET 
  profession = 'ymm',
  company_name = 'Yılmaz Denetim A.Ş.',
  avatar_url = 'https://i.pravatar.cc/150?u=ahmet',
  credit_balance = 150,
  profile_completed = true,
  is_verified = true,
  role = 'admin'
WHERE id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

UPDATE public.profiles SET 
  profession = 'mali_musavir',
  company_name = 'Aydın Müşavirlik Ofisi',
  avatar_url = 'https://i.pravatar.cc/150?u=merve',
  credit_balance = 85,
  profile_completed = true,
  is_verified = true
WHERE id = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';

-- 6. ÖRNEK VERİLERİ YENİDEN EKLE
INSERT INTO public.surveys (author_id, title, description, options, expires_at)
VALUES 
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Enflasyon Düzeltmesi', 'Uygulama süreci nasıl gidiyor?', '[{"id": "1", "text": "Sorunsuz", "votes": 5}, {"id": "2", "text": "Zorlanıyoruz", "votes": 12}]'::jsonb, now() + interval '30 days');

INSERT INTO public.discussions (author_id, type, title, body)
VALUES 
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'tartisma', 'E-Defter Beratları', 'Sistemde genel bir yavaşlık mı var?');

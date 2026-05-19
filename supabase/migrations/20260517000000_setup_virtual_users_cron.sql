-- This script requires the pg_cron and pg_net extensions to be enabled in your Supabase project.
-- You can enable them via the Supabase Dashboard -> Database -> Extensions.

-- Replace 'YOUR_PROJECT_REF' and 'YOUR_ANON_KEY' with your actual Supabase project reference and anon key.
-- Or use the Authorization header with a Service Role Key for protected edge functions.

-- 1. Simulate User Creation (Runs twice a day, 10:00 and 16:00, only on weekdays)
SELECT cron.schedule(
  'invoke-simulate-create-user',
  '0 10,16 * * 1-5', -- 10:00 ve 16:00, Pazartesi-Cuma
  $$
  SELECT net.http_post(
      url:='https://yvytejobimltbefxrsjc.supabase.co/functions/v1/simulate-create-user',
      headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI", "Content-Type": "application/json"}'::jsonb
  ) as request_id;
  $$
);

-- 2. Simulate Discussions and Surveys (Runs 3 times a day, only on weekdays)
SELECT cron.schedule(
  'invoke-simulate-discussions',
  '0 11,15,19 * * 1-5', -- 11:00, 15:00, 19:00, Pazartesi-Cuma
  $$
  SELECT net.http_post(
      url:='https://yvytejobimltbefxrsjc.supabase.co/functions/v1/simulate-discussions-and-surveys',
      headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI", "Content-Type": "application/json"}'::jsonb
  ) as request_id;
  $$
);

-- 3. Simulate Replies and Likes (Runs every 1 hour between 10:00 and 20:00, only on weekdays)
SELECT cron.schedule(
  'invoke-simulate-replies-likes',
  '0 10-20 * * 1-5', -- Saat başı (10:00, 11:00... 20:00), Pazartesi-Cuma
  $$
  SELECT net.http_post(
      url:='https://yvytejobimltbefxrsjc.supabase.co/functions/v1/simulate-replies-and-likes',
      headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI", "Content-Type": "application/json"}'::jsonb
  ) as request_id;
  $$
);

-- 4. Simulate Direct Messages (Runs every 19 minutes between 10:00 and 18:59, only on weekdays)
SELECT cron.schedule(
  'invoke-simulate-direct-messages',
  '*/19 10-18 * * 1-5', -- Her 19 dakikada bir (10:00 - 18:59 arası), Pazartesi-Cuma
  $$
  SELECT net.http_post(
      url:='https://yvytejobimltbefxrsjc.supabase.co/functions/v1/simulate-direct-messages',
      headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI", "Content-Type": "application/json"}'::jsonb
  ) as request_id;
  $$
);

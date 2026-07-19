-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Replace [PROJECT_REF] and [ANON_KEY] with your actual Supabase project reference and anon key.

-- 1. Scraper (Her yarım saatte bir, her gün 7/24)
SELECT cron.schedule(
    'weekly_advisor_scraper',
    '*/30 * * * *', -- Her 30 dakikada bir (7/24)
    $$
    SELECT net.http_post(
        url:='https://[PROJECT_REF].supabase.co/functions/v1/scrape-advisors',
        headers:='{"Authorization": "Bearer [ANON_KEY]"}'::jsonb
    );
    $$
);

-- 2. Half-hourly Promotional Emailer (Every 30 minutes, 09:00 to 17:30 TRT / 06:00 to 14:30 UTC, Monday to Friday)
SELECT cron.schedule(
    'half_hourly_promotional_emailer',
    '*/30 6-14 * * 1-5', -- Every 30 mins from 6am to 2pm UTC (9am to 5:30pm TRT) on weekdays
    $$
    SELECT net.http_post(
        url:='https://[PROJECT_REF].supabase.co/functions/v1/send-promotional-emails',
        headers:='{"Authorization": "Bearer [ANON_KEY]"}'::jsonb
    );
    $$
);

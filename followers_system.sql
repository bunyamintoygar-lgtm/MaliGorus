-- Create user_follows table
create table if not exists public.user_follows (
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (follower_id, following_id),
  constraint self_follow_check check (follower_id <> following_id)
);

-- Enable Row Level Security (RLS)
alter table public.user_follows enable row level security;

-- Policies
create policy "Allow public read access to user_follows"
  on public.user_follows for select
  using (true);

create policy "Allow users to follow others"
  on public.user_follows for insert
  with check (auth.uid() = follower_id);

create policy "Allow users to unfollow others"
  on public.user_follows for delete
  using (auth.uid() = follower_id);

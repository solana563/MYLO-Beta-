-- milo. cloud sync: run once in Supabase > SQL editor
create table if not exists public.milo_sync (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.milo_sync enable row level security;
drop policy if exists "milo read own" on public.milo_sync;
drop policy if exists "milo insert own" on public.milo_sync;
drop policy if exists "milo update own" on public.milo_sync;
drop policy if exists "milo delete own" on public.milo_sync;
create policy "milo read own" on public.milo_sync for select using (auth.uid() = user_id);
create policy "milo insert own" on public.milo_sync for insert with check (auth.uid() = user_id);
create policy "milo update own" on public.milo_sync for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "milo delete own" on public.milo_sync for delete using (auth.uid() = user_id);

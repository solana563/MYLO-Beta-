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

-- ======================= milo. accounts, friends, sharing and chat =======================
-- Run this whole file once in Supabase > SQL editor. Safe to run again.
-- Tip: Authentication > Providers > Email > turn OFF "Confirm email" so people can start right after signing up.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  name text not null default '',
  av jsonb not null default '{}'::jsonb check (pg_column_size(av) < 90000),
  terms_v int not null default 0,
  terms_at timestamptz,
  share_pl boolean not null default true,
  share_np boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "profiles read" on public.profiles;
drop policy if exists "profiles insert own" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- create the profile automatically when someone signs up with a username
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare u text := lower(coalesce(new.raw_user_meta_data->>'username',''));
begin
  if u ~ '^[a-z0-9_]{3,20}$' then
    insert into public.profiles(id, username, name) values (new.id, u, coalesce(nullif(new.raw_user_meta_data->>'name',''), u));
  end if;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.username_free(u text) returns boolean language sql security definer set search_path = public as
$$ select not exists (select 1 from public.profiles where username = lower(u)) $$;
grant execute on function public.username_free(text) to anon, authenticated;

create or replace function public.find_user(u text) returns table(id uuid, username text, name text, av jsonb) language sql security definer set search_path = public as
$$ select p.id, p.username, p.name, p.av from public.profiles p where p.username = lower(u) limit 1 $$;
grant execute on function public.find_user(text) to authenticated;

-- friendships: a asks b; b accepts
create table if not exists public.friendships (
  a uuid not null references auth.users(id) on delete cascade,
  b uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a <> b)
);
create unique index if not exists friendships_pair on public.friendships (least(a, b), greatest(a, b));
alter table public.friendships enable row level security;
drop policy if exists "fr read" on public.friendships;
drop policy if exists "fr ask" on public.friendships;
drop policy if exists "fr accept" on public.friendships;
drop policy if exists "fr delete" on public.friendships;
create policy "fr read" on public.friendships for select to authenticated using (auth.uid() in (a, b));
create policy "fr ask" on public.friendships for insert to authenticated with check (a = auth.uid() and status = 'pending');
create policy "fr accept" on public.friendships for update to authenticated using (b = auth.uid()) with check (b = auth.uid() and status = 'accepted');
create policy "fr delete" on public.friendships for delete to authenticated using (auth.uid() in (a, b));

create or replace function public.are_friends(x uuid, y uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.a = x and f.b = y) or (f.a = y and f.b = x))) $$;

create or replace function public.friend_cap() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.friendships where a = new.a or b = new.a) >= 200 then raise exception 'friend_limit'; end if;
  return new;
end $$;
drop trigger if exists friend_cap_t on public.friendships;
create trigger friend_cap_t before insert on public.friendships for each row execute function public.friend_cap();

-- shared: now playing + playlists, stored as song DNA (metadata and a stream source, never audio files)
create table if not exists public.shared (
  user_id uuid primary key references auth.users(id) on delete cascade,
  np jsonb, np_at timestamptz,
  pl jsonb check (pl is null or pg_column_size(pl) < 400000), pl_at timestamptz
);
alter table public.shared enable row level security;
drop policy if exists "shared read" on public.shared;
drop policy if exists "shared insert" on public.shared;
drop policy if exists "shared update" on public.shared;
drop policy if exists "shared delete" on public.shared;
create policy "shared read" on public.shared for select to authenticated using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));
create policy "shared insert" on public.shared for insert to authenticated with check (user_id = auth.uid());
create policy "shared update" on public.shared for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "shared delete" on public.shared for delete to authenticated using (user_id = auth.uid());

-- messages: disappear after 24 hours, each chat holds 5 MB, oldest removed first
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  chat text not null,
  sender uuid not null default auth.uid() references auth.users(id) on delete cascade,
  rcpt uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('text','song','img')),
  body text not null,
  bytes int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists messages_chat_time on public.messages (chat, created_at desc);
create index if not exists messages_rcpt_time on public.messages (rcpt, created_at desc);
alter table public.messages enable row level security;
drop policy if exists "msg read" on public.messages;
drop policy if exists "msg send" on public.messages;
create policy "msg read" on public.messages for select to authenticated using (auth.uid() in (sender, rcpt) and created_at > now() - interval '1 day');
create policy "msg send" on public.messages for insert to authenticated with check (sender = auth.uid() and public.are_friends(sender, rcpt));

create or replace function public.msg_before() returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.sender := auth.uid();
  new.chat := least(new.sender::text, new.rcpt::text) || ':' || greatest(new.sender::text, new.rcpt::text);
  new.bytes := octet_length(new.body) + 64;
  if new.bytes > 400000 then raise exception 'message_too_large'; end if;
  if (select count(*) from public.messages where sender = new.sender and created_at > now() - interval '1 minute') >= 30 then raise exception 'rate_limited'; end if;
  return new;
end $$;
drop trigger if exists msg_before_t on public.messages;
create trigger msg_before_t before insert on public.messages for each row execute function public.msg_before();

create or replace function public.msg_after() returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.messages where chat = new.chat and created_at < now() - interval '1 day';
  delete from public.messages where id in (
    select id from (select id, sum(bytes) over (order by created_at desc, id desc) as run from public.messages where chat = new.chat) s where s.run > 5242880);
  return null;
end $$;
drop trigger if exists msg_after_t on public.messages;
create trigger msg_after_t after insert on public.messages for each row execute function public.msg_after();

-- removing a friend deletes the chat
create or replace function public.fr_gone() returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.messages where chat = least(old.a::text, old.b::text) || ':' || greatest(old.a::text, old.b::text);
  return old;
end $$;
drop trigger if exists fr_gone_t on public.friendships;
create trigger fr_gone_t after delete on public.friendships for each row execute function public.fr_gone();

-- delete my account and everything under it
create or replace function public.delete_me() returns void language plpgsql security definer set search_path = public, auth as $$
begin
  delete from auth.users where id = auth.uid();
end $$;
grant execute on function public.delete_me() to authenticated;

-- optional but recommended: also purge expired messages every hour (Database > Extensions > enable pg_cron first)
-- select cron.schedule('milo-purge', '0 * * * *', $$ delete from public.messages where created_at < now() - interval '1 day' $$);

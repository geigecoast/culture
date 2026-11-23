-- Culture — initial schema (Supabase / Postgres).
-- Privacy rules live here, in row-level security, not only in the app:
--   * attendance is private by default;
--   * friends only see attendance of users who opted in (visibility = friends/public);
--   * blocked users never see the blocker's attendance;
--   * deleting the account removes every row owned by the user.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  attendance_visibility text not null default 'private' check (attendance_visibility in ('private', 'friends', 'public')),
  analytics_consent boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.friendships (
  user_id uuid not null references auth.users (id) on delete cascade,
  friend_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create table public.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

-- One row per (user, event). state = null is a tombstone so other devices learn about removals.
create table public.rsvps (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  event_id text not null,
  state text check (state in ('interested', 'going', 'maybe')),
  updated_at timestamptz not null default now(),
  primary key (user_id, event_id)
);
create index rsvps_updated_at on public.rsvps (user_id, updated_at);

create table public.review_states (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vocab_id text not null,
  ease_factor double precision not null,
  repetitions int not null,
  interval_days int not null,
  due timestamptz not null,
  lapses int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, vocab_id)
);

create table public.progress_days (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  xp int not null default 0,
  primary key (user_id, day)
);

-- Helpers -------------------------------------------------------------------

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where status = 'accepted' and ((user_id = a and friend_id = b) or (user_id = b and friend_id = a))
  );
$$;

create or replace function public.is_blocked(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blocks where (blocker_id = owner and blocked_id = viewer) or (blocker_id = viewer and blocked_id = owner));
$$;

-- Row-level security --------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.rsvps enable row level security;
alter table public.review_states enable row level security;
alter table public.progress_days enable row level security;

create policy "own profile" on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());
create policy "friends see profile" on public.profiles for select
  using (public.are_friends(auth.uid(), id) and not public.is_blocked(auth.uid(), id));

create policy "own friendships" on public.friendships for all
  using (user_id = auth.uid() or friend_id = auth.uid())
  with check (user_id = auth.uid());

create policy "own blocks" on public.blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy "own rsvps" on public.rsvps for all using (user_id = auth.uid()) with check (user_id = auth.uid());
-- Friends see attendance only when the owner opted in, and never across a block.
create policy "shared rsvps" on public.rsvps for select using (
  state is not null
  and not public.is_blocked(auth.uid(), user_id)
  and exists (
    select 1 from public.profiles p
    where p.id = rsvps.user_id
      and (p.attendance_visibility = 'public'
           or (p.attendance_visibility = 'friends' and public.are_friends(auth.uid(), p.id)))
  )
);

create policy "own review states" on public.review_states for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own progress" on public.progress_days for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Keep updated_at server-side so "last writer wins" uses one clock.
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
create trigger rsvps_touch before insert or update on public.rsvps for each row execute function public.touch_updated_at();

-- Create a private profile for every new user.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin insert into profiles (id) values (new.id) on conflict do nothing; return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Account deletion (called from the app). Cascades remove every user-owned row,
-- including rows in tables added later as long as they reference auth.users on delete cascade.
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end; $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- GDPR export.
create or replace function public.export_my_data() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from profiles p where p.id = auth.uid()),
    'rsvps', coalesce((select jsonb_agg(r) from rsvps r where r.user_id = auth.uid()), '[]'::jsonb),
    'review_states', coalesce((select jsonb_agg(s) from review_states s where s.user_id = auth.uid()), '[]'::jsonb),
    'progress_days', coalesce((select jsonb_agg(d) from progress_days d where d.user_id = auth.uid()), '[]'::jsonb),
    'friendships', coalesce((select jsonb_agg(f) from friendships f where f.user_id = auth.uid() or f.friend_id = auth.uid()), '[]'::jsonb),
    'blocks', coalesce((select jsonb_agg(b) from blocks b where b.blocker_id = auth.uid()), '[]'::jsonb)
  );
$$;
grant execute on function public.export_my_data() to authenticated;

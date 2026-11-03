-- Schema for the piano-learning MVP. Postgres on Supabase.
-- Access rules: row level security on every table. auth.uid() is the account id.
-- All times are timestamptz in UTC. No money is stored here: Apple handles payment,
-- and only the entitlement state is kept.

create extension if not exists pgcrypto;

-- shared updated_at trigger
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------- accounts
-- One row per Supabase auth user (email one-time-code sign in).
create table accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger accounts_updated before update on accounts
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------- subscriptions
-- Entitlement mirrored from App Store Server API / Server Notifications v2.
-- The client never writes this table; only edge functions (service role) do.
create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  store text not null default 'app_store' check (store in ('app_store')),
  original_transaction_id text not null unique,
  product_id text not null,
  plan text not null check (plan in ('individual','duo','family')),
  period text not null check (period in ('month','year')),
  status text not null
    check (status in ('trial','active','grace','billing_retry','expired','revoked')),
  max_profiles smallint not null default 1 check (max_profiles between 1 and 5),
  expires_at timestamptz,
  auto_renew boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on subscriptions (account_id);
create index on subscriptions (status, expires_at);
create trigger subscriptions_updated before update on subscriptions
  for each row execute function set_updated_at();

-- Every App Store notification once, by its UUID (they are retried).
create table app_store_events (
  id uuid primary key default gen_random_uuid(),
  notification_uuid text not null unique,
  notification_type text not null,
  subtype text,
  original_transaction_id text,
  signed_date timestamptz not null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);
create index on app_store_events (original_transaction_id);

-- Is this account premium right now? Used by RLS-adjacent checks and functions.
create or replace function has_premium(acc uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from subscriptions s
    where s.account_id = acc
      and s.status in ('trial','active','grace','billing_retry')
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

-- ---------------------------------------------------------------- profiles
-- Learner profiles under one account (family plan: up to 5).
create table profiles (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  kind text not null default 'adult' check (kind in ('adult','kid')),
  input_mode text not null default 'mic' check (input_mode in ('mic','midi','touch')),
  learning_path text check (learning_path in ('melody','chords')),
  experience text not null default 'beginner'
    check (experience in ('beginner','some','advanced')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on profiles (account_id);
create trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();

-- Profile cap: 1 without a plan or on individual, plan's max_profiles otherwise.
create or replace function enforce_profile_cap() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  cap smallint;
  n int;
begin
  select coalesce(max(s.max_profiles), 1) into cap
  from subscriptions s
  where s.account_id = new.account_id
    and s.status in ('trial','active','grace','billing_retry');
  select count(*) into n from profiles where account_id = new.account_id;
  if n >= cap then
    raise exception 'profile_limit_reached' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger profiles_cap before insert on profiles
  for each row execute function enforce_profile_cap();

-- ---------------------------------------------------------------- content
-- Content rows are public metadata. The note data itself lives in Storage as
-- versioned JSON; premium files are only reachable through signed URLs that
-- the content-url function issues after an entitlement check.
create table courses (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  learning_path text not null
    check (learning_path in ('foundation','melody','chords','touch','extra')),
  position int not null,
  is_free boolean not null default false,
  unlock_after_course_id uuid references courses(id) on delete set null,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on courses (learning_path, position);
create index on courses (unlock_after_course_id);
create trigger courses_updated before update on courses
  for each row execute function set_updated_at();

create table lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  position int not null,
  kind text not null check (kind in ('concept','exercise_set','song','star_gate')),
  title text not null,
  stars_required smallint check (stars_required between 1 and 30),
  content_path text,           -- storage key, e.g. lessons/<id>/v3.json
  content_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, position),
  constraint gate_needs_stars check (kind <> 'star_gate' or stars_required is not null)
);
create index on lessons (course_id);
create trigger lessons_updated before update on lessons
  for each row execute function set_updated_at();

create table songs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  composer text not null,
  level text not null check (level in ('beginner','intermediate','advanced')),
  genre text not null,
  -- every song must say why we may ship it
  license text not null check (license in ('public_domain','original','licensed')),
  license_note text not null,
  is_premium boolean not null default true,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on songs (level, genre);
create trigger songs_updated before update on songs
  for each row execute function set_updated_at();

create table song_sections (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references songs(id) on delete cascade,
  position int not null,
  name text not null,           -- intro, part A, whole piece
  content_path text not null,
  backing_audio_path text,
  content_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (song_id, position)
);
create index on song_sections (song_id);
create trigger song_sections_updated before update on song_sections
  for each row execute function set_updated_at();

-- Star gates draw on these songs.
create table gate_songs (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references lessons(id) on delete cascade,
  song_section_id uuid not null references song_sections(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (lesson_id, song_section_id)
);
create index on gate_songs (song_section_id);

-- ---------------------------------------------------------------- learning data
-- One row per finished play-through, written by the record_attempts RPC.
-- client_attempt_id makes offline re-uploads safe.
create table attempts (
  id uuid primary key default gen_random_uuid(),
  client_attempt_id uuid not null unique,
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  lesson_id uuid references lessons(id) on delete set null,
  song_section_id uuid references song_sections(id) on delete set null,
  content_version int not null,
  accuracy smallint not null check (accuracy between 0 and 100),
  timing smallint check (timing between 0 and 100),
  stars smallint not null check (stars between 0 and 3),
  input_mode text not null check (input_mode in ('mic','midi','touch')),
  tempo_pct smallint not null default 100 check (tempo_pct between 25 and 200),
  hands text not null default 'both' check (hands in ('left','right','both')),
  wait_mode boolean not null default false,
  started_at timestamptz not null,
  finished_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint one_target check (num_nonnulls(lesson_id, song_section_id) = 1),
  constraint ends_after_start check (finished_at >= started_at)
);
create index on attempts (profile_id, finished_at desc);
create index on attempts (account_id);
create index on attempts (lesson_id);
create index on attempts (song_section_id);

create table lesson_progress (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  lesson_id uuid not null references lessons(id) on delete cascade,
  status text not null default 'open' check (status in ('open','done')),
  best_stars smallint not null default 0 check (best_stars between 0 and 3),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, lesson_id)
);
create index on lesson_progress (account_id);
create index on lesson_progress (lesson_id);
create trigger lesson_progress_updated before update on lesson_progress
  for each row execute function set_updated_at();

create table song_progress (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  song_section_id uuid not null references song_sections(id) on delete cascade,
  best_stars smallint not null default 0 check (best_stars between 0 and 3),
  plays int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, song_section_id)
);
create index on song_progress (account_id);
create index on song_progress (song_section_id);
create trigger song_progress_updated before update on song_progress
  for each row execute function set_updated_at();

-- Weekly streak. A "week" runs 7 days from week_anchor in the profile's time zone.
create table streaks (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null unique references profiles(id) on delete cascade,
  timezone text not null default 'UTC',
  week_anchor date not null,
  current_weeks int not null default 0,
  best_weeks int not null default 0,
  freezes_left smallint not null default 2 check (freezes_left between 0 and 10),
  weeks_since_freeze_award smallint not null default 0,
  practised_this_week boolean not null default false,
  last_session_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on streaks (account_id);
create trigger streaks_updated before update on streaks
  for each row execute function set_updated_at();

create table favourites (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  song_id uuid not null references songs(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (profile_id, song_id)
);
create index on favourites (account_id);
create index on favourites (song_id);

-- ---------------------------------------------------------------- notifications
create table devices (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  apns_token text not null unique,
  timezone text not null,
  app_version text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on devices (account_id);
create trigger devices_updated before update on devices
  for each row execute function set_updated_at();

create table reminders (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  profile_id uuid not null unique references profiles(id) on delete cascade,
  weekdays smallint[] not null check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  local_time time not null,
  timezone text not null,
  enabled boolean not null default true,
  next_fire_at timestamptz,     -- UTC, recomputed on every change and after each send
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on reminders (account_id);
create index on reminders (next_fire_at) where enabled;
create trigger reminders_updated before update on reminders
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------- row level security
alter table accounts        enable row level security;
alter table subscriptions   enable row level security;
alter table app_store_events enable row level security;
alter table profiles        enable row level security;
alter table courses         enable row level security;
alter table lessons         enable row level security;
alter table songs           enable row level security;
alter table song_sections   enable row level security;
alter table gate_songs      enable row level security;
alter table attempts        enable row level security;
alter table lesson_progress enable row level security;
alter table song_progress   enable row level security;
alter table streaks         enable row level security;
alter table favourites      enable row level security;
alter table devices         enable row level security;
alter table reminders       enable row level security;

-- own account
create policy own_account on accounts for all
  using (id = auth.uid()) with check (id = auth.uid());

-- subscriptions: read own, never write from the client
create policy read_own_subscription on subscriptions for select
  using (account_id = auth.uid());

-- app_store_events: no client policy at all (service role only)

-- user-owned tables: everything scoped by account_id
create policy own_profiles  on profiles  for all using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy own_favourites on favourites for all using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy own_devices   on devices   for all using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy own_reminders on reminders for all using (account_id = auth.uid()) with check (account_id = auth.uid());

-- progress and streaks: read only from the client; written by record_attempts
create policy read_own_attempts on attempts        for select using (account_id = auth.uid());
create policy read_own_lp       on lesson_progress for select using (account_id = auth.uid());
create policy read_own_sp       on song_progress   for select using (account_id = auth.uid());
create policy read_own_streak   on streaks         for select using (account_id = auth.uid());

-- content metadata: any signed-in user can read what is published
create policy read_courses  on courses  for select to authenticated using (published);
create policy read_lessons  on lessons  for select to authenticated
  using (exists (select 1 from courses c where c.id = course_id and c.published));
create policy read_songs    on songs    for select to authenticated using (published);
create policy read_sections on song_sections for select to authenticated
  using (exists (select 1 from songs s where s.id = song_id and s.published));
create policy read_gate_songs on gate_songs for select to authenticated using (true);

-- Child rows must belong to a profile of the same account. Checked here because
-- RLS on profile_id alone would let a client point at another account's profile.
create or replace function profile_in_account() returns trigger
language plpgsql as $$
begin
  if not exists (select 1 from profiles p
                 where p.id = new.profile_id and p.account_id = new.account_id) then
    raise exception 'profile_not_in_account' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger favourites_profile before insert or update on favourites
  for each row execute function profile_in_account();
create trigger reminders_profile before insert or update on reminders
  for each row execute function profile_in_account();
create trigger attempts_profile before insert on attempts
  for each row execute function profile_in_account();

-- ---------------------------------------------------------------- record_attempts
-- The only write path for learning data. Called by the app with a batch of
-- finished attempts (online or after offline play). Safe to call twice with the
-- same batch: attempts are keyed by client_attempt_id.
-- Input: [{client_attempt_id, profile_id, lesson_id | song_section_id,
--          content_version, accuracy, timing, stars, input_mode, tempo_pct,
--          hands, wait_mode, started_at, finished_at}, ...]
create or replace function record_attempts(batch jsonb, tz text default 'UTC')
returns int
language plpgsql security definer set search_path = public as $$
declare
  acc uuid := auth.uid();
  a jsonb;
  inserted int := 0;
  row_id uuid;
  pid uuid;
  local_today date;
begin
  if acc is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if jsonb_typeof(batch) <> 'array' or jsonb_array_length(batch) > 200 then
    raise exception 'bad_batch' using errcode = '22023';
  end if;
  perform 1 from pg_timezone_names where name = tz;
  if not found then tz := 'UTC'; end if;

  for a in select * from jsonb_array_elements(batch) loop
    pid := (a->>'profile_id')::uuid;

    insert into attempts (client_attempt_id, account_id, profile_id, lesson_id,
      song_section_id, content_version, accuracy, timing, stars, input_mode,
      tempo_pct, hands, wait_mode, started_at, finished_at)
    values ((a->>'client_attempt_id')::uuid, acc, pid,
      (a->>'lesson_id')::uuid, (a->>'song_section_id')::uuid,
      (a->>'content_version')::int, (a->>'accuracy')::smallint,
      (a->>'timing')::smallint, (a->>'stars')::smallint, a->>'input_mode',
      coalesce((a->>'tempo_pct')::smallint, 100), coalesce(a->>'hands', 'both'),
      coalesce((a->>'wait_mode')::boolean, false),
      (a->>'started_at')::timestamptz,
      -- never trust a finish time in the future
      least((a->>'finished_at')::timestamptz, now()))
    on conflict (client_attempt_id) do nothing
    returning id into row_id;

    continue when row_id is null;   -- already recorded
    inserted := inserted + 1;

    if (a->>'lesson_id') is not null then
      insert into lesson_progress (account_id, profile_id, lesson_id, status,
        best_stars, completed_at)
      values (acc, pid, (a->>'lesson_id')::uuid,
        case when (a->>'stars')::int >= 1 then 'done' else 'open' end,
        (a->>'stars')::smallint,
        case when (a->>'stars')::int >= 1 then now() end)
      on conflict (profile_id, lesson_id) do update set
        best_stars = greatest(lesson_progress.best_stars, excluded.best_stars),
        status = case when lesson_progress.status = 'done'
                        or excluded.status = 'done' then 'done' else 'open' end,
        completed_at = coalesce(lesson_progress.completed_at, excluded.completed_at);
    else
      -- Song stars only count at full tempo without wait mode (a slowed or
      -- waiting play is practice, not a pass). Lessons set their own tempo.
      insert into song_progress (account_id, profile_id, song_section_id,
        best_stars, plays)
      values (acc, pid, (a->>'song_section_id')::uuid,
        case when coalesce((a->>'tempo_pct')::int, 100) >= 100
              and not coalesce((a->>'wait_mode')::boolean, false)
             then (a->>'stars')::smallint else 0 end, 1)
      on conflict (profile_id, song_section_id) do update set
        best_stars = greatest(song_progress.best_stars, excluded.best_stars),
        plays = song_progress.plays + 1;
    end if;

    -- streak: first session ever anchors the weekly cycle
    local_today := (now() at time zone tz)::date;
    insert into streaks (account_id, profile_id, timezone, week_anchor,
      current_weeks, best_weeks, practised_this_week, last_session_at)
    values (acc, pid, tz, local_today, 1, 1, true, now())
    on conflict (profile_id) do update set
      timezone = excluded.timezone,
      current_weeks = case when streaks.practised_this_week
                           then streaks.current_weeks
                           else streaks.current_weeks + 1 end,
      best_weeks = greatest(streaks.best_weeks, case when streaks.practised_this_week
                           then streaks.current_weeks
                           else streaks.current_weeks + 1 end),
      practised_this_week = true,
      last_session_at = now();
  end loop;

  return inserted;
end $$;

revoke all on function record_attempts(jsonb, text) from public;
grant execute on function record_attempts(jsonb, text) to authenticated;

-- ---------------------------------------------------------------- roll_streaks
-- Run hourly by pg_cron. Closes every week whose 7 days are over in the
-- profile's time zone: a practised week resets the flag; an empty week spends a
-- freeze or resets the streak. Every 5 kept weeks earns one freeze.
create or replace function roll_streaks() returns int
language plpgsql security definer set search_path = public as $$
declare
  n int := 0;
  s record;
  weeks_over int;
begin
  for s in
    select * from streaks
    where (now() at time zone timezone)::date >= week_anchor + 7
    for update skip locked
  loop
    weeks_over := ((now() at time zone s.timezone)::date - s.week_anchor) / 7;
    update streaks set
      -- the first closed week is the one that was being tracked
      current_weeks = case
        when s.practised_this_week and weeks_over = 1 then s.current_weeks
        when s.practised_this_week and weeks_over - 1 <= s.freezes_left then s.current_weeks
        when not s.practised_this_week and weeks_over <= s.freezes_left then s.current_weeks
        else 0 end,
      freezes_left = case
        when s.practised_this_week and weeks_over - 1 <= s.freezes_left
          then s.freezes_left - (weeks_over - 1)
        when not s.practised_this_week and weeks_over <= s.freezes_left
          then s.freezes_left - weeks_over
        else 0 end,
      weeks_since_freeze_award = case
        when s.practised_this_week and weeks_over = 1 then s.weeks_since_freeze_award + 1
        else 0 end,
      practised_this_week = false,
      week_anchor = s.week_anchor + weeks_over * 7
    where id = s.id;

    -- award a freeze every 5 practised weeks in a row (cap 10)
    update streaks set freezes_left = least(freezes_left + 1, 10),
                       weeks_since_freeze_award = 0
    where id = s.id and weeks_since_freeze_award >= 5;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function roll_streaks() from public;

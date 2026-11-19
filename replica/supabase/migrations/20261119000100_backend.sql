-- What the app needs on top of schema.sql to run on a real Supabase project.

-- Every new auth user gets an accounts row, so the app never has to create one and
-- profiles can point at it straight after the first sign-in.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into accounts (id) values (new.id) on conflict (id) do nothing;
  return new;
end $$;
revoke all on function handle_new_user() from public;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Users who signed up before this trigger existed.
insert into accounts (id) select id from auth.users on conflict (id) do nothing;

-- Clients never write progress or subscriptions; RLS already blocks it, and the table
-- grants say the same thing so a policy mistake later can't open them.
revoke insert, update, delete on subscriptions, app_store_events, attempts,
  lesson_progress, song_progress, streaks from anon, authenticated;
revoke all on app_store_events from anon, authenticated;
-- Signed-out visitors read nothing at all.
revoke all on all tables in schema public from anon;
revoke execute on function has_premium(uuid) from public, anon;

-- Hourly streak rollover (architecture.md: jobs). pg_cron is available on every
-- Supabase project; a plain Postgres without it (the local tests) skips this.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('roll-streaks', '7 * * * *', 'select public.roll_streaks()');
  end if;
end $$;

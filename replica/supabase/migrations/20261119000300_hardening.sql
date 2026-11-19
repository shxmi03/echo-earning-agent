-- From the Supabase security advisor on the first deploy. Supabase grants EXECUTE on
-- new functions straight to anon and authenticated, so "revoke ... from public" alone
-- leaves them callable through /rest/v1/rpc/.

-- Trigger and job functions: never callable over the API.
revoke execute on function enforce_profile_cap() from public, anon, authenticated;
revoke execute on function handle_new_user() from public, anon, authenticated;
revoke execute on function roll_streaks() from public, anon, authenticated;
revoke execute on function profile_in_account() from public, anon, authenticated;
revoke execute on function set_updated_at() from public, anon, authenticated;
-- Entitlement checks run inside edge functions with the service role.
revoke execute on function has_premium(uuid) from public, anon, authenticated;
-- The one RPC the app calls: signed-in users only.
revoke execute on function record_attempts(jsonb, text) from public, anon;
grant execute on function record_attempts(jsonb, text) to authenticated;

-- Pin search_path on the remaining plain functions.
alter function set_updated_at() set search_path = public;
alter function profile_in_account() set search_path = public;

-- app_store_events has RLS on and no policy on purpose: only the service role
-- (the App Store webhook) touches it.
comment on table app_store_events is 'Service role only. RLS on with no policy on purpose.';

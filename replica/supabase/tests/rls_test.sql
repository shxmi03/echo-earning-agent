-- Run by tests/run.sh after the migrations. Every check raises on failure.
\set ON_ERROR_STOP on
insert into auth.users values ('11111111-1111-1111-1111-111111111111', 'a@example.com'),
                              ('22222222-2222-2222-2222-222222222222', 'b@example.com');

do $$ begin
  assert (select count(*) from accounts) = 2, 'new auth users get an accounts row';
end $$;

-- ---- signed in as A
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false) \g /dev/null

do $$ begin
  assert (select count(*) from courses) = 1, 'signed-in users see the published course';
  assert (select count(*) from lessons) = 6, 'and its six lessons (five and the first song)';
end $$;

insert into profiles (id, account_id, name, input_mode, experience)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Ana', 'mic', 'beginner');

do $$ begin
  begin
    insert into profiles (account_id, name) values ('11111111-1111-1111-1111-111111111111', 'Second');
    raise exception 'a second profile without a plan must fail';
  exception when sqlstate 'P0001' then
    assert sqlerrm = 'profile_limit_reached', sqlerrm;
  end;
end $$;

do $$
declare
  batch jsonb := '[{"client_attempt_id":"cccccccc-0000-0000-0000-000000000001",
    "profile_id":"aaaaaaaa-0000-0000-0000-000000000001",
    "lesson_id":"a0709ee4-87f0-5519-a787-e7004b828ec9","content_version":1,
    "accuracy":92,"stars":3,"input_mode":"mic","tempo_pct":100,"hands":"right",
    "started_at":"2026-11-19T10:00:00Z","finished_at":"2026-11-19T10:05:00Z"}]';
begin
  assert record_attempts(batch, 'Europe/Zagreb') = 1, 'first upload inserts';
  assert record_attempts(batch, 'Europe/Zagreb') = 0, 'replay inserts nothing';
  assert (select status from lesson_progress) = 'done', 'lesson done';
  assert (select best_stars from lesson_progress) = 3, '3 stars';
  assert (select current_weeks from streaks) = 1, 'streak starts';
end $$;

do $$ begin
  begin
    insert into attempts (client_attempt_id, account_id, profile_id, lesson_id, content_version,
      accuracy, stars, input_mode, started_at, finished_at)
    values (gen_random_uuid(), '11111111-1111-1111-1111-111111111111',
      'aaaaaaaa-0000-0000-0000-000000000001', 'a0709ee4-87f0-5519-a787-e7004b828ec9', 1,
      100, 3, 'mic', now(), now());
    raise exception 'clients must not write attempts directly';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into subscriptions (account_id, original_transaction_id, product_id, plan, period, status)
    values ('11111111-1111-1111-1111-111111111111', 'x', 'p', 'family', 'year', 'active');
    raise exception 'clients must not write subscriptions';
  exception when insufficient_privilege then null;
  end;
  begin
    perform roll_streaks();
    raise exception 'clients must not run the streak job';
  exception when insufficient_privilege then null;
  end;
  begin
    perform has_premium('11111111-1111-1111-1111-111111111111');
    raise exception 'clients must not call has_premium';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- signed in as B
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false) \g /dev/null
do $$ begin
  assert (select count(*) from profiles) = 0, 'B sees none of A''s profiles';
  assert (select count(*) from attempts) = 0, 'B sees none of A''s attempts';
  assert (select count(*) from lesson_progress) = 0, 'B sees none of A''s progress';
  assert (select count(*) from streaks) = 0, 'B sees none of A''s streak';
  begin
    perform record_attempts('[{"client_attempt_id":"cccccccc-0000-0000-0000-000000000002",
      "profile_id":"aaaaaaaa-0000-0000-0000-000000000001",
      "lesson_id":"a0709ee4-87f0-5519-a787-e7004b828ec9","content_version":1,
      "accuracy":10,"stars":0,"input_mode":"mic",
      "started_at":"2026-11-19T10:00:00Z","finished_at":"2026-11-19T10:05:00Z"}]');
    raise exception 'B must not record into A''s profile';
  exception when sqlstate 'P0001' then
    assert sqlerrm = 'profile_not_in_account', sqlerrm;
  end;
  update profiles set name = 'hacked' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
end $$;

-- ---- signed out
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false) \g /dev/null
do $$ begin
  begin
    perform count(*) from courses;
    raise exception 'signed-out visitors must not read tables';
  exception when insufficient_privilege then null;
  end;
  begin
    perform record_attempts('[]');
    raise exception 'signed-out visitors must not call record_attempts';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- delete-account: removing the auth user removes everything
reset role;
do $$ begin
  assert (select name from profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 'Ana',
    'B''s update must not touch A''s profile';
  delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
  assert (select count(*) from accounts where id = '11111111-1111-1111-1111-111111111111') = 0, 'account gone';
  assert (select count(*) from profiles) = 0, 'profiles gone';
  assert (select count(*) from attempts) = 0, 'attempts gone';
  assert (select count(*) from lesson_progress) = 0, 'progress gone';
  assert (select count(*) from streaks) = 0, 'streak gone';
end $$;

\echo 'All database checks passed.'

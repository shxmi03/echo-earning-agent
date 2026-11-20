-- First course content version 4: a star gate before the song (S09). Same UUID and
-- numbers as `gates` in app/.../Resources/first-steps.json.
--
-- A gate here counts the stars of the course's own lessons since the previous gate (the
-- app does the counting, from lesson_progress). It doesn't use gate_songs: that table is
-- for gates drawn from the song library, which doesn't exist yet.
--
-- The song moves from position 6 to 7 first, so (course_id, position) stays unique.
update lessons set position = 7
where id = 'a9d032ab-362f-5115-b815-72c26246d782';

insert into lessons (id, course_id, position, kind, title, stars_required, content_version) values
  ('3485bb09-53e1-5cdc-b4f7-bad8d5004c61', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 6, 'star_gate',
   'Ready for the song', 10, 1)
on conflict (id) do update set position = excluded.position, kind = excluded.kind,
  title = excluded.title, stars_required = excluded.stars_required;

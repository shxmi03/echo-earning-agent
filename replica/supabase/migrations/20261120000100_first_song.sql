-- The first course ends on a song (fix 1: the whole first course is free, up to a finished
-- song). Same UUID as the lesson in app/.../Resources/first-steps.json.
insert into lessons (id, course_id, position, kind, title, content_version) values
  ('a9d032ab-362f-5115-b815-72c26246d782', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 6, 'song',
   'Your first song: Morning Steps', 1)
on conflict (id) do update set position = excluded.position, kind = excluded.kind,
  title = excluded.title, content_version = excluded.content_version;

-- The first course, from app/HandspanCore/Sources/HandspanCore/Resources/first-steps.json.
-- The note data ships in the app; these rows exist so attempts and progress can point at
-- real lesson ids. Same UUIDs as the JSON.
insert into courses (id, slug, title, learning_path, position, is_free, published)
values ('d4d397f6-e393-5d7e-a830-239b9a8c6949', 'first-steps', 'First steps', 'foundation', 1, true, true)
on conflict (id) do update set title = excluded.title, is_free = excluded.is_free, published = excluded.published;

insert into lessons (id, course_id, position, kind, title, content_version) values
  ('a0709ee4-87f0-5519-a787-e7004b828ec9', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 1, 'concept', 'Find middle C', 1),
  ('ba403960-5ae3-547c-9466-3822d8cf0528', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 2, 'concept', 'C, D and E', 1),
  ('bf772433-e1a6-506e-92cc-6ef59543e75f', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 3, 'concept', 'Steps on the staff', 1),
  ('4eb18dd9-6443-5620-9f55-ed8e203c1cce', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 4, 'concept', 'F and G', 1),
  ('3f3816f1-9889-5161-be50-ecdb80e69c8e', 'd4d397f6-e393-5d7e-a830-239b9a8c6949', 5, 'exercise_set', 'Five notes, right hand', 1)
on conflict (id) do update set position = excluded.position, kind = excluded.kind,
  title = excluded.title, content_version = excluded.content_version;

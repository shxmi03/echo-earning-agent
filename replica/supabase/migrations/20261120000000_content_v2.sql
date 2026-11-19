-- First course content version 2: lessons 2 to 5 gained a timed exercise (S12).
update lessons set content_version = 2
where course_id = 'd4d397f6-e393-5d7e-a830-239b9a8c6949' and position between 2 and 5;

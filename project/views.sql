-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 6: Views
-- run after schema.sql and seed.sql

-- VIEW 1: student_transcript
-- shows everything a student has enrolled in, both current and past
-- useful for checking course history or generating a transcript
-- usage: SELECT * FROM student_transcript WHERE roll_no = '22CS001';

CREATE OR REPLACE VIEW student_transcript AS
SELECT
    s.student_id,
    s.roll_no,
    s.name                          AS student_name,
    d_s.dept_code                   AS student_dept,
    s.year_of_study,
    c.course_code,
    c.title                         AS course_title,
    c.credits,
    c.schedule_day,
    c.schedule_start,
    c.schedule_end,
    i.name                          AS instructor_name,
    d_c.dept_code                   AS course_dept,
    e.status,
    e.enrolled_at
FROM   Enrollments e
JOIN   Students    s   ON e.student_id    = s.student_id
JOIN   Courses     c   ON e.course_id     = c.course_id
JOIN   Instructors i   ON c.instructor_id = i.instructor_id
JOIN   Departments d_s ON s.dept_id       = d_s.dept_id
JOIN   Departments d_c ON c.dept_id       = d_c.dept_id
ORDER  BY s.roll_no, e.status, c.course_code;


-- VIEW 2: course_roster
-- shows all students enrolled in each course along with remaining seats
-- instructors can use this to see whos in their class
-- usage: SELECT * FROM course_roster WHERE course_code = 'CS201';

CREATE OR REPLACE VIEW course_roster AS
SELECT
    c.course_id,
    c.course_code,
    c.title                                 AS course_title,
    d.dept_code                             AS dept,
    i.name                                  AS instructor,
    c.schedule_day,
    c.schedule_start,
    c.schedule_end,
    c.capacity,
    c.enrolled_count,
    (c.capacity - c.enrolled_count)         AS seats_remaining,
    s.roll_no,
    s.name                                  AS student_name,
    e.status
FROM   Courses     c
JOIN   Departments d ON c.dept_id       = d.dept_id
JOIN   Instructors i ON c.instructor_id = i.instructor_id
LEFT JOIN Enrollments e ON c.course_id  = e.course_id
                       AND e.status     = 'enrolled'
LEFT JOIN Students    s ON e.student_id = s.student_id
ORDER  BY c.course_code, s.roll_no;


-- VIEW 3: department_summary
-- one row per department with total courses, total students enrolled, and occupancy %
-- usage: SELECT * FROM department_summary;

CREATE OR REPLACE VIEW department_summary AS
SELECT
    d.dept_id,
    d.dept_name,
    d.dept_code,
    COUNT(DISTINCT c.course_id)                         AS courses_offered,
    COALESCE(SUM(c.enrolled_count), 0)                  AS total_enrolled,
    COALESCE(SUM(c.capacity), 0)                        AS total_capacity,
    ROUND(
        COALESCE(SUM(c.enrolled_count), 0)::NUMERIC
      / NULLIF(SUM(c.capacity), 0) * 100, 1
    )                                                   AS occupancy_pct,
    COUNT(DISTINCT i.instructor_id)                     AS num_instructors
FROM   Departments d
LEFT JOIN Courses      c ON d.dept_id = c.dept_id
LEFT JOIN Instructors  i ON d.dept_id = i.dept_id
GROUP  BY d.dept_id, d.dept_name, d.dept_code
ORDER  BY d.dept_name;


-- quick sanity check to make sure all 3 views have data
SELECT 'student_transcript' AS view_name, COUNT(*) AS rows FROM student_transcript
UNION ALL
SELECT 'course_roster',                  COUNT(*) FROM course_roster
UNION ALL
SELECT 'department_summary',             COUNT(*) FROM department_summary;

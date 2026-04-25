-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 6: Views
-- Run after: schema.sql, seed.sql

-- ============================================================
-- VIEW 1: student_transcript
-- One row per (student, course) enrollment.
-- Shows full course history (completed + currently enrolled).
-- ============================================================

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

-- Sample query: Alice's full transcript
-- SELECT * FROM student_transcript WHERE roll_no = '22CS001';


-- ============================================================
-- VIEW 2: course_roster
-- One row per (course, enrolled student).
-- Shows instructor, seats used, and remaining capacity.
-- ============================================================

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

-- Sample query: who is in CS201?
-- SELECT course_code, student_name, seats_remaining FROM course_roster WHERE course_code = 'CS201';


-- ============================================================
-- VIEW 3: department_summary
-- One row per department.
-- Shows total courses offered, total active enrollments, and
-- average seat occupancy (%).
-- ============================================================

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

-- Sample query: view all departments
-- SELECT * FROM department_summary;


-- ============================================================
-- QUICK VIEW VERIFICATION
-- ============================================================

SELECT 'student_transcript rows' AS view_name, COUNT(*) AS row_count FROM student_transcript
UNION ALL
SELECT 'course_roster rows',                  COUNT(*) FROM course_roster
UNION ALL
SELECT 'department_summary rows',             COUNT(*) FROM department_summary;

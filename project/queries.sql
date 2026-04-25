-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 2: Basic Queries
-- Run after: schema.sql, seed.sql

-- ============================================================
-- Q1: All courses a specific student is currently enrolled in
-- ============================================================
SELECT
    c.course_code,
    c.title,
    c.credits,
    c.schedule_day,
    c.schedule_start,
    c.schedule_end,
    i.name AS instructor
FROM   Enrollments e
JOIN   Courses     c ON e.course_id     = c.course_id
JOIN   Instructors i ON c.instructor_id = i.instructor_id
WHERE  e.student_id = 1           -- Alice
  AND  e.status     = 'enrolled'
ORDER  BY c.schedule_day, c.schedule_start;


-- ============================================================
-- Q2: All students enrolled in a given course
-- ============================================================
SELECT
    s.roll_no,
    s.name,
    s.email,
    s.year_of_study,
    d.dept_code
FROM   Enrollments e
JOIN   Students    s ON e.student_id = s.student_id
JOIN   Departments d ON s.dept_id    = d.dept_id
WHERE  e.course_id = 2            -- CS201
  AND  e.status    = 'enrolled'
ORDER  BY s.roll_no;


-- ============================================================
-- Q3: Courses with available seats
-- ============================================================
SELECT
    c.course_code,
    c.title,
    c.capacity,
    c.enrolled_count,
    (c.capacity - c.enrolled_count) AS seats_available,
    i.name AS instructor
FROM   Courses     c
JOIN   Instructors i ON c.instructor_id = i.instructor_id
WHERE  c.enrolled_count < c.capacity
ORDER  BY seats_available DESC;


-- ============================================================
-- Q4: Full timetable for a student (current enrollments)
-- ============================================================
SELECT
    c.schedule_day                       AS day,
    c.schedule_start                     AS start_time,
    c.schedule_end                       AS end_time,
    c.course_code,
    c.title,
    i.name                               AS instructor,
    d.dept_code                          AS offering_dept
FROM   Enrollments e
JOIN   Courses     c ON e.course_id     = c.course_id
JOIN   Instructors i ON c.instructor_id = i.instructor_id
JOIN   Departments d ON c.dept_id       = d.dept_id
WHERE  e.student_id = 1           -- Alice
  AND  e.status     = 'enrolled'
ORDER  BY c.schedule_day, c.schedule_start;


-- ============================================================
-- Q5: Students who have completed a course (grade/history)
-- ============================================================
SELECT
    s.roll_no,
    s.name,
    c.course_code,
    c.title,
    e.enrolled_at,
    e.status
FROM   Enrollments e
JOIN   Students s ON e.student_id = s.student_id
JOIN   Courses  c ON e.course_id  = c.course_id
WHERE  e.status = 'completed'
ORDER  BY s.roll_no, c.course_code;


-- ============================================================
-- Q6: Courses that have unfulfilled prerequisites for a student
--     (courses the student CANNOT enroll in yet)
-- ============================================================
SELECT
    c.course_code,
    c.title,
    STRING_AGG(preq.course_code, ', ' ORDER BY preq.course_code) AS missing_prereqs
FROM   Courses c
JOIN   Prerequisites p  ON c.course_id       = p.course_id
JOIN   Courses preq     ON p.prereq_course_id = preq.course_id
WHERE  NOT EXISTS (
           SELECT 1
           FROM   Enrollments e
           WHERE  e.student_id  = 3           -- Charlie
             AND  e.course_id   = p.prereq_course_id
             AND  e.status      = 'completed'
       )
GROUP  BY c.course_id, c.course_code, c.title
ORDER  BY c.course_code;

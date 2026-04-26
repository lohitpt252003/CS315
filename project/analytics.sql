-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 6: Analytical Queries
-- run after schema.sql, seed.sql, views.sql

-- A1: which courses are the most popular? sorted by how full they are
SELECT
    c.course_code,
    c.title,
    d.dept_code,
    c.enrolled_count,
    c.capacity,
    ROUND(c.enrolled_count::NUMERIC / c.capacity * 100, 1) AS occupancy_pct,
    i.name AS instructor
FROM   Courses     c
JOIN   Departments d ON c.dept_id       = d.dept_id
JOIN   Instructors i ON c.instructor_id = i.instructor_id
ORDER  BY occupancy_pct DESC, c.enrolled_count DESC;


-- A2: who has the heaviest course load right now?
-- shows total credits so you can see who might be overloading
SELECT
    s.roll_no,
    s.name,
    d.dept_code,
    COUNT(e.course_id)          AS courses_enrolled,
    SUM(c.credits)              AS total_credits
FROM   Students    s
JOIN   Departments d ON s.dept_id    = d.dept_id
JOIN   Enrollments e ON s.student_id = e.student_id
                     AND e.status    = 'enrolled'
JOIN   Courses     c ON e.course_id  = c.course_id
GROUP  BY s.student_id, s.roll_no, s.name, d.dept_code
ORDER  BY total_credits DESC, courses_enrolled DESC;


-- A3: courses that are less than 50% full — maybe not enough interest?
SELECT
    c.course_code,
    c.title,
    c.enrolled_count,
    c.capacity,
    ROUND(c.enrolled_count::NUMERIC / c.capacity * 100, 1) AS fill_pct,
    (c.capacity - c.enrolled_count)                         AS empty_seats
FROM   Courses c
WHERE  c.enrolled_count::NUMERIC / c.capacity < 0.5
ORDER  BY fill_pct ASC;


-- A4: department-level breakdown — how many courses, avg occupancy, and the most popular course per dept
SELECT
    d.dept_name,
    d.dept_code,
    COUNT(DISTINCT c.course_id)                              AS courses,
    SUM(c.enrolled_count)                                    AS total_students,
    ROUND(AVG(c.enrolled_count::NUMERIC / c.capacity * 100), 1) AS avg_occupancy_pct,
    (
        SELECT c2.course_code
        FROM   Courses c2
        WHERE  c2.dept_id = d.dept_id
        ORDER  BY c2.enrolled_count DESC
        LIMIT  1
    )                                                        AS most_popular_course
FROM   Departments d
LEFT JOIN Courses c ON d.dept_id = c.dept_id
GROUP  BY d.dept_id, d.dept_name, d.dept_code
ORDER  BY total_students DESC NULLS LAST;


-- A5: who is eligible to enroll in CS315 but hasnt yet?
-- eligible means they have all prereqs completed and arent already in the course
WITH prereqs_for_course AS (
    SELECT prereq_course_id
    FROM   Prerequisites
    WHERE  course_id = 3         -- CS315
),
eligible_students AS (
    SELECT s.student_id, s.roll_no, s.name
    FROM   Students s
    WHERE  NOT EXISTS (          -- not already enrolled or completed
               SELECT 1 FROM Enrollments e
               WHERE  e.student_id = s.student_id
                 AND  e.course_id  = 3
           )
      AND  NOT EXISTS (          -- check all prereqs are completed
               SELECT 1 FROM prereqs_for_course p
               WHERE  NOT EXISTS (
                   SELECT 1 FROM Enrollments e2
                   WHERE  e2.student_id = s.student_id
                     AND  e2.course_id  = p.prereq_course_id
                     AND  e2.status     = 'completed'
               )
           )
)
SELECT es.roll_no, es.name,
       c.course_code, c.title,
       (c.capacity - c.enrolled_count) AS seats_left
FROM   eligible_students es
CROSS JOIN Courses c
WHERE  c.course_id = 3
ORDER  BY es.roll_no;


-- A6: instructor workload — how many courses each prof is teaching and how many students total
SELECT
    i.name          AS instructor,
    d.dept_code,
    COUNT(c.course_id)          AS courses_teaching,
    SUM(c.enrolled_count)       AS total_students,
    SUM(c.credits)              AS total_credit_hours
FROM   Instructors i
JOIN   Departments d ON i.dept_id       = d.dept_id
JOIN   Courses     c ON i.instructor_id = c.instructor_id
GROUP  BY i.instructor_id, i.name, d.dept_code
ORDER  BY total_students DESC;

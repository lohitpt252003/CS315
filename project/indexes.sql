-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 4: Indexing & Query Optimization
-- Run after: schema.sql, seed.sql

-- ============================================================
-- INDEX DEFINITIONS
-- ============================================================

-- Enrollments: most frequent lookup pattern is by student_id
-- (timetable, prereq check, conflict check all filter on this).
CREATE INDEX IF NOT EXISTS idx_enrollments_student
    ON Enrollments (student_id);

-- Enrollments: course_id is the second most queried column
-- (roster retrieval, seat-count checks, drops).
CREATE INDEX IF NOT EXISTS idx_enrollments_course
    ON Enrollments (course_id);

-- Enrollments: status is almost always part of the WHERE clause
-- ('enrolled', 'completed'). Partial index on 'enrolled' is the
-- hottest path — covers seat-limit trigger and conflict check.
CREATE INDEX IF NOT EXISTS idx_enrollments_status
    ON Enrollments (status);

CREATE INDEX IF NOT EXISTS idx_enrollments_enrolled_partial
    ON Enrollments (student_id, course_id)
    WHERE status = 'enrolled';

-- Courses: frequently filtered by department for faculty reports
-- and the department_summary view.
CREATE INDEX IF NOT EXISTS idx_courses_dept
    ON Courses (dept_id);

-- Students: roll_no is used for user-facing lookups (login, search).
CREATE INDEX IF NOT EXISTS idx_students_rollno
    ON Students (roll_no);

-- Prerequisites: looking up prereqs for a course is O(prereqs)
-- without an index; common during enrollment validation.
CREATE INDEX IF NOT EXISTS idx_prereqs_course
    ON Prerequisites (course_id);


-- ============================================================
-- QUERY PLAN DEMONSTRATION
-- Run these in psql after ANALYZE to see planner behaviour.
--
-- Typical output BEFORE indexes: Seq Scan on enrollments
-- Typical output AFTER  indexes: Index Scan / Bitmap Heap Scan
-- ============================================================

-- Update planner statistics first
ANALYZE Enrollments;
ANALYZE Courses;
ANALYZE Students;

-- Plan: fetch all current enrollments for Alice (student_id = 1)
EXPLAIN ANALYZE
SELECT c.course_code, c.title, e.status
FROM   Enrollments e
JOIN   Courses c ON e.course_id = c.course_id
WHERE  e.student_id = 1
  AND  e.status     = 'enrolled';

-- Plan: find all students in CS201 (course_id = 2)
EXPLAIN ANALYZE
SELECT s.name, s.roll_no
FROM   Enrollments e
JOIN   Students s ON e.student_id = s.student_id
WHERE  e.course_id = 2
  AND  e.status    = 'enrolled';

-- Plan: courses offered by CS department (dept_id = 1)
EXPLAIN ANALYZE
SELECT course_code, title, enrolled_count, capacity
FROM   Courses
WHERE  dept_id = 1;


-- ============================================================
-- WHY THESE INDEXES
--
-- idx_enrollments_student: Every timetable query, prereq check,
--   and conflict detection filters by student_id. Without this,
--   every such query does a full table scan of Enrollments.
--
-- idx_enrollments_course: Roster queries and seat-count triggers
--   filter by course_id. Same problem as above for courses.
--
-- idx_enrollments_enrolled_partial: The 'enrolled' status subset
--   is the one that the constraint trigger reads on every INSERT.
--   A partial index covers only these rows — smaller, faster.
--
-- idx_courses_dept: The department_summary view groups by dept_id.
--   With an index the planner can do an index scan instead of
--   a full Courses scan followed by hash aggregation.
--
-- idx_prereqs_course: Enrollment validation queries
--   "SELECT * FROM Prerequisites WHERE course_id = X" on every
--   INSERT. With 100s of courses this becomes expensive without
--   the index.
-- ============================================================

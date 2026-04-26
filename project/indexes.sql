-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 4: Indexing and Query Optimization
-- run after schema.sql and seed.sql

-- most queries on Enrollments filter by student_id (timetable, prereq check, conflict check)
-- so this one is probably the most used index overall
CREATE INDEX IF NOT EXISTS idx_enrollments_student
    ON Enrollments (student_id);

-- course_id is used a lot too, mostly for roster queries and seat count stuff
CREATE INDEX IF NOT EXISTS idx_enrollments_course
    ON Enrollments (course_id);

-- almost every query also filters by status so index that too
CREATE INDEX IF NOT EXISTS idx_enrollments_status
    ON Enrollments (status);

-- this is the most important one imo — partial index only on active enrollments
-- the constraint trigger reads this on literally every single insert attempt
-- keeping it partial means it stays small (excludes dropped/completed rows)
CREATE INDEX IF NOT EXISTS idx_enrollments_enrolled_partial
    ON Enrollments (student_id, course_id)
    WHERE status = 'enrolled';

-- courses are often filtered by department, mainly for the department_summary view
CREATE INDEX IF NOT EXISTS idx_courses_dept
    ON Courses (dept_id);

-- roll_no is what students use to identify themselves, makes lookups faster
CREATE INDEX IF NOT EXISTS idx_students_rollno
    ON Students (roll_no);

-- every enrollment validation does "SELECT * FROM Prerequisites WHERE course_id = X"
-- without this it would be a full table scan every time
CREATE INDEX IF NOT EXISTS idx_prereqs_course
    ON Prerequisites (course_id);


-- update stats before running EXPLAIN so the planner has fresh info
ANALYZE Enrollments;
ANALYZE Courses;
ANALYZE Students;

-- check query plan for fetching Alice's current courses
-- should use idx_enrollments_student after the index is created
EXPLAIN ANALYZE
SELECT c.course_code, c.title, e.status
FROM   Enrollments e
JOIN   Courses c ON e.course_id = c.course_id
WHERE  e.student_id = 1
  AND  e.status     = 'enrolled';

-- check plan for getting all students in CS201
EXPLAIN ANALYZE
SELECT s.name, s.roll_no
FROM   Enrollments e
JOIN   Students s ON e.student_id = s.student_id
WHERE  e.course_id = 2
  AND  e.status    = 'enrolled';

-- check plan for courses by CS department
EXPLAIN ANALYZE
SELECT course_code, title, enrolled_count, capacity
FROM   Courses
WHERE  dept_id = 1;

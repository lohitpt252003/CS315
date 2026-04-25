-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 2: Sample Data
-- Run after: schema.sql

-- ============================================================
-- DEPARTMENTS (3)
-- ============================================================
INSERT INTO Departments (dept_name, dept_code) VALUES
    ('Computer Science',       'CS'),
    ('Electrical Engineering', 'EE'),
    ('Mathematics',            'MTH');


-- ============================================================
-- INSTRUCTORS (4)
-- ============================================================
INSERT INTO Instructors (name, email, dept_id) VALUES
    ('Dr. Ravi Shankar', 'ravi.shankar@iitk.ac.in',   1),
    ('Dr. Priya Nair',   'priya.nair@iitk.ac.in',     1),
    ('Dr. Amit Verma',   'amit.verma@iitk.ac.in',     2),
    ('Dr. Sunita Rao',   'sunita.rao@iitk.ac.in',     3);


-- ============================================================
-- COURSES (8)
-- Edge cases embedded:
--   CS201: capacity=3 → will be filled to 100% (seat-limit test)
--   CS101 & EE201: same MWF 09:00-10:00 → schedule-conflict pair
--   CS315 & MTH201: same TTH 09:30-11:00 → second conflict pair
-- ============================================================
INSERT INTO Courses (course_code, title, credits, dept_id, instructor_id,
                     capacity, enrolled_count,
                     schedule_day, schedule_start, schedule_end) VALUES
    ('CS101',  'Introduction to Programming',        3, 1, 1,  30, 0, 'MWF', '09:00', '10:00'),
    ('CS201',  'Data Structures',                    3, 1, 1,   3, 0, 'MWF', '10:00', '11:00'),
    ('CS315',  'Database Systems Management',        3, 1, 2,   5, 0, 'TTH', '09:30', '11:00'),
    ('CS401',  'Machine Learning',                   3, 1, 2,  20, 0, 'MWF', '14:00', '15:00'),
    ('EE201',  'Circuit Analysis',                   4, 2, 3,  25, 0, 'MWF', '09:00', '10:00'),
    ('EE301',  'Signals and Systems',                4, 2, 3,  20, 0, 'TTH', '14:00', '15:30'),
    ('MTH101', 'Calculus',                           4, 3, 4,  40, 0, 'MWF', '11:00', '12:00'),
    ('MTH201', 'Linear Algebra',                     4, 3, 4,  30, 0, 'TTH', '09:30', '11:00');


-- ============================================================
-- PREREQUISITES
--   CS201  → CS101
--   CS315  → CS201
--   CS401  → CS315, MTH201
--   MTH201 → MTH101
-- ============================================================
INSERT INTO Prerequisites (course_id, prereq_course_id) VALUES
    (2, 1),   -- CS201 requires CS101
    (3, 2),   -- CS315 requires CS201
    (4, 3),   -- CS401 requires CS315
    (4, 8),   -- CS401 requires MTH201
    (8, 7);   -- MTH201 requires MTH101


-- ============================================================
-- STUDENTS (10)
-- ============================================================
INSERT INTO Students (roll_no, name, email, dept_id, year_of_study) VALUES
    ('22CS001',  'Alice Sharma',   'alice@iitk.ac.in',   1, 2),
    ('21CS002',  'Bob Mehta',      'bob@iitk.ac.in',     1, 3),
    ('23EE001',  'Charlie Roy',    'charlie@iitk.ac.in', 2, 1),
    ('22MTH001', 'Diana Krishnan', 'diana@iitk.ac.in',   3, 2),
    ('22CS003',  'Eve Patel',      'eve@iitk.ac.in',     1, 2),
    ('21EE002',  'Frank Joshi',    'frank@iitk.ac.in',   2, 3),
    ('23CS004',  'Grace Singh',    'grace@iitk.ac.in',   1, 1),
    ('21MTH002', 'Henry Thomas',   'henry@iitk.ac.in',   3, 3),
    ('22CS005',  'Iris Kapoor',    'iris@iitk.ac.in',    1, 2),
    ('22EE003',  'Jack Nambiar',   'jack@iitk.ac.in',    2, 2);


-- ============================================================
-- ENROLLMENTS
-- Historical (status = 'completed') — used for prereq verification.
-- Current semester (status = 'enrolled').
-- 15 active 'enrolled' rows; CS201 filled to its capacity of 3.
-- ============================================================

-- Bob's completed history (year-3 CS student)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (2, 1, 'completed'),   -- Bob – CS101
    (2, 2, 'completed'),   -- Bob – CS201
    (2, 3, 'completed'),   -- Bob – CS315
    (2, 7, 'completed'),   -- Bob – MTH101
    (2, 8, 'completed');   -- Bob – MTH201

-- Alice's completed history
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (1, 1, 'completed'),   -- Alice – CS101
    (1, 7, 'completed');   -- Alice – MTH101

-- Eve's completed history (prereqs for CS315)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (5, 1, 'completed'),   -- Eve – CS101
    (5, 2, 'completed');   -- Eve – CS201

-- Other completed prereqs
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (7, 1, 'completed'),   -- Grace – CS101
    (9, 1, 'completed'),   -- Iris  – CS101
    (4, 7, 'completed'),   -- Diana – MTH101
    (8, 7, 'completed');   -- Henry – MTH101

-- ── Current semester active enrollments (15 rows) ────────────

-- CS101: Charlie, Grace (2 of 30 seats)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (3, 1, 'enrolled'),   -- Charlie – CS101
    (7, 7, 'enrolled');   -- Grace   – MTH101 (also add here for count)

-- CS201: Alice, Grace, Iris → capacity 3 → FULL (edge case #1)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (1, 2, 'enrolled'),   -- Alice – CS201
    (7, 2, 'enrolled'),   -- Grace – CS201
    (9, 2, 'enrolled');   -- Iris  – CS201   ← fills to capacity

-- CS315: Eve (prereq CS201 ✓ completed)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (5, 3, 'enrolled');   -- Eve – CS315

-- CS401: Bob (prereq CS315 ✓ MTH201 ✓)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (2, 4, 'enrolled');   -- Bob – CS401

-- EE201 & EE301: Frank, Jack
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (6, 5, 'enrolled'),   -- Frank – EE201
    (6, 6, 'enrolled'),   -- Frank – EE301
    (10, 5, 'enrolled'),  -- Jack  – EE201
    (10, 6, 'enrolled');  -- Jack  – EE301

-- MTH101: Alice, Charlie
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (1, 7, 'enrolled'),   -- Alice   – MTH101
    (3, 7, 'enrolled');   -- Charlie – MTH101

-- MTH201: Diana (prereq MTH101 ✓), Henry (prereq MTH101 ✓)
INSERT INTO Enrollments (student_id, course_id, status) VALUES
    (4, 8, 'enrolled'),   -- Diana – MTH201
    (8, 8, 'enrolled');   -- Henry – MTH201


-- ============================================================
-- Sync enrolled_count with actual 'enrolled' rows.
-- This compensates for the triggers not being installed yet.
-- ============================================================
UPDATE Courses c
SET enrolled_count = (
    SELECT COUNT(*)
    FROM Enrollments e
    WHERE e.course_id = c.course_id
      AND e.status = 'enrolled'
);

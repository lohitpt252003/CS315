-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 1: ER Design & Schema Definition
-- Database: PostgreSQL (compatible with MySQL with minor syntax changes)

-- ============================================================
-- DROP (safe re-run) — reverse dependency order
-- ============================================================
DROP TABLE IF EXISTS Enrollments   CASCADE;
DROP TABLE IF EXISTS Prerequisites CASCADE;
DROP TABLE IF EXISTS Students      CASCADE;
DROP TABLE IF EXISTS Courses       CASCADE;
DROP TABLE IF EXISTS Instructors   CASCADE;
DROP TABLE IF EXISTS Departments   CASCADE;


-- ============================================================
-- 1. DEPARTMENTS
-- No FK dependencies — create first.
-- ============================================================
CREATE TABLE Departments (
    dept_id    SERIAL       PRIMARY KEY,
    dept_name  VARCHAR(100) NOT NULL UNIQUE,
    dept_code  CHAR(4)      NOT NULL UNIQUE   -- e.g. 'CS', 'EE', 'MTH'
);


-- ============================================================
-- 2. INSTRUCTORS
-- Each instructor belongs to one department (many-to-one).
-- ============================================================
CREATE TABLE Instructors (
    instructor_id SERIAL       PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    dept_id       INT          NOT NULL REFERENCES Departments(dept_id)
);


-- ============================================================
-- 3. COURSES
-- schedule_day  : 'MWF', 'TTH', 'MW', 'F' — days class meets
-- schedule_start/end: enables SQL-level conflict detection
-- enrolled_count: maintained by trigger (added in M5);
--                 stored here so seat-limit CHECK is instant.
-- ============================================================
CREATE TABLE Courses (
    course_id       SERIAL       PRIMARY KEY,
    course_code     VARCHAR(10)  NOT NULL UNIQUE,  -- e.g. 'CS315'
    title           VARCHAR(150) NOT NULL,
    credits         SMALLINT     NOT NULL CHECK (credits BETWEEN 1 AND 5),
    dept_id         INT          NOT NULL REFERENCES Departments(dept_id),
    instructor_id   INT          REFERENCES Instructors(instructor_id),
    capacity        INT          NOT NULL CHECK (capacity > 0),
    enrolled_count  INT          NOT NULL DEFAULT 0,
    schedule_day    VARCHAR(10)  NOT NULL,  -- 'MWF' | 'TTH' | 'MW' | 'F'
    schedule_start  TIME         NOT NULL,
    schedule_end    TIME         NOT NULL,

    CONSTRAINT chk_schedule_order  CHECK (schedule_end > schedule_start),
    CONSTRAINT chk_seat_count      CHECK (enrolled_count >= 0),
    CONSTRAINT chk_capacity_limit  CHECK (enrolled_count <= capacity)

);


-- ============================================================
-- 4. PREREQUISITES
-- Separate table to support multiple prerequisites per course.
-- Self-referential many-to-many on Courses.
-- ON DELETE CASCADE: if a course is deleted, its prereq records go too.
-- ============================================================
CREATE TABLE Prerequisites (
    course_id        INT NOT NULL REFERENCES Courses(course_id) ON DELETE CASCADE,
    prereq_course_id INT NOT NULL REFERENCES Courses(course_id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, prereq_course_id),
    CONSTRAINT no_self_prereq CHECK (course_id <> prereq_course_id)
);


-- ============================================================
-- 5. STUDENTS
-- roll_no: institution-assigned identifier (e.g. '22CS0001')
-- year_of_study: 1-5 (UG 4yr + dual degree 5yr)
-- ============================================================
CREATE TABLE Students (
    student_id    SERIAL       PRIMARY KEY,
    roll_no       VARCHAR(20)  NOT NULL UNIQUE,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    dept_id       INT          NOT NULL REFERENCES Departments(dept_id),
    year_of_study SMALLINT     NOT NULL CHECK (year_of_study BETWEEN 1 AND 5)
);


-- ============================================================
-- 6. ENROLLMENTS
-- Junction table resolving the Students <-> Courses many-to-many.
-- UNIQUE(student_id, course_id) prevents duplicate enrollments.
-- status tracks lifecycle: enrolled → dropped / waitlisted
-- Business rules (seat limit, prereqs, conflicts) enforced by
-- triggers in M5; CHECK here guards status values.
-- ============================================================
CREATE TABLE Enrollments (
    enrollment_id SERIAL      PRIMARY KEY,
    student_id    INT         NOT NULL REFERENCES Students(student_id) ON DELETE CASCADE,
    course_id     INT         NOT NULL REFERENCES Courses(course_id)  ON DELETE CASCADE,
    enrolled_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
    status        VARCHAR(15) NOT NULL DEFAULT 'enrolled'
                  CHECK (status IN ('enrolled', 'dropped', 'waitlisted', 'completed')),

    UNIQUE (student_id, course_id)
);


-- ============================================================
-- NORMALIZATION NOTES
-- ============================================================
-- 1NF: All columns hold atomic values; no repeating groups.
--      Prerequisites stored in a separate table (not as a CSV in Courses).
--
-- 2NF: Every non-key attribute depends on the whole primary key.
--      Enrollments(student_id, course_id) → enrolled_at, status — full dependency.
--      No partial dependencies exist (all PKs are single-column except Prerequisites).
--
-- 3NF: No transitive dependencies.
--      dept_name is in Departments, NOT duplicated in Students/Courses.
--      instructor details are in Instructors, NOT duplicated in Courses.
--      If dept_code were stored in both Departments and Courses, that would
--      violate 3NF (Courses.dept_code → Departments.dept_name transitively).
--      We avoided this by using FK references everywhere.

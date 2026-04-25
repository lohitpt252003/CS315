-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 3: Business Logic & Constraints
-- Run after: schema.sql, seed.sql

-- ============================================================
-- CONSTRAINT TRIGGER: check all three rules before enrollment
--
-- Fires BEFORE INSERT on Enrollments (when status = 'enrolled').
-- Raises an exception (aborting the insert) if any rule fails:
--   1. Seat limit  — enrolled_count >= capacity
--   2. Prerequisites — student has not completed all prereqs
--   3. Schedule conflict — timeslot overlaps an existing course
--
-- Note on schedule-day matching: the conflict check uses exact
-- schedule_day string equality (e.g. 'MWF' = 'MWF'). Courses
-- on day patterns that share individual days but differ as strings
-- (e.g. 'MWF' vs 'MW') are treated as non-conflicting. This is a
-- deliberate simplification for this project scope.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_check_enrollment_constraints()
RETURNS TRIGGER AS $$
DECLARE
    v_capacity      INT;
    v_enrolled      INT;
    v_prereq_total  INT;
    v_prereq_met    INT;
    v_conflicts     INT;
BEGIN
    -- ── 1. Seat limit ──────────────────────────────────────────
    SELECT capacity, enrolled_count
      INTO v_capacity, v_enrolled
      FROM Courses
     WHERE course_id = NEW.course_id;

    IF v_enrolled >= v_capacity THEN
        RAISE EXCEPTION
            'Enrollment rejected: course % is full (% / % seats occupied).',
            NEW.course_id, v_enrolled, v_capacity;
    END IF;

    -- ── 2. Prerequisites ───────────────────────────────────────
    SELECT COUNT(*) INTO v_prereq_total
      FROM Prerequisites
     WHERE course_id = NEW.course_id;

    IF v_prereq_total > 0 THEN
        SELECT COUNT(*) INTO v_prereq_met
          FROM Prerequisites p
         WHERE p.course_id = NEW.course_id
           AND EXISTS (
               SELECT 1
                 FROM Enrollments e
                WHERE e.student_id = NEW.student_id
                  AND e.course_id  = p.prereq_course_id
                  AND e.status     = 'completed'
           );

        IF v_prereq_met < v_prereq_total THEN
            RAISE EXCEPTION
                'Enrollment rejected: student % has not completed all prerequisites for course %.',
                NEW.student_id, NEW.course_id;
        END IF;
    END IF;

    -- ── 3. Schedule conflict ───────────────────────────────────
    SELECT COUNT(*) INTO v_conflicts
      FROM Enrollments  en
      JOIN Courses       c_existing ON en.course_id = c_existing.course_id
      JOIN Courses       c_new      ON c_new.course_id = NEW.course_id
     WHERE en.student_id        = NEW.student_id
       AND en.status            = 'enrolled'
       AND en.course_id        <> NEW.course_id
       AND c_existing.schedule_day   = c_new.schedule_day
       AND c_existing.schedule_start < c_new.schedule_end
       AND c_new.schedule_start      < c_existing.schedule_end;

    IF v_conflicts > 0 THEN
        RAISE EXCEPTION
            'Enrollment rejected: student % has a schedule conflict with course %.',
            NEW.student_id, NEW.course_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_enrollment
BEFORE INSERT ON Enrollments
FOR EACH ROW
WHEN (NEW.status = 'enrolled')
EXECUTE FUNCTION fn_check_enrollment_constraints();


-- ============================================================
-- TEST CASES
-- Each DO block expects a specific outcome; a NOTICE confirms it.
-- ============================================================

-- ── Test 1: Full course (should FAIL) ─────────────────────────
-- CS201 is at capacity 3; a 4th enrollee must be rejected.
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 2, 'enrolled');   -- Charlie tries CS201 (full)
    RAISE NOTICE 'Test 1 FAILED — insert should have been rejected.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 1 PASSED — seat limit enforced: %', SQLERRM;
END $$;


-- ── Test 2: Missing prerequisite (should FAIL) ────────────────
-- Charlie (year-1) has not completed CS201; CS315 requires it.
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 3, 'enrolled');   -- Charlie tries CS315 without CS201
    RAISE NOTICE 'Test 2 FAILED — insert should have been rejected.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 2 PASSED — prereq enforced: %', SQLERRM;
END $$;


-- ── Test 3: Schedule conflict (should FAIL) ───────────────────
-- Charlie is enrolled in CS101 (MWF 09:00-10:00).
-- EE201 is also MWF 09:00-10:00 → overlap.
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 5, 'enrolled');   -- Charlie tries EE201 (same slot as CS101)
    RAISE NOTICE 'Test 3 FAILED — insert should have been rejected.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 3 PASSED — schedule conflict enforced: %', SQLERRM;
END $$;


-- ── Test 4: Valid enrollment (should SUCCEED, then rolled back) ─
-- Charlie can enroll in EE301 (TTH 14:00-15:30) — no issues.
DO $$
BEGIN
    SAVEPOINT sp_test4;
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 6, 'enrolled');   -- Charlie enrolls in EE301 ✓
    RAISE NOTICE 'Test 4 PASSED — valid enrollment accepted.';
    ROLLBACK TO SAVEPOINT sp_test4;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 4 FAILED — unexpected rejection: %', SQLERRM;
END $$;

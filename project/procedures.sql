-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Stored Procedures
-- Run after: schema.sql, seed.sql, constraints.sql, triggers.sql

-- ============================================================
-- FUNCTION: check_conflicts(student_id, course_id) → BOOLEAN
--
-- Returns TRUE if it is safe to enroll the student in the course.
-- Returns FALSE (with a NOTICE explaining why) otherwise.
-- Checks: seat availability, prerequisites, schedule conflicts.
--
-- Usage:
--   SELECT check_conflicts(3, 6);   -- Can Charlie enroll in EE301?
-- ============================================================

CREATE OR REPLACE FUNCTION check_conflicts(
    p_student_id INT,
    p_course_id  INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    v_capacity      INT;
    v_enrolled      INT;
    v_course_code   VARCHAR;
    v_prereq_total  INT;
    v_prereq_met    INT;
    v_conflicts     INT;
    v_conflict_code VARCHAR;
BEGIN
    -- ── Seat availability ──────────────────────────────────────
    SELECT course_code, capacity, enrolled_count
      INTO v_course_code, v_capacity, v_enrolled
      FROM Courses
     WHERE course_id = p_course_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'check_conflicts: course % does not exist.', p_course_id;
        RETURN FALSE;
    END IF;

    IF v_enrolled >= v_capacity THEN
        RAISE NOTICE 'BLOCKED: % is full (% / % seats).', v_course_code, v_enrolled, v_capacity;
        RETURN FALSE;
    END IF;

    -- ── Prerequisites ──────────────────────────────────────────
    SELECT COUNT(*) INTO v_prereq_total
      FROM Prerequisites
     WHERE course_id = p_course_id;

    IF v_prereq_total > 0 THEN
        SELECT COUNT(*) INTO v_prereq_met
          FROM Prerequisites p
         WHERE p.course_id = p_course_id
           AND EXISTS (
               SELECT 1
                 FROM Enrollments e
                WHERE e.student_id = p_student_id
                  AND e.course_id  = p.prereq_course_id
                  AND e.status     = 'completed'
           );

        IF v_prereq_met < v_prereq_total THEN
            RAISE NOTICE 'BLOCKED: student % has not completed all prerequisites for %.', p_student_id, v_course_code;
            RETURN FALSE;
        END IF;
    END IF;

    -- ── Schedule conflict ──────────────────────────────────────
    SELECT COUNT(*), MIN(c_ex.course_code)
      INTO v_conflicts, v_conflict_code
      FROM Enrollments  en
      JOIN Courses       c_ex  ON en.course_id    = c_ex.course_id
      JOIN Courses       c_new ON c_new.course_id = p_course_id
     WHERE en.student_id        = p_student_id
       AND en.status            = 'enrolled'
       AND en.course_id        <> p_course_id
       AND c_ex.schedule_day   = c_new.schedule_day
       AND c_ex.schedule_start < c_new.schedule_end
       AND c_new.schedule_start < c_ex.schedule_end;

    IF v_conflicts > 0 THEN
        RAISE NOTICE 'BLOCKED: % conflicts with already-enrolled course %.', v_course_code, v_conflict_code;
        RETURN FALSE;
    END IF;

    RAISE NOTICE 'OK: student % can enroll in %.', p_student_id, v_course_code;
    RETURN TRUE;
END;
$$;


-- ============================================================
-- PROCEDURE: enroll_student(student_id, course_id)
--
-- Wraps the full enrollment flow in a single callable procedure.
-- Uses check_conflicts() as a pre-flight check, then inserts.
-- ============================================================

CREATE OR REPLACE PROCEDURE enroll_student(
    p_student_id INT,
    p_course_id  INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT check_conflicts(p_student_id, p_course_id) THEN
        RAISE EXCEPTION 'Enrollment aborted: see NOTICE above for details.';
    END IF;

    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (p_student_id, p_course_id, 'enrolled');

    RAISE NOTICE 'Enrollment successful: student % → course %.', p_student_id, p_course_id;
END;
$$;


-- ============================================================
-- TEST CALLS
-- ============================================================

-- Should return FALSE (CS201 is full)
SELECT check_conflicts(3, 2) AS can_enroll_charlie_cs201;

-- Should return FALSE (Charlie missing CS201 prereq for CS315)
SELECT check_conflicts(3, 3) AS can_enroll_charlie_cs315;

-- Should return FALSE (EE201 conflicts with Charlie's CS101 timeslot)
SELECT check_conflicts(3, 5) AS can_enroll_charlie_ee201;

-- Should return TRUE (EE301 is fine for Charlie)
SELECT check_conflicts(3, 6) AS can_enroll_charlie_ee301;

-- Test the procedure for a valid case (wrapped so it rolls back)
DO $$
BEGIN
    SAVEPOINT sp_proc;
    CALL enroll_student(3, 6);   -- Charlie → EE301 (valid)
    ROLLBACK TO SAVEPOINT sp_proc;
END $$;

-- Test the procedure for an invalid case
DO $$
BEGIN
    CALL enroll_student(3, 2);   -- Charlie → CS201 (full)
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Procedure correctly rejected: %', SQLERRM;
END $$;

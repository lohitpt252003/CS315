-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Stored Procedures
-- run after schema.sql, seed.sql, constraints.sql, triggers.sql

-- check_conflicts() is a helper function that does all three checks
-- and returns TRUE if its safe to enroll, FALSE if not.
-- Useful for checking before actually doing the insert.
--
-- usage: SELECT check_conflicts(3, 6);  -- can Charlie enroll in EE301?

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
    -- check if course even exists and get its seat info
    SELECT course_code, capacity, enrolled_count
      INTO v_course_code, v_capacity, v_enrolled
      FROM Courses
     WHERE course_id = p_course_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'check_conflicts: course % not found.', p_course_id;
        RETURN FALSE;
    END IF;

    -- seat check
    IF v_enrolled >= v_capacity THEN
        RAISE NOTICE 'BLOCKED: % is full (% / % seats).', v_course_code, v_enrolled, v_capacity;
        RETURN FALSE;
    END IF;

    -- prereq check - same logic as in the trigger
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
            RAISE NOTICE 'BLOCKED: student % hasnt completed all prereqs for %.', p_student_id, v_course_code;
            RETURN FALSE;
        END IF;
    END IF;

    -- schedule conflict check
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
        RAISE NOTICE 'BLOCKED: % clashes with %.', v_course_code, v_conflict_code;
        RETURN FALSE;
    END IF;

    RAISE NOTICE 'OK: student % can enroll in %.', p_student_id, v_course_code;
    RETURN TRUE;
END;
$$;


-- enroll_student() wraps the whole flow into one callable procedure
-- calls check_conflicts first, then does the insert if all good

CREATE OR REPLACE PROCEDURE enroll_student(
    p_student_id INT,
    p_course_id  INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT check_conflicts(p_student_id, p_course_id) THEN
        RAISE EXCEPTION 'Enrollment aborted — check the notices above for reason.';
    END IF;

    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (p_student_id, p_course_id, 'enrolled');

    RAISE NOTICE 'Done: student % enrolled in course %.', p_student_id, p_course_id;
END;
$$;


-- test the function with a few cases

-- should be FALSE — CS201 is full
SELECT check_conflicts(3, 2) AS can_charlie_enroll_cs201;

-- should be FALSE — Charlie doesnt have CS201 completed
SELECT check_conflicts(3, 3) AS can_charlie_enroll_cs315;

-- should be FALSE — EE201 clashes with CS101
SELECT check_conflicts(3, 5) AS can_charlie_enroll_ee201;

-- should be TRUE — EE301 is fine
SELECT check_conflicts(3, 6) AS can_charlie_enroll_ee301;

-- test the procedure with a valid case, rollback after so data isnt changed
DO $$
BEGIN
    SAVEPOINT sp_proc;
    CALL enroll_student(3, 6);
    ROLLBACK TO SAVEPOINT sp_proc;
END $$;

-- test the procedure with an invalid case — should print the notice and raise exception
DO $$
BEGIN
    CALL enroll_student(3, 2);   -- CS201 is full
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Procedure blocked enrollment as expected: %', SQLERRM;
END $$;

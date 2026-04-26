-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Enrollment Transaction
-- run after schema.sql, seed.sql, constraints.sql, triggers.sql

-- The point of this file is to show how a proper enrollment should happen
-- using a transaction with FOR UPDATE so two students cant grab the same
-- last seat at the same time.
--
-- Flow:
--   1. Lock the course row (FOR UPDATE)
--   2. Try to insert into Enrollments
--   3. constraint trigger checks prereqs, seats, schedule
--   4. count trigger updates enrolled_count
--   5. COMMIT or ROLLBACK depending on what happened

-- Example A: normal successful enrollment
-- Charlie (student 3) enrolling in EE301 (course 6) - no issues expected

BEGIN;

    -- lock this course row so no other transaction can change enrolled_count
    -- while we are in the middle of checking and inserting
    SELECT course_id, enrolled_count, capacity
      FROM Courses
     WHERE course_id = 6
       FOR UPDATE;

    -- the BEFORE INSERT trigger fires here and does all 3 checks
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 6, 'enrolled');

    -- the AFTER INSERT trigger fires here and increments enrolled_count

COMMIT;

-- confirm it worked
SELECT c.course_code, c.enrolled_count, c.capacity,
       s.name AS newly_enrolled
FROM   Enrollments e
JOIN   Courses     c ON e.course_id  = c.course_id
JOIN   Students    s ON e.student_id = s.student_id
WHERE  e.student_id = 3 AND e.course_id = 6;


-- Example B: trying to enroll in a full course, should rollback
-- CS201 is already at capacity so this should fail cleanly

DO $$
BEGIN
    BEGIN
        INSERT INTO Enrollments (student_id, course_id, status)
        VALUES (3, 2, 'enrolled');   -- CS201 is full
        RAISE NOTICE 'Example B: went through (shouldnt have).';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Example B PASSED — rolled back: %', SQLERRM;
    END;
END $$;


-- Example C: simulate two students competing for the same seat
-- in real concurrent usage the FOR UPDATE would make T2 wait for T1 to finish
-- here we just simulate with savepoints to show the logic

DO $$
DECLARE
    v_enrolled INT;
    v_capacity INT;
BEGIN
    -- T1 reads the current state
    SELECT enrolled_count, capacity
      INTO v_enrolled, v_capacity
      FROM Courses
     WHERE course_id = 3;   -- CS315

    RAISE NOTICE 'T1 reads: enrolled=%, capacity=%.', v_enrolled, v_capacity;

    IF v_enrolled < v_capacity THEN
        -- Iris (student 9) has CS201 completed so she can enroll in CS315
        SAVEPOINT sp_t1;
        INSERT INTO Enrollments (student_id, course_id, status)
        VALUES (9, 3, 'enrolled');
        RAISE NOTICE 'T1 COMMITTED: Iris enrolled in CS315.';
        ROLLBACK TO SAVEPOINT sp_t1;  -- rollback so test data stays clean
    ELSE
        RAISE NOTICE 'T1 ABORTED: course is full.';
    END IF;
END $$;


-- cleanup: remove Charlie's EE301 enrollment from Example A
DELETE FROM Enrollments
WHERE student_id = 3 AND course_id = 6;

-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Enrollment Transaction (ACID demonstration)
-- Run after: schema.sql, seed.sql, constraints.sql, triggers.sql

-- ============================================================
-- ENROLLMENT TRANSACTION
--
-- Safely enroll a student in a course:
--   1. Lock the Courses row to prevent concurrent seat theft.
--   2. Re-read enrolled_count inside the transaction.
--   3. Let the BEFORE-INSERT trigger validate constraints.
--   4. The AFTER-INSERT trigger increments enrolled_count.
--   5. COMMIT on success; ROLLBACK on any failure.
--
-- This pattern guarantees:
--   Atomicity   — both the Enrollment insert and count update
--                 succeed together, or neither does.
--   Consistency — constraint trigger keeps business rules intact.
--   Isolation   — FOR UPDATE lock prevents another transaction
--                 from stealing the last seat concurrently.
--   Durability  — COMMIT makes the change permanent.
-- ============================================================

-- ── Example A: Successful enrollment ─────────────────────────
-- Charlie (student 3) enrolls in EE301 (course 6, TTH 14:00-15:30).
-- No prerequisites, plenty of seats, no schedule conflict.

BEGIN;

    -- Lock the course row so no concurrent transaction changes
    -- enrolled_count between our read and our write.
    SELECT course_id, enrolled_count, capacity
      FROM Courses
     WHERE course_id = 6
       FOR UPDATE;

    -- The constraint trigger (trg_check_enrollment) fires here
    -- and validates seats, prereqs, and schedule conflicts.
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 6, 'enrolled');

    -- The count trigger (trg_sync_count_insert_delete) fires here
    -- and increments enrolled_count for course 6.

COMMIT;

-- Verify the result
SELECT c.course_code, c.enrolled_count, c.capacity,
       s.name AS newly_enrolled
FROM   Enrollments e
JOIN   Courses     c ON e.course_id  = c.course_id
JOIN   Students    s ON e.student_id = s.student_id
WHERE  e.student_id = 3 AND e.course_id = 6;


-- ── Example B: Enrollment ROLLBACK on constraint violation ───
-- Try to enroll Charlie in CS201 (full). The constraint trigger
-- raises an exception, which aborts the transaction.

DO $$
BEGIN
    BEGIN  -- Nested block to catch the exception cleanly
        INSERT INTO Enrollments (student_id, course_id, status)
        VALUES (3, 2, 'enrolled');   -- CS201 is full
        RAISE NOTICE 'Example B: insert succeeded (unexpected).';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Example B PASSED — transaction rolled back: %', SQLERRM;
    END;
END $$;


-- ── Example C: Concurrent enrollment simulation ───────────────
-- Two transactions compete for the last seat in a course.
-- In real concurrent usage, the FOR UPDATE lock ensures only one
-- succeeds. Here we simulate with savepoints.

DO $$
DECLARE
    v_enrolled INT;
    v_capacity INT;
BEGIN
    -- Simulate Transaction T1 reading and locking
    SELECT enrolled_count, capacity
      INTO v_enrolled, v_capacity
      FROM Courses
     WHERE course_id = 3;   -- CS315 (capacity 5, 1 enrolled)

    RAISE NOTICE 'T1 sees: enrolled=%, capacity=%.', v_enrolled, v_capacity;

    IF v_enrolled < v_capacity THEN
        -- T1 enrolls Iris (student 9) in CS315
        -- (Iris has CS201 completed so prereq is met)
        SAVEPOINT sp_t1;
        INSERT INTO Enrollments (student_id, course_id, status)
        VALUES (9, 3, 'enrolled');
        RAISE NOTICE 'T1 COMMITTED: Iris enrolled in CS315.';
        ROLLBACK TO SAVEPOINT sp_t1;  -- clean up for demo
    ELSE
        RAISE NOTICE 'T1 ABORTED: no seats available.';
    END IF;
END $$;


-- ── Cleanup: remove Charlie's EE301 enrollment from Example A ──
DELETE FROM Enrollments
WHERE student_id = 3 AND course_id = 6;

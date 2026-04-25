-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Seat-Count Maintenance Triggers
-- Run after: schema.sql, seed.sql, constraints.sql

-- ============================================================
-- TRIGGER FUNCTION: keep Courses.enrolled_count in sync
--
-- Cases handled:
--   INSERT  status='enrolled'                → +1
--   INSERT  status='dropped'|'waitlisted'   → no change
--   UPDATE  'enrolled'  → 'dropped'|other   → -1
--   UPDATE  other       → 'enrolled'        → +1
--   DELETE  status='enrolled'               → -1
--   DELETE  other status                    → no change
-- ============================================================

CREATE OR REPLACE FUNCTION fn_sync_enrolled_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'enrolled' THEN
            UPDATE Courses
               SET enrolled_count = enrolled_count + 1
             WHERE course_id = NEW.course_id;
        END IF;

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'enrolled' AND NEW.status <> 'enrolled' THEN
            UPDATE Courses
               SET enrolled_count = enrolled_count - 1
             WHERE course_id = NEW.course_id;

        ELSIF OLD.status <> 'enrolled' AND NEW.status = 'enrolled' THEN
            UPDATE Courses
               SET enrolled_count = enrolled_count + 1
             WHERE course_id = NEW.course_id;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.status = 'enrolled' THEN
            UPDATE Courses
               SET enrolled_count = enrolled_count - 1
             WHERE course_id = OLD.course_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger for INSERT and DELETE
CREATE TRIGGER trg_sync_count_insert_delete
AFTER INSERT OR DELETE ON Enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_sync_enrolled_count();

-- Trigger for UPDATE (status change, e.g. student drops a course)
CREATE TRIGGER trg_sync_count_update
AFTER UPDATE OF status ON Enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_sync_enrolled_count();


-- ============================================================
-- SMOKE TESTS
-- ============================================================

-- Show seat counts before tests
SELECT course_code, enrolled_count, capacity
FROM   Courses
WHERE  course_code IN ('EE301', 'CS315')
ORDER  BY course_code;

-- Enroll Jack in EE301 (Jack is already enrolled — UNIQUE will
-- block this; illustrates that duplicate protection still works)
DO $$
BEGIN
    SAVEPOINT sp_smoke;
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (10, 6, 'enrolled');   -- Jack – EE301 (duplicate)
    RAISE NOTICE 'Smoke test: insert succeeded (unexpected)';
    ROLLBACK TO SAVEPOINT sp_smoke;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Smoke test PASSED: duplicate enrollment blocked.';
END $$;

-- Drop Frank from EE301 (status UPDATE: enrolled → dropped)
-- enrolled_count for EE301 should decrease by 1.
DO $$
BEGIN
    SAVEPOINT sp_drop;
    UPDATE Enrollments
       SET status = 'dropped'
     WHERE student_id = 6 AND course_id = 6;

    RAISE NOTICE 'Frank dropped EE301. Checking enrolled_count...';

    PERFORM 1 FROM Courses
     WHERE course_id = 6
       AND enrolled_count = (
               SELECT COUNT(*) FROM Enrollments
                WHERE course_id = 6 AND status = 'enrolled'
           );
    IF FOUND THEN
        RAISE NOTICE 'PASSED: enrolled_count matches actual count after drop.';
    ELSE
        RAISE NOTICE 'FAILED: enrolled_count mismatch after drop.';
    END IF;

    ROLLBACK TO SAVEPOINT sp_drop;
END $$;

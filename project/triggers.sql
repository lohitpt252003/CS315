-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 5: Seat Count Trigger
-- run after schema.sql, seed.sql, constraints.sql

-- This trigger keeps enrolled_count in the Courses table accurate.
-- Whenever someone enrolls, drops, or changes status the count gets updated.
-- Without this the seat limit CHECK constraint wont work properly since
-- enrolled_count would never change.
--
-- basically handles these cases:
--   INSERT with status='enrolled'       -> +1
--   INSERT with any other status        -> no change
--   UPDATE from 'enrolled' to something -> -1
--   UPDATE to 'enrolled' from something -> +1
--   DELETE where status was 'enrolled'  -> -1
--   DELETE any other status             -> no change

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
        -- student dropped the course
        IF OLD.status = 'enrolled' AND NEW.status <> 'enrolled' THEN
            UPDATE Courses
               SET enrolled_count = enrolled_count - 1
             WHERE course_id = NEW.course_id;

        -- student re-enrolled or moved from waitlist to enrolled
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


-- one trigger for inserts and deletes
CREATE TRIGGER trg_sync_count_insert_delete
AFTER INSERT OR DELETE ON Enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_sync_enrolled_count();

-- separate trigger for updates since status can change without insert/delete
CREATE TRIGGER trg_sync_count_update
AFTER UPDATE OF status ON Enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_sync_enrolled_count();


-- quick checks to make sure the trigger is working

-- see counts before anything
SELECT course_code, enrolled_count, capacity
FROM   Courses
WHERE  course_code IN ('EE301', 'CS315')
ORDER  BY course_code;

-- try inserting Jack into EE301 again — should fail because of UNIQUE constraint
-- just checking duplicate protection still works alongside the trigger
DO $$
BEGIN
    SAVEPOINT sp_smoke;
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (10, 6, 'enrolled');   -- Jack is already in EE301
    RAISE NOTICE 'Smoke test: insert went through (not expected)';
    ROLLBACK TO SAVEPOINT sp_smoke;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Smoke test PASSED: duplicate enrollment blocked as expected.';
END $$;

-- drop Frank from EE301 and verify enrolled_count goes down by 1
DO $$
BEGIN
    SAVEPOINT sp_drop;
    UPDATE Enrollments
       SET status = 'dropped'
     WHERE student_id = 6 AND course_id = 6;

    RAISE NOTICE 'Frank dropped EE301. Checking count...';

    -- verify count matches actual number of active enrollments
    PERFORM 1 FROM Courses
     WHERE course_id = 6
       AND enrolled_count = (
               SELECT COUNT(*) FROM Enrollments
                WHERE course_id = 6 AND status = 'enrolled'
           );
    IF FOUND THEN
        RAISE NOTICE 'PASSED: enrolled_count is correct after drop.';
    ELSE
        RAISE NOTICE 'FAILED: enrolled_count is wrong after drop.';
    END IF;

    ROLLBACK TO SAVEPOINT sp_drop;
END $$;

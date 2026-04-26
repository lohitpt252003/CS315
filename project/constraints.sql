-- CS315 Project: Smart Course Registration and Scheduling System
-- Milestone 3: Business Logic and Constraints
-- run this after schema.sql and seed.sql

-- This trigger runs BEFORE a student is inserted into Enrollments.
-- It checks three things in order:
--   1. Is the course full?
--   2. Has the student completed all prerequisites?
--   3. Does the timeslot clash with something they are already in?
-- If any of these fail it raises an exception and the insert is cancelled.
--
-- Note: schedule conflict check only works if the schedule_day string
-- is exactly same (like 'MWF' == 'MWF'). If one course is 'MWF' and
-- another is 'MW' it wont detect the overlap. I know this is a limitation,
-- kept it simple for now.

CREATE OR REPLACE FUNCTION fn_check_enrollment_constraints()
RETURNS TRIGGER AS $$
DECLARE
    v_capacity      INT;
    v_enrolled      INT;
    v_prereq_total  INT;
    v_prereq_met    INT;
    v_conflicts     INT;
BEGIN
    -- check 1: is the course full?
    SELECT capacity, enrolled_count
      INTO v_capacity, v_enrolled
      FROM Courses
     WHERE course_id = NEW.course_id;

    IF v_enrolled >= v_capacity THEN
        RAISE EXCEPTION
            'Enrollment rejected: course % is full (% / % seats occupied).',
            NEW.course_id, v_enrolled, v_capacity;
    END IF;

    -- check 2: prerequisites
    -- first count how many prereqs this course has
    SELECT COUNT(*) INTO v_prereq_total
      FROM Prerequisites
     WHERE course_id = NEW.course_id;

    IF v_prereq_total > 0 THEN
        -- now count how many of those the student has actually completed
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

    -- check 3: schedule conflict
    -- using time overlap formula: start1 < end2 AND start2 < end1
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

-- attach the trigger - fires before every insert on Enrollments
-- but only when status is 'enrolled' (no point checking for waitlisted inserts)
CREATE TRIGGER trg_check_enrollment
BEFORE INSERT ON Enrollments
FOR EACH ROW
WHEN (NEW.status = 'enrolled')
EXECUTE FUNCTION fn_check_enrollment_constraints();


-- test cases to verify all three constraints work

-- test 1: CS201 is already at capacity (3/3), 4th student should be rejected
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 2, 'enrolled');   -- Charlie trying CS201
    RAISE NOTICE 'Test 1 FAILED — should have been blocked.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 1 PASSED — seat limit working: %', SQLERRM;
END $$;


-- test 2: Charlie hasn't done CS201 which is required for CS315
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 3, 'enrolled');
    RAISE NOTICE 'Test 2 FAILED — should have been blocked.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 2 PASSED — prereq check working: %', SQLERRM;
END $$;


-- test 3: EE201 is MWF 09:00-10:00, same as CS101 which Charlie is in
DO $$
BEGIN
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 5, 'enrolled');
    RAISE NOTICE 'Test 3 FAILED — should have been blocked.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 3 PASSED — schedule conflict working: %', SQLERRM;
END $$;


-- test 4: EE301 should work fine for Charlie, rolling back after so data stays clean
DO $$
BEGIN
    SAVEPOINT sp_test4;
    INSERT INTO Enrollments (student_id, course_id, status)
    VALUES (3, 6, 'enrolled');
    RAISE NOTICE 'Test 4 PASSED — valid enrollment accepted.';
    ROLLBACK TO SAVEPOINT sp_test4;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 4 FAILED — unexpected error: %', SQLERRM;
END $$;

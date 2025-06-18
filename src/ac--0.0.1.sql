-- Subject represents the user or role
DROP DOMAIN IF EXISTS ac_subject;
CREATE DOMAIN ac_subject TEXT;

-- Operation
-- insert, update, delete, select, ....
DROP DOMAIN IF EXISTS ac_operation;
CREATE DOMAIN ac_operation TEXT;

--- Rule: a set of allowed and denied operations for a specific subject
DROP TYPE IF EXISTS ac_policy CASCADE;
CREATE TYPE ac_policy AS (subject ac_subject, allowed ac_operation[], denied ac_operation[]);

-- Policy: a set of allowed and denied operations for a specific subject
-- The following utility functions are used to create policies

-- Creates a policy with multiple allowed and denied operations
CREATE OR REPLACE FUNCTION ac_policy(ac_subject, ac_operation[], ac_operation[])
    RETURNS ac_policy
    LANGUAGE sql IMMUTABLE AS
    $$ SELECT ROW($1, $2, $3)::ac_policy $$;

-- Creates a policy with multiple allowed operations and no denied operations
CREATE OR REPLACE FUNCTION ac_policy(ac_subject, ac_operation[])
    RETURNS ac_policy
    LANGUAGE sql IMMUTABLE AS
    $$ SELECT ROW($1, $2, null)::ac_policy $$;

-- Creates a policy with a single allowed operation and no denied operations
CREATE OR REPLACE FUNCTION ac_policy(ac_subject, ac_operation[], ac_operation)
    RETURNS ac_policy
    LANGUAGE sql IMMUTABLE AS
    $$ SELECT ROW($1, $2, CASE WHEN $3 IS NOT NULL THEN ARRAY[$3] END)::ac_policy $$;

-- Creates a policy with a single allowed operation and no denied operations
CREATE OR REPLACE FUNCTION ac_policy(ac_subject, ac_operation)
    RETURNS ac_policy
    LANGUAGE sql IMMUTABLE AS
    $$ SELECT ROW($1, CASE WHEN $2 IS NOT NULL THEN ARRAY[$2] END, null)::ac_policy $$;

-- Creates a policy with a single denied operation and no allowed operations
CREATE OR REPLACE FUNCTION ac_policy(ac_subject, ac_operation, ac_operation)
    RETURNS ac_policy
    LANGUAGE sql IMMUTABLE AS
    $$ SELECT ROW($1, CASE WHEN $2 IS NOT NULL THEN ARRAY[$2] END, CASE WHEN $3 IS NOT NULL THEN ARRAY[$3] END)::ac_policy $$;


-- Cleans policy list
--
-- 1. Removes duplicates
-- 2. Removes policies with empty allowed and denied lists
-- 3. Removes denied operations from the allow list
--
-- Should be used when updating the policy list:
--   UPDATE table SET acl = ac_list_cleanup(acl || ac_policy(...));
CREATE OR REPLACE FUNCTION ac_list_cleanup(dirty ac_policy[]) RETURNS ac_policy[] LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
AS $$
DECLARE
    list ac_policy[];
    p    ac_policy;
BEGIN
    -- remove clutter, duplicates and policies with empty values
    -- and sort by the number of denied operations
    WITH uniq AS (
        SELECT d
          FROM unnest(dirty::ac_policy[]) as d(subject, allowed, denied)
         WHERE d.subject IS NOT NULL
           AND NOT (d.allowed IS NULL AND d.denied IS NULL)
         ORDER BY array_length(d.denied, 1) DESC
    ) SELECT array_agg(DISTINCT d) INTO list FROM uniq;

    --
    IF list IS NULL THEN
        -- no policies
        RETURN NULL;
    END IF;


    IF COALESCE(array_length(list,1),0) = 0 THEN
        -- no policies
        RETURN NULL;
    END IF;

    -- remove denied operations from allowed list
    FOR i IN array_lower(list, 1)..array_upper(list, 1) LOOP
        p = list[i];

        -- remove NULL values from allowed and denied lists
        p.allowed := array_remove(p.allowed, NULL);
        p.denied  := array_remove(p.denied, NULL);

        -- one or both sets of ops are empty, no need to go further
        CONTINUE WHEN p.denied IS NULL OR p.allowed IS NULL;


        FOR j IN array_lower(p.allowed, 1)..array_upper(p.allowed, 1) LOOP
            IF p.allowed[j] = ANY(p.denied) THEN
                list[i].allowed := array_remove(list[i].allowed, list[i].allowed[j]);
            END IF;
        END LOOP;
    END LOOP;

    RETURN list;
END $$;


-- Checks an operation and subject bindings against the policy list
--
-- If the function returns NULL, the operation is not explicitly allowed or denied,
-- the caller should fall back to the default policy.
--
-- 1. No policies will return NULL
-- 2. No subjects will return NULL
-- 3. If the operation is denied for any of the subjects, the function returns FALSE
-- 4. If the operation is allowed for any of the subjects, the function returns TRUE
-- 5. If the operation is not explicitly allowed or denied, the function returns NULL
--
CREATE OR REPLACE
    FUNCTION ac_check(
    -- operation to be checked
    op ac_operation

    -- subjects to be used for filtering the rules
,   bindings ac_subject[]

    -- list of grants
,   list ac_policy[]

)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    IMMUTABLE           -- function is deterministic
    STRICT              -- if any of the arguments is NULL, return NULL
    PARALLEL SAFE
AS $$
BEGIN
    IF COALESCE(array_length(list::ac_policy[],1),0) = 0 THEN
        -- no policies, return NULL
        RETURN NULL;
    END IF;

    IF COALESCE(array_length(bindings::ac_subject[],1),0) = 0 THEN
        -- no bindings, return NULL
        RETURN NULL;
    END IF;

    FOR i IN array_lower(list,)..array_upper(list, 1) LOOP
        IF list[i].subject = ANY(bindings) AND op = ANY(list[i].denied) THEN
            -- at least one of the matching policies denies the operation
            RETURN FALSE;
        END IF;
    END LOOP;

    -- not explicitly denied, check if allowed
    FOR i IN array_lower(list, 1)..array_upper(list, 1) LOOP
        IF list[i].subject = ANY(bindings) AND op = ANY(list[i].allowed) THEN
            -- at least one of the matching policies allows the operation
            RETURN TRUE;
        END IF;

    END LOOP;

    -- signal no match with NULL
    RETURN NULL;
END;
$$;

-- Overloading the function to allow check with only one subject
CREATE OR REPLACE FUNCTION ac_check(ac_operation, ac_subject, ac_policy[]) RETURNS BOOLEAN LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$ SELECT ac_check($1, ARRAY[$2], $3) $$;



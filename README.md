# Access Control Postgres extension (with dev environment)

Please note that this is a work in progress and not yet production ready.

Extension provides a few functions and types/domains to implement security policies in PostgreSQL. 

The solution is somehow based on what was developed in [Corteza Project](https://github.com/cortezaproject/corteza) in application layer.

I wanted to explore PostgreSQL implementation, refresh my knowledge of [RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) and how extensions work.

This is not intended to be a full-fledged solution, but rather a set of building blocks that can be used to implement row security and RBAC in PostgreSQL.

It aims to be fast, flexible and unopinionated, does not handle user membership or role/group/object hierarchy.

# Installation

## Copy the code
The most straightforward way to install the extension is to copy the contents from the [ac--0.0.1.sql](src/ac--0.0.1.sql) 
file into your PostgreSQL database and execute all SQL statements from the file.

This is all that needs to be done to install this extension and for you to start using it.

## "The right way" (make install)
You will need build tools like `make` installed on your system, copy the files to the container and run the `make install` command.

See the [Dockerfile](Dockerfile) for a development environment setup and copy/adjust the RUN commands.

After the extension is installed, you can use it in your database by running:

```sql
CREATE EXTENSION ac;
```


## Extension types/domains
| Type/Domain    | Description                                                 |
|----------------|-------------------------------------------------------------|
| `ac_subject`   | Represents user, group, role                                |
| `ac_operation` | Operation to check, allow or deny                           |
| `ac_policy`    | Set of allowed and denied operations for a specific subject |

## Extension functions
| Type/Domain                                             | Returns     | Description                                                                    |
|---------------------------------------------------------|-------------|--------------------------------------------------------------------------------|
| `ac_policy(ac_subject, ac_operation[], ac_operation[])` | ac_policy   | Returns access-control policy with allow/deny operations subject               |
| `ac_policy(ac_subject, ac_operation[])`                 | ac_policy   | (overloaded function, for convenience)                                         |
| `ac_policy(ac_subject, ac_operation[], ac_operation)`   | ac_policy   | (overloaded function, for convenience)                                         |
| `ac_policy(ac_subject, ac_operation, ac_operation)`     | ac_policy   | (overloaded function, for convenience)                                         |
| `ac_list_cleanup(ac_policy[])`                          | ac_policy[] | Utility function, removes duplicates and empty policies                        |
| `ac_check(ac_operation, ac_subject[], ac_policy[])`     | boolean     | Check if any of the subjects has the operation allowed in the list of policies |
| `ac_check(ac_operation, ac_subject, ac_policy[])`       | boolean     | (overloaded function, for convenience)                                         |

## The basic idea

1. Add a new column of type `ac_policy[]` to your table.
2. Assign policies to the column for each row using the `ac_policy`
3. Use the `ac_check` function in your queries or with RLS policy to verify if an operation can be performed

## The logic of the policy checking function

The `ac_check` function checks if the operation is allowed or denied by the given set of policies. 
It filters the policies based on the list of subjects. 
If a subject has a policy that explicitly denies the operation, the function returns `FALSE`.
If a subject has at least one policy that allows the operation, it returns `TRUE`. 
If no matching policies are found, `NULL` is returned.

## On performance

The extension is designed to be efficient, but function performance will depend on the number of policies and subjects involved.

See the [performance tests](src/performance.sql) for more details.
Test shows how fast the extension can check access for a large number of policies and subjects.

# Example usage

## Policy creation
```sql
SELECT ac_policy(
    'user:1', 
    ARRAY['read', 'write'], 
    ARRAY['delete']
);
```

Results in:
```
            ac_policy
----------------------------------
 (user:1,"{read,write}",{delete})
```

## Checking access
```sql
SELECT ac_check(
    'read', 
    ARRAY['user:1', 'group:admins'], 
    ARRAY[ac_policy('user:1', ARRAY['read', 'write'], ARRAY['delete'])]
);
```
Results in:
```
 ac_check
----------
 t
(1 row)
```

Swaping 1st parameter for `ac_check` with `delete` would return `f` since the policy explicitly denies it for `user:1`.
Setting that parameter to `update` would return `NULL` (no matching policies).

## Using with RLS

The challenge with RLS we need to inject the current user/subject into the query context.

We can do this with the current_setting function, which can be set by the application at the connection or transaction level:
```sql
SELECT set_config('current-user', 'user:42', false);
SELECT set_config('current-roles', ARRAY['role:1','role:3']::TEXT, false);
```

### Hint

If you want to be able to create policies for a specific user, just add that user as a subject in the `current-roles` setting, e.g. `set_config('current-roles', ARRAY['user:42', ....], false)`


Now, alter the table, enable RLS, and create a policy that uses the `ac_check` function to verify access.

```sql
ALTER TABLE my_objects ADD COLUMN acl ac_policy[];
ALTER TABLE my_objects ENABLE ROW LEVEL SECURITY;

-- Similarities with PostgREST setup are not coincidental
CREATE POLICY acl ON my_objects
    FOR SELECT
    USING (COALESCE(
        ac_check('SELECT', current_setting('current-roles', true), acl)
        -- default: deny access 
    ,   false 
    ));
```

## Example with contextual subjects

Consider the following contextual roles (subjects) a particular user (subject) can have when accessing an entry in the table (object):
 - An owner of an object (`owned_by`)
 - A creator (`created_by`)
 - An updater (`updated_by`)

In addition to that, we will add a roles for anonymous or authenticated user, depends on the application context.

```sql
DROP POLICY acl ON my_objects;
CREATE POLICY acl ON my_objects
    FOR SELECT
    USING (COALESCE(
        ac_check(
            'SELECT'
        ,   ARRAY[ 
            -- list of conrextual subjects
                CASE WHEN current_setting('current-user', true) IS NULL         
                     THEN 'ctx:anonymous'
                     ELSE 'ctx:authenticated' END
            ,   CASE WHEN current_setting('current-user', true) = id         THEN 'ctx:owner'   END
            ,   CASE WHEN current_setting('current-user', true) = created_by THEN 'ctx:creator' END
            ,   CASE WHEN current_setting('current-user', true) = updated_by THEN 'ctx:updater' END
            ]::ac_subject
            -- concatenate with subjects provided by the application
            || current_setting('current-roles', true)::ac_subject[]
        ,   acl
        )
    ,   false -- if no matching policies are found, deny access
    ));
```

### Note on wrapping the logic into a function
If you want to get minimize the code repetition, you can create a function that returns the list of contextual subjects based on the current user and roles.
Or even a function that packs the whole logic of checking access into a single function.

That will have major performance implications (todo explain why).

# Things that could be added in the future
 - set/get current user/roles helper functions
 - helper function to convert policies from/to JSON
...

# Development environment

The provided [docker-compose.yaml](docker-compose.yaml) and [Dockerfile](Dockerfile) allow you to quickly set up a development environment for the extension.

```
# Build the Docker image
docker compose build

# Start the PostgreSQL container
docker compose up -d

# Install extension and run the tests
docker compose exec pgxdev make install installcheck
```


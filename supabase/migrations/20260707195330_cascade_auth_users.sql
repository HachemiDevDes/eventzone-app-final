DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT 
            tc.table_schema, 
            tc.table_name, 
            tc.constraint_name, 
            kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
          ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu 
          ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND ccu.table_schema = 'auth'
          AND ccu.table_name = 'users'
          AND ccu.column_name = 'id'
          AND tc.table_schema = 'public'
    )
    LOOP
        -- Drop the existing constraint
        EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', r.table_schema, r.table_name, r.constraint_name);
        
        -- Re-add it with ON DELETE CASCADE
        EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES auth.users(id) ON DELETE CASCADE', 
            r.table_schema, r.table_name, r.constraint_name, r.column_name);
    END LOOP;
END;
$$;

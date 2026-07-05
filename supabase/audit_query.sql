-- Full Audit Query Batch

-- 1. Tables
SELECT 'TABLES' as check_type, json_agg(row_to_json(t)) FROM (SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename) t;

-- 2. Columns (Checking for profiles.points)
SELECT 'COLUMNS' as check_type, json_agg(row_to_json(t)) FROM (
  SELECT table_name, column_name 
  FROM information_schema.columns 
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'points'
) t;

-- 3. Functions (Checking for deduct_connection_points)
SELECT 'FUNCTIONS' as check_type, json_agg(row_to_json(t)) FROM (
  SELECT routine_name 
  FROM information_schema.routines 
  WHERE routine_schema = 'public' 
  ORDER BY routine_name
) t;

-- 4. Indexes (Checking for newly added indexes and renamed transactions index)
SELECT 'INDEXES' as check_type, json_agg(row_to_json(t)) FROM (
  SELECT tablename, indexname 
  FROM pg_indexes 
  WHERE schemaname = 'public' 
  ORDER BY tablename, indexname
) t;

-- 5. RLS Policies (Checking for removed duplicates)
SELECT 'POLICIES' as check_type, json_agg(row_to_json(t)) FROM (
  SELECT tablename, policyname, cmd, with_check 
  FROM pg_policies 
  WHERE schemaname = 'public' 
  ORDER BY tablename, policyname
) t;

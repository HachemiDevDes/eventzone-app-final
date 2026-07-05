-- Create a view or RPC for the global leaderboard
-- This function aggregates connection counts per user and joins with their profile.

CREATE OR REPLACE FUNCTION get_global_leaderboard()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  avatar_url TEXT,
  job_title TEXT,
  company_name TEXT,
  connection_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.job_title,
    p.company_name,
    COUNT(c.id) as connection_count
  FROM profiles p
  LEFT JOIN connections c ON p.id = c.user_id
  -- Optionally filter out organizers/admins if desired, but we'll include all valid attendees for now
  WHERE p.role = 'attendee' OR p.role IS NULL
  GROUP BY p.id
  HAVING COUNT(c.id) > 0
  ORDER BY connection_count DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql;

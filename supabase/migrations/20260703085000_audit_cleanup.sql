-- =====================================================
-- AUDIT FIX: Clean up legacy points system remnants
-- =====================================================

-- CRITICAL 3: Drop obsolete deduct_connection_points function
DROP FUNCTION IF EXISTS public.deduct_connection_points;

-- CRITICAL 4: Drop orphan points column from profiles
ALTER TABLE profiles DROP COLUMN IF EXISTS points;

-- WARNING 8: Drop test table
DROP TABLE IF EXISTS antigravity_test_table;

-- =====================================================
-- AUDIT FIX: Consolidate duplicate RLS policies
-- =====================================================

-- WARNING 5a: Drop duplicate INSERT policy on profiles (keep the one named consistently)
DROP POLICY IF EXISTS "Allow users to create their own profile" ON profiles;

-- WARNING 5b: Drop the UPDATE policy missing WITH CHECK (keep "Profiles update policy" which has both)
DROP POLICY IF EXISTS "Allow users to update their own profile" ON profiles;

-- WARNING 6: Drop duplicate INSERT policy on messages (keep "Allow authenticated inserts")
DROP POLICY IF EXISTS "Allow users to send messages" ON messages;

-- =====================================================
-- AUDIT FIX: Add missing indexes for performance
-- =====================================================

-- connections indexes
CREATE INDEX IF NOT EXISTS idx_connections_user_id ON connections(user_id);
CREATE INDEX IF NOT EXISTS idx_connections_linked_profile_id ON connections(linked_profile_id);

-- connection_requests indexes (used in profiles SELECT RLS subquery)
CREATE INDEX IF NOT EXISTS idx_connection_requests_sender_id ON connection_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_connection_requests_receiver_id ON connection_requests(receiver_id);

-- transactions index
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);

-- event_registrations indexes
CREATE INDEX IF NOT EXISTS idx_event_registrations_event_id ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_profile_id ON event_registrations(profile_id);

-- meetings indexes
CREATE INDEX IF NOT EXISTS idx_meetings_organizer_id ON meetings(organizer_id);
CREATE INDEX IF NOT EXISTS idx_meetings_attendee_id ON meetings(attendee_id);

-- =====================================================
-- AUDIT FIX: Rename legacy constraint/index names
-- =====================================================

-- INFO 14: Rename legacy PK index on transactions
ALTER INDEX IF EXISTS points_transactions_pkey RENAME TO transactions_pkey;

-- INFO 14: Rename legacy FK on transactions
ALTER TABLE transactions RENAME CONSTRAINT points_transactions_user_id_fkey TO transactions_user_id_fkey;

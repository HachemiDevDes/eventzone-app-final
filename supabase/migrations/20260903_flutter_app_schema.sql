-- ==============================================================================
-- EVENTZONE FLUTTER APP - COMPATIBILITY & SCHEMA MIGRATION SCRIPT
-- Target: gknglowozpewwrtjumuc (Eventzone Platform)
-- ==============================================================================

-- 1. Patch connections table with missing columns & indexes
ALTER TABLE public.connections ADD COLUMN IF NOT EXISTS linked_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.connections ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'connected';
CREATE INDEX IF NOT EXISTS idx_connections_user_id ON public.connections(user_id);
CREATE INDEX IF NOT EXISTS idx_connections_linked_profile_id ON public.connections(linked_profile_id);

-- 2. Messages table (Attendees / Connections chat)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL,
    recipient_id UUID NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_sender_recipient ON public.messages(sender_id, recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.messages;
CREATE POLICY "Public access policy" ON public.messages FOR ALL USING (true) WITH CHECK (true);

-- 3. Event Registrations table
CREATE TABLE IF NOT EXISTS public.event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT event_registrations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
    UNIQUE(event_id, profile_id)
);
CREATE INDEX IF NOT EXISTS idx_event_registrations_event_id ON public.event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_profile_id ON public.event_registrations(profile_id);
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.event_registrations;
CREATE POLICY "Public access policy" ON public.event_registrations FOR ALL USING (true) WITH CHECK (true);

-- 4. Meetings table (1-on-1 attendee scheduling)
CREATE TABLE IF NOT EXISTS public.meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    date TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    location TEXT,
    note TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_meetings_organizer_id ON public.meetings(organizer_id);
CREATE INDEX IF NOT EXISTS idx_meetings_attendee_id ON public.meetings(attendee_id);
CREATE INDEX IF NOT EXISTS idx_meetings_date ON public.meetings(date);
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.meetings;
CREATE POLICY "Public access policy" ON public.meetings FOR ALL USING (true) WITH CHECK (true);

-- 5. Session Favorites table (Personal Agenda)
CREATE TABLE IF NOT EXISTS public.session_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, session_id)
);
CREATE INDEX IF NOT EXISTS idx_session_favorites_user_id ON public.session_favorites(user_id);
ALTER TABLE public.session_favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.session_favorites;
CREATE POLICY "Public access policy" ON public.session_favorites FOR ALL USING (true) WITH CHECK (true);

-- 6. Shake Sessions table (Shake to connect nearby networking)
CREATE TABLE IF NOT EXISTS public.shake_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    latitude FLOAT8 NOT NULL,
    longitude FLOAT8 NOT NULL,
    status TEXT DEFAULT 'searching' CHECK (status IN ('searching', 'matched', 'expired')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_shake_sessions_status_created_at ON public.shake_sessions(status, created_at);
ALTER TABLE public.shake_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.shake_sessions;
CREATE POLICY "Public access policy" ON public.shake_sessions FOR ALL USING (true) WITH CHECK (true);

-- 7. Support Messages table
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    name TEXT,
    email TEXT,
    subject TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.support_messages;
CREATE POLICY "Public access policy" ON public.support_messages FOR ALL USING (true) WITH CHECK (true);

-- 8. Transactions table (Billing / Subscription logs)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    type TEXT,
    amount NUMERIC,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.transactions;
CREATE POLICY "Public access policy" ON public.transactions FOR ALL USING (true) WITH CHECK (true);

-- 9. Promo Codes table
CREATE TABLE IF NOT EXISTS public.promo_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    discount_percentage INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON public.promo_codes(code);
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.promo_codes;
CREATE POLICY "Public access policy" ON public.promo_codes FOR ALL USING (true) WITH CHECK (true);

-- 10. App Config table
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.app_config;
CREATE POLICY "Public access policy" ON public.app_config FOR ALL USING (true) WITH CHECK (true);

-- Insert default app_config entries
INSERT INTO public.app_config (key, value, description)
VALUES 
    ('maintenance_mode', 'false', 'Disable app for maintenance'),
    ('min_version', '1.0.0', 'Minimum supported version')
ON CONFLICT (key) DO NOTHING;

-- 11. User FCM Tokens table
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, token)
);
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.user_fcm_tokens;
CREATE POLICY "Public access policy" ON public.user_fcm_tokens FOR ALL USING (true) WITH CHECK (true);

-- 12. RPC Functions
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
  FROM public.profiles p
  LEFT JOIN public.connections c ON p.id = c.user_id
  WHERE p.role = 'attendee' OR p.role IS NULL OR p.role = 'organizer'
  GROUP BY p.id
  HAVING COUNT(c.id) > 0
  ORDER BY connection_count DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- 13. Enable Realtime Publications for Interactive Features
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.shake_sessions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.meetings;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.event_registrations;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.session_favorites;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

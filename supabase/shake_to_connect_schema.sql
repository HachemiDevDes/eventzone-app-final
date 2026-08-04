-- 1. Create the shake_sessions table
CREATE TABLE IF NOT EXISTS public.shake_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude FLOAT8 NOT NULL,
  longitude FLOAT8 NOT NULL,
  status TEXT DEFAULT 'searching' CHECK (status IN ('searching', 'matched', 'expired')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Add indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_shake_sessions_status_created_at 
  ON public.shake_sessions(status, created_at);

-- 3. Enable RLS
ALTER TABLE public.shake_sessions ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
-- Users can insert their own row
CREATE POLICY "Users can insert their own shake session"
  ON public.shake_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can read all searching rows (needed for matchmaking) or their own row
CREATE POLICY "Users can read searching sessions or their own"
  ON public.shake_sessions
  FOR SELECT
  USING (status = 'searching' OR auth.uid() = user_id);

-- Users can update only their own row
CREATE POLICY "Users can update their own shake session"
  ON public.shake_sessions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 5. Enable Realtime on shake_sessions table
BEGIN;
  DO $$ 
  BEGIN 
    IF EXISTS (
      SELECT 1 FROM pg_publication 
      WHERE pubname = 'supabase_realtime'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.shake_sessions;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Ignore
  END; 
  $$;
COMMIT;

-- 6. Setup pg_cron for automatic cleanup (requires pg_cron extension)
DO $do$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule('cleanup-shake-sessions', '* * * * *',
      $$DELETE FROM public.shake_sessions WHERE created_at < now() - interval '60 seconds'$$
    );
  END IF;
END $do$;

-- 1. Create table for FCM tokens
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, token)
);

-- 2. Add RLS policies for FCM tokens
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own token" 
ON public.user_fcm_tokens FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own token" 
ON public.user_fcm_tokens FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own token" 
ON public.user_fcm_tokens FOR DELETE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can read their own token" 
ON public.user_fcm_tokens FOR SELECT 
USING (auth.uid() = user_id);

-- Note: To send pushes when a message is inserted, you will need to set up a Supabase Database Webhook
-- or Edge Function that triggers ON INSERT to the `messages` table and sends the payload to Firebase FCM API.

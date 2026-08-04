-- Add CRM desktop login token to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS crm_token TEXT UNIQUE;

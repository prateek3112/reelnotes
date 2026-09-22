-- 001_create_profiles.sql
-- User profiles table for ReelVault

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS (permissive for MVP)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to profiles" 
    ON public.profiles FOR SELECT 
    USING (true);

CREATE POLICY "Allow public insert to profiles" 
    ON public.profiles FOR INSERT 
    WITH CHECK (true);

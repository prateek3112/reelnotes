-- 002_create_reels.sql
-- Reels master table storing media metadata, transcriptions, and AI analysis

CREATE TABLE IF NOT EXISTS public.reels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    source_platform TEXT DEFAULT 'instagram',
    original_url TEXT NOT NULL,
    shortcode TEXT,
    creator_username TEXT,
    creator_name TEXT,
    title TEXT,
    topic TEXT,
    summary TEXT,
    hook TEXT,
    transcript TEXT,
    cleaned_transcript TEXT,
    content_structure JSONB,
    tags TEXT[] DEFAULT '{}',
    thumbnail_url TEXT,
    duration_seconds INTEGER,
    status TEXT DEFAULT 'pending'
        CHECK (status IN (
            'pending',
            'downloading',
            'extracting_audio',
            'transcribing',
            'analyzing',
            'completed',
            'failed'
        )),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    processed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Duplicate prevention constraint: unique shortcode per platform and user
-- If user_id is null, unique index ensures single global entry per shortcode
CREATE UNIQUE INDEX IF NOT EXISTS uq_reels_platform_shortcode_global
    ON public.reels (source_platform, shortcode)
    WHERE user_id IS NULL AND shortcode IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_reels_user_platform_shortcode
    ON public.reels (user_id, source_platform, shortcode)
    WHERE user_id IS NOT NULL AND shortcode IS NOT NULL;

-- Enable Realtime replication for instant client UI updates
ALTER TABLE public.reels REPLICA IDENTITY FULL;

-- RLS policies
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to reels"
    ON public.reels FOR SELECT
    USING (true);

CREATE POLICY "Allow public insert to reels"
    ON public.reels FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public update to reels"
    ON public.reels FOR UPDATE
    USING (true);

CREATE POLICY "Allow public delete to reels"
    ON public.reels FOR DELETE
    USING (true);

-- ==============================================================================
-- REELVAULT / REELNOTES: COMBINED SUPABASE SETUP MIGRATION
-- Run this entire script in Supabase Dashboard -> SQL Editor -> Click 'Run'
-- ==============================================================================

-- 1. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public read access to profiles') THEN
        CREATE POLICY "Allow public read access to profiles" ON public.profiles FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public insert to profiles') THEN
        CREATE POLICY "Allow public insert to profiles" ON public.profiles FOR INSERT WITH CHECK (true);
    END IF;
END $$;

-- 2. REELS TABLE
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_reels_platform_shortcode_global
    ON public.reels (source_platform, shortcode)
    WHERE user_id IS NULL AND shortcode IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_reels_user_platform_shortcode
    ON public.reels (user_id, source_platform, shortcode)
    WHERE user_id IS NOT NULL AND shortcode IS NOT NULL;

ALTER TABLE public.reels REPLICA IDENTITY FULL;

ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public read access to reels') THEN
        CREATE POLICY "Allow public read access to reels" ON public.reels FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public insert to reels') THEN
        CREATE POLICY "Allow public insert to reels" ON public.reels FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public update to reels') THEN
        CREATE POLICY "Allow public update to reels" ON public.reels FOR UPDATE USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public delete to reels') THEN
        CREATE POLICY "Allow public delete to reels" ON public.reels FOR DELETE USING (true);
    END IF;
END $$;

-- 3. PROCESSING JOBS QUEUE TABLE
CREATE TABLE IF NOT EXISTS public.processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    locked_by TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.processing_jobs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public read access to processing_jobs') THEN
        CREATE POLICY "Allow public read access to processing_jobs" ON public.processing_jobs FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow service role full access to processing_jobs') THEN
        CREATE POLICY "Allow service role full access to processing_jobs" ON public.processing_jobs FOR ALL USING (true);
    END IF;
END $$;

-- 4. PERFORMANCE & FULL-TEXT SEARCH INDEXES
CREATE INDEX IF NOT EXISTS idx_jobs_queued_created
    ON public.processing_jobs (status, created_at ASC)
    WHERE status = 'queued';

CREATE INDEX IF NOT EXISTS idx_jobs_reel_id
    ON public.processing_jobs (reel_id);

CREATE INDEX IF NOT EXISTS idx_reels_status
    ON public.reels (status);

CREATE INDEX IF NOT EXISTS idx_reels_created_at_desc
    ON public.reels (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reels_shortcode
    ON public.reels (shortcode)
    WHERE shortcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reels_fts
    ON public.reels
    USING gin (
        to_tsvector('english',
            coalesce(title, '') || ' ' ||
            coalesce(topic, '') || ' ' ||
            coalesce(summary, '') || ' ' ||
            coalesce(transcript, '') || ' ' ||
            coalesce(creator_username, '') || ' ' ||
            coalesce(array_to_string(tags, ' '), '')
        )
    );

-- 5. ATOMIC QUEUE CLAIM RPC FUNCTION
CREATE OR REPLACE FUNCTION claim_next_job(worker_identifier TEXT)
RETURNS SETOF public.processing_jobs AS $$
BEGIN
    RETURN QUERY
    WITH candidate AS (
        SELECT id
        FROM public.processing_jobs
        WHERE status = 'queued'
          AND attempt_count < max_attempts
        ORDER BY created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    UPDATE public.processing_jobs
    SET status = 'processing',
        locked_by = worker_identifier,
        attempt_count = processing_jobs.attempt_count + 1,
        started_at = now()
    FROM candidate
    WHERE processing_jobs.id = candidate.id
    RETURNING processing_jobs.*;
END;
$$ LANGUAGE plpgsql;

-- 6. ENABLE SUPABASE REALTIME REPLICATION (For live card updates in SwiftUI)
DO $$ BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.reels;
    EXCEPTION
        WHEN duplicate_object THEN NULL;
    END;
END $$;

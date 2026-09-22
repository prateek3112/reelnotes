-- 004_create_indexes.sql
-- Optimized indexes for fast queue polling, full-text search, and library sorting

-- Queue polling performance index
CREATE INDEX IF NOT EXISTS idx_jobs_queued_created
    ON public.processing_jobs (status, created_at ASC)
    WHERE status = 'queued';

CREATE INDEX IF NOT EXISTS idx_jobs_reel_id
    ON public.processing_jobs (reel_id);

-- Reels status filter index
CREATE INDEX IF NOT EXISTS idx_reels_status
    ON public.reels (status);

-- Reels timeline sorting
CREATE INDEX IF NOT EXISTS idx_reels_created_at_desc
    ON public.reels (created_at DESC);

-- Shortcode lookup
CREATE INDEX IF NOT EXISTS idx_reels_shortcode
    ON public.reels (shortcode)
    WHERE shortcode IS NOT NULL;

-- Full-Text Search GIN index
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

-- 005_create_claim_job_rpc.sql
-- Atomic Dequeue Function using FOR UPDATE SKIP LOCKED
-- Guarantees multiple worker threads/containers never process the same job

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

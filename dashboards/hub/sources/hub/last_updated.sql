SELECT MAX(completed_at)::VARCHAR AS last_updated
FROM superligaen.meta.ingestion_run_log
WHERE status = 'success'

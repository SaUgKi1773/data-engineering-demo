select strftime(max(completed_at), '%d %b %Y %H:%M UTC') as last_updated
from superligaen.meta.ingestion_run_log
where status = 'success'

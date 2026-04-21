select strftime(max(ingested_at), '%d %b %Y %H:%M UTC') as last_updated
from superligaen.bronze.api_football__fixtures

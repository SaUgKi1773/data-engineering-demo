select
    league_name,
    league_logo,
    league_country_flag
from superligaen.gold.dim_league
where league_id = 119924
limit 1

select
    league_name,
    league_logo,
    league_country_flag
from gold.dim_league
where league_id = 119
limit 1

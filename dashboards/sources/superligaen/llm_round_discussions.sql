select
    d.season,
    dm.match_round_number                                                    as round_number,
    dm.match_name,
    dp.persona_name,
    dp.sort_order,
    f.message,
    d.date                                                                    as match_date
from superligaen.gold.fct_match_discussions f
join superligaen.gold.dim_persona           dp  on dp.persona_sk  = f.persona_sk
join superligaen.gold.dim_match             dm  on dm.match_sk    = f.match_sk
join (
    select match_sk, min(date_sk) as date_sk
    from superligaen.gold.fct_team_matches
    group by match_sk
)                                           ftm on ftm.match_sk   = f.match_sk
join superligaen.gold.dim_date              d   on d.date_sk      = ftm.date_sk
order by d.season, dm.match_round_number, dm.match_name, dp.sort_order

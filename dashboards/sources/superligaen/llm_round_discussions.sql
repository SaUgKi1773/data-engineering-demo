select
    dd.date                as comment_date,
    dm.match_id,
    dm.match_round_type,
    dm.match_round_number,
    dm.match_round_name,
    dm.match_type,
    dm.match_name,
    dm.match_short_name,
    dm.match_result,
    dm.kick_off_time,
    dm.match_status,
    dp.persona_name,
    dp.sort_order,
    f.message
from superligaen.gold.fct_match_discussions f
join superligaen.gold.dim_match             dm on dm.match_sk   = f.match_sk
join superligaen.gold.dim_persona           dp on dp.persona_sk = f.persona_sk
join superligaen.gold.dim_date              dd on dd.date_sk    = f.date_sk
order by dd.date, dm.match_name, dp.sort_order

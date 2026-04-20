select
    m.season,
    m.match_round_number          as round,
    t.team_name,
    sum(f.points_earned) over (
        partition by f.team_sk, m.season
        order by m.match_round_number
    )                             as cumulative_points
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m on m.match_sk        = f.match_sk
join superligaen.gold.dim_team         t on t.team_sk         = f.team_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where r.match_result in ('Win', 'Draw', 'Loss')
order by m.season, t.team_name, m.match_round_number

select
    t.team_name,
    m.season,
    count(*)                                                            as gp,
    sum(case when f.match_result_sk = 1 then 1 else 0 end)             as w,
    sum(case when f.match_result_sk = 2 then 1 else 0 end)             as d,
    sum(case when f.match_result_sk = 3 then 1 else 0 end)             as l,
    sum(f.goals_scored)                                                 as gf,
    sum(f.goals_conceded)                                               as ga,
    sum(f.goals_scored) - sum(f.goals_conceded)                        as gd,
    sum(coalesce(f.points_earned, 0))                                   as pts,
    case
        when max(case when m.match_round_name like 'Championship Group%' then 1 else 0 end) = 1 then 'Championship Group'
        when max(case when m.match_round_name like 'Relegation Group%'   then 1 else 0 end) = 1 then 'Relegation Group'
        else 'Regular Season'
    end                                                                 as round_group
from gold.fct_match_results f
join gold.dim_team t   on t.team_sk  = f.team_sk
join gold.dim_match m  on m.match_sk = f.match_sk
where f.match_result_sk in (1, 2, 3)
group by t.team_name, m.season
order by m.season desc, round_group, pts desc, gd desc, gf desc

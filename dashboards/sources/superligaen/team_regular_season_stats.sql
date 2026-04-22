select
    t.team_name,
    d.season,
    count(*)                                                            as gp,
    sum(case when f.match_result_sk = 1 then 1 else 0 end)             as w,
    sum(case when f.match_result_sk = 2 then 1 else 0 end)             as d,
    sum(case when f.match_result_sk = 3 then 1 else 0 end)             as l,
    sum(f.goals_scored)                                                 as gf,
    sum(f.goals_conceded)                                               as ga,
    sum(f.goals_scored) - sum(f.goals_conceded)                        as gd,
    sum(coalesce(f.points_earned, 0))                                   as pts
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team  t  on t.team_sk  = f.team_sk
join superligaen.gold.dim_match m  on m.match_sk = f.match_sk
join superligaen.gold.dim_date  d  on d.date_sk  = f.date_sk
where f.match_result_sk in (1, 2, 3)
  and m.match_round_name like 'Regular Season%'
group by t.team_name, d.season
order by d.season desc, pts desc, gd desc, gf desc

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
    sum(coalesce(f.points_earned, 0))                                   as pts,
    case
        when max(case when m.match_round_type = 'Championship Group' then 1 else 0 end) = 1 then 'Championship Group'
        when max(case when m.match_round_type = 'Relegation Group'   then 1 else 0 end) = 1 then 'Relegation Group'
        when max(case when m.match_round_type = 'Regular Season'     then 1 else 0 end) = 1 then 'Regular Season'
        else max(m.match_round_type)
    end                                                                 as round_group
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team  t  on t.team_sk  = f.team_sk
join superligaen.gold.dim_match m  on m.match_sk = f.match_sk
join superligaen.gold.dim_date  d  on d.date_sk  = f.date_sk
where f.match_result_sk in (1, 2, 3)
group by t.team_name, d.season
order by d.season desc, round_group, pts desc, gd desc, gf desc

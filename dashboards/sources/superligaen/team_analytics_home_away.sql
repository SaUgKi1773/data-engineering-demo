select
    t.team_name,
    ts.team_side                                                                    as side,
    m.season,
    count(*)                                                                        as matches,
    sum(f.points_earned)                                                            as points,
    count(*) filter (where r.match_result = 'Win')                                  as wins,
    count(*) filter (where r.match_result = 'Draw')                                 as draws,
    count(*) filter (where r.match_result = 'Loss')                                 as losses,
    sum(f.goals_scored)                                                             as goals_for,
    sum(f.goals_conceded)                                                           as goals_against,
    round(avg(f.expected_goals::double), 2)                                         as avg_xg,
    round(avg(f.ball_possession_pct::double), 1)                                    as avg_possession,
    round(avg(f.shots_on_goal::double), 1)                                          as avg_shots_on_goal,
    round(100.0 * sum(f.goals_scored) / nullif(sum(f.total_shots), 0), 1)          as shot_conversion_pct,
    round(avg(f.fouls::double), 1)                                                  as avg_fouls,
    sum(f.yellow_cards)                                                             as yellow_cards,
    sum(f.red_cards)                                                                as red_cards,
    round(avg(f.goalkeeper_saves::double), 1)                                       as avg_saves,
    round(100.0 * count(*) filter (where r.match_result = 'Win') / count(*), 1)    as win_rate_pct
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team          t   on t.team_sk          = f.team_sk
join superligaen.gold.dim_match         m   on m.match_sk         = f.match_sk
join superligaen.gold.dim_match_result  r   on r.match_result_sk  = f.match_result_sk
join superligaen.gold.dim_team_side     ts  on ts.team_side_sk    = f.team_side_sk
where r.match_result in ('Win', 'Draw', 'Loss')
group by t.team_name, ts.team_side, m.season
order by t.team_name, m.season, ts.team_side

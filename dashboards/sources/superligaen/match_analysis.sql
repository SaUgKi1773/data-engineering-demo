select
    d.date                                                                      as match_date,
    m.match_name,
    m.match_result                                                              as score,
    m.season,
    t.team_name,
    ts.team_side                                                                as side,
    f.goals_scored                                                              as goals,
    round(f.expected_goals::double, 2)                                          as xg,
    f.shots_on_goal,
    f.total_shots,
    f.shots_insidebox,
    f.shots_outsidebox,
    round(f.ball_possession_pct::double, 1)                                     as possession,
    f.corner_kicks                                                              as corners,
    f.fouls,
    f.offsides,
    f.yellow_cards,
    f.red_cards,
    f.goalkeeper_saves                                                          as saves,
    round(f.passes_accurate::double / nullif(f.total_passes, 0) * 100, 1)      as pass_accuracy
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m  on m.match_sk        = f.match_sk
join superligaen.gold.dim_date         d  on d.date_sk         = f.date_sk
join superligaen.gold.dim_team         t  on t.team_sk         = f.team_sk
join superligaen.gold.dim_match_result r  on r.match_result_sk = f.match_result_sk
join superligaen.gold.dim_team_side    ts on ts.team_side_sk   = f.team_side_sk
where r.match_result in ('Win', 'Draw', 'Loss')
order by d.date desc, m.match_name, ts.team_side

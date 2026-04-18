select
    t.team_name,
    d.full_date                                                             as match_date,
    m.match_round_name                                                      as round,
    m.match_round_number,
    ot.opponent_team_name                                                   as opponent,
    ts.team_side                                                            as side,
    f.goals_scored                                                          as gf,
    f.goals_conceded                                                        as ga,
    r.match_result                                                          as result,
    f.points_earned                                                         as pts,
    round(f.expected_goals::double, 2)                                      as xg,
    f.shots_on_goal,
    f.total_shots,
    f.shots_insidebox,
    f.shots_outsidebox,
    f.ball_possession_pct                                                   as possession,
    f.yellow_cards,
    f.red_cards,
    f.fouls,
    f.corner_kicks,
    f.offsides,
    f.goalkeeper_saves                                                      as saves,
    round(f.passes_accurate::double / nullif(f.total_passes, 0) * 100, 1)  as pass_accuracy,
    sum(f.points_earned) over (
        partition by t.team_name, m.season
        order by d.full_date
        rows between unbounded preceding and current row
    )                                                                       as cumulative_points,
    m.season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team          t   on t.team_sk          = f.team_sk
join superligaen.gold.dim_opponent_team ot  on ot.opponent_team_sk = f.opponent_team_sk
join superligaen.gold.dim_date          d   on d.date_sk          = f.date_sk
join superligaen.gold.dim_match         m   on m.match_sk         = f.match_sk
join superligaen.gold.dim_match_result  r   on r.match_result_sk  = f.match_result_sk
join superligaen.gold.dim_team_side     ts  on ts.team_side_sk    = f.team_side_sk
where r.match_result in ('Win', 'Draw', 'Loss')
order by t.team_name, m.season, d.full_date

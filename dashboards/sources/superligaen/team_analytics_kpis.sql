select
    t.team_name,
    m.season,
    count(*)                                                                        as matches_played,
    sum(f.points_earned)                                                            as total_points,
    count(*) filter (where r.match_result = 'Win')                                  as wins,
    count(*) filter (where r.match_result = 'Draw')                                 as draws,
    count(*) filter (where r.match_result = 'Loss')                                 as losses,
    sum(f.goals_scored)                                                             as goals_for,
    sum(f.goals_conceded)                                                           as goals_against,
    sum(f.goals_scored) - sum(f.goals_conceded)                                     as goal_difference,
    round(avg(f.goals_scored::double), 2)                                           as avg_goals_scored,
    round(avg(f.goals_conceded::double), 2)                                         as avg_goals_conceded,
    round(sum(f.expected_goals::double), 2)                                         as total_xg,
    round(avg(f.expected_goals::double), 2)                                         as avg_xg_per_match,
    round(sum(f.goals_scored::double) - sum(f.expected_goals::double), 2)           as xg_overperformance,
    round(avg(f.ball_possession_pct::double), 1)                                    as avg_possession,
    round(avg(f.passes_accurate::double / nullif(f.total_passes, 0) * 100), 1)     as avg_pass_accuracy,
    round(avg(f.shots_on_goal::double), 1)                                          as avg_shots_on_goal,
    round(100.0 * sum(f.goals_scored) / nullif(sum(f.total_shots), 0), 1)          as shot_conversion_pct,
    round(100.0 * sum(f.goals_scored) / nullif(sum(f.shots_on_goal), 0), 1)        as on_target_conversion_pct,
    sum(f.shots_insidebox)                                                          as shots_insidebox,
    sum(f.shots_outsidebox)                                                         as shots_outsidebox,
    round(avg(f.goalkeeper_saves::double), 1)                                       as avg_saves,
    round(avg(f.fouls::double), 1)                                                  as avg_fouls,
    round(avg(f.corner_kicks::double), 1)                                           as avg_corners,
    round(avg(f.offsides::double), 1)                                               as avg_offsides,
    sum(f.yellow_cards)                                                             as yellow_cards,
    sum(f.red_cards)                                                                as red_cards,
    round(avg(f.yellow_cards::double), 2)                                           as avg_yellow_per_match,
    round(avg(f.red_cards::double), 2)                                              as avg_red_per_match,
    round(100.0 * count(*) filter (where r.match_result = 'Win') / count(*), 1)    as win_rate_pct,
    round(
        (sum(f.fouls) + sum(f.yellow_cards) * 5 + sum(f.red_cards) * 15)
        ::double / count(*), 1
    )                                                                               as aggression_index,
    count(*) filter (where f.goals_conceded = 0)                                    as clean_sheets
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team         t  on t.team_sk          = f.team_sk
join superligaen.gold.dim_match        m  on m.match_sk         = f.match_sk
join superligaen.gold.dim_match_result r  on r.match_result_sk  = f.match_result_sk
where r.match_result in ('Win', 'Draw', 'Loss')
group by t.team_name, m.season
order by m.season desc, total_points desc

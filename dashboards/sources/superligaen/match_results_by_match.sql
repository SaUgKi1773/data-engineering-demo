select
    d.date                                     as match_date,
    m.match_round_name                              as round,
    m.match_round_number,
    m.match_name,
    m.match_short_name,
    m.match_result                                  as score,
    sum(f.shots_on_goal)                            as total_shots_on_goal,
    sum(f.yellow_cards)                             as total_yellow_cards,
    sum(f.red_cards)                                as total_red_cards,
    sum(f.corner_kicks)                             as total_corners,
    round(sum(f.expected_goals::double), 2)         as total_xg,
    sum(f.goals_scored)                             as total_goals,
    d.season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m on m.match_sk        = f.match_sk
join superligaen.gold.dim_date         d on d.date_sk         = f.date_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where r.match_result in ('Win', 'Draw', 'Loss')
group by d.date, m.match_round_name, m.match_round_number, m.match_name, m.match_short_name, m.match_result, d.season
order by d.date desc

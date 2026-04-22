select
    sum(case when f.team_side_sk = 1 then f.goals_scored else 0 end)::integer  as total_goals,
    sum(f.red_cards)::integer                                                   as total_red_cards,
    round(
        sum(f.total_shots)::decimal / nullif(count(distinct f.match_sk), 0),
        1
    )                                                                           as avg_shots_per_match,
    max(d.season)                                                               as season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m on m.match_sk        = f.match_sk
join superligaen.gold.dim_date         d on d.date_sk         = f.date_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where d.season = (select max(d2.season) from superligaen.gold.fct_match_results f2 join superligaen.gold.dim_date d2 on d2.date_sk = f2.date_sk)
  and r.match_result in ('Win', 'Draw', 'Loss')
  and f.total_shots is not null

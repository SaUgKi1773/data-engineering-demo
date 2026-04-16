select
    sum(case when f.team_side_sk = 1 then f.goals_scored else 0 end)::integer  as total_goals,
    sum(f.red_cards)::integer                                                   as total_red_cards,
    round(
        sum(f.total_shots)::decimal / nullif(count(distinct f.match_sk), 0),
        1
    )                                                                           as avg_shots_per_match,
    max(m.season)                                                               as season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m on m.match_sk        = f.match_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where m.season = (select max(season) from superligaen.gold.dim_match where season is not null)
  and r.match_result in ('Win', 'Draw', 'Loss')
  and f.total_shots is not null

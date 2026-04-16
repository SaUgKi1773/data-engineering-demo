select
    t.team_name,
    sum(f.points_earned)::integer as pts
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team         t on t.team_sk        = f.team_sk
join superligaen.gold.dim_match        m on m.match_sk       = f.match_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where m.season = (select max(season) from superligaen.gold.dim_match where season is not null)
  and r.match_result in ('Win', 'Draw', 'Loss')
group by t.team_name
order by pts desc
limit 1

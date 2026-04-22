select
    t.team_name,
    sum(f.points_earned)::integer as pts
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_team         t on t.team_sk         = f.team_sk
join superligaen.gold.dim_match        m on m.match_sk        = f.match_sk
join superligaen.gold.dim_date         d on d.date_sk         = f.date_sk
join superligaen.gold.dim_match_result r on r.match_result_sk = f.match_result_sk
where d.season = (select max(d2.season) from superligaen.gold.fct_match_results f2 join superligaen.gold.dim_date d2 on d2.date_sk = f2.date_sk)
  and r.match_result in ('Win', 'Draw', 'Loss')
group by t.team_name
order by pts desc
limit 1

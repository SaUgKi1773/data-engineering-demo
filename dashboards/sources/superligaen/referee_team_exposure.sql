select
    ref.referee_name,
    d.season,
    t.team_name,
    count(distinct m.match_sk)  as matches
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_referee      ref on ref.referee_sk     = f.referee_sk
join superligaen.gold.dim_match        m   on m.match_sk         = f.match_sk
join superligaen.gold.dim_date         d   on d.date_sk          = f.date_sk
join superligaen.gold.dim_match_result r   on r.match_result_sk = f.match_result_sk
join superligaen.gold.dim_team         t   on t.team_sk          = f.team_sk
where r.match_result in ('Win', 'Draw', 'Loss')
  and ref.referee_name not like '%Unknown%'
  and ref.referee_name not like '%Applicable%'
group by ref.referee_name, d.season, t.team_name
order by ref.referee_name, d.season desc, matches desc

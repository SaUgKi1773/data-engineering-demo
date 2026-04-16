select
    d.full_date             as match_date,
    m.match_round_name      as round,
    m.match_name,
    st.stadium_name         as stadium,
    m.season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m  on m.match_sk    = f.match_sk
join superligaen.gold.dim_date         d  on d.date_sk     = f.date_sk
join superligaen.gold.dim_stadium      st on st.stadium_sk = f.stadium_sk
join superligaen.gold.dim_match_result r  on r.match_result_sk = f.match_result_sk
where r.match_result = 'Pending'
group by all
order by d.full_date asc

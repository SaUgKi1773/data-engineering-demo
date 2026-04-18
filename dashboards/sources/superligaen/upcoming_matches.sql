select
    d.date                                                               as match_date,
    m.match_round_name                                                        as round,
    m.match_name,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name END)                as home_team,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name END)                as away_team,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name END)
        || '|||'
        || MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name END)         as match_key,
    st.stadium_name                                                           as stadium,
    m.season
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_match        m  on m.match_sk       = f.match_sk
join superligaen.gold.dim_date         d  on d.date_sk        = f.date_sk
join superligaen.gold.dim_stadium      st on st.stadium_sk    = f.stadium_sk
join superligaen.gold.dim_match_result r  on r.match_result_sk = f.match_result_sk
join superligaen.gold.dim_team         t  on t.team_sk        = f.team_sk
join superligaen.gold.dim_team_side    ts on ts.team_side_sk  = f.team_side_sk
where r.match_result = 'Pending'
group by d.date, m.match_round_name, m.match_name, st.stadium_name, m.season
order by d.date asc

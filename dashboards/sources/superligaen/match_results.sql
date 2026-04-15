select
    d.full_date                  as match_date,
    m.match_round_name           as round,
    m.season,
    t.team_name,
    ot.opponent_team_name        as opponent,
    ts.team_side                 as side,
    f.goals_scored               as gf,
    f.goals_conceded             as ga,
    r.match_result               as result,
    f.points_earned              as pts,
    st.stadium_name              as stadium
from gold.fct_match_results f
join gold.dim_team          t   on t.team_sk            = f.team_sk
join gold.dim_opponent_team ot  on ot.opponent_team_sk   = f.opponent_team_sk
join gold.dim_date          d   on d.date_sk            = f.date_sk
join gold.dim_match         m   on m.match_sk           = f.match_sk
join gold.dim_match_result  r   on r.match_result_sk    = f.match_result_sk
join gold.dim_team_side     ts  on ts.team_side_sk      = f.team_side_sk
join gold.dim_stadium       st  on st.stadium_sk        = f.stadium_sk
where r.match_result in ('Win', 'Draw', 'Loss')
order by d.full_date desc

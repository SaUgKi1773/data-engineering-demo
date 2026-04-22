select
    ref.referee_name,
    d.season,
    strftime(d.date, '%Y-%m-%d')   as match_date,
    m.match_round_name              as round,
    m.match_name,
    m.match_result                  as score,
    sum(f.yellow_cards)             as yellow_cards,
    sum(f.red_cards)                as red_cards,
    sum(f.fouls)                    as total_fouls
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_referee      ref on ref.referee_sk     = f.referee_sk
join superligaen.gold.dim_match        m   on m.match_sk         = f.match_sk
join superligaen.gold.dim_match_result r   on r.match_result_sk = f.match_result_sk
join superligaen.gold.dim_date         d   on d.date_sk          = f.date_sk
where r.match_result in ('Win', 'Draw', 'Loss')
  and ref.referee_name not like '%Unknown%'
  and ref.referee_name not like '%Applicable%'
group by ref.referee_name, d.season, d.date, m.match_round_name, m.match_name, m.match_result
order by ref.referee_name, d.season desc, d.date desc

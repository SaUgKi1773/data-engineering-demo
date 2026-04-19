select
    ref.referee_name,
    m.season,
    count(distinct m.match_sk)                                                              as matches_managed,
    sum(f.yellow_cards)                                                                     as total_yellow_cards,
    sum(f.red_cards)                                                                        as total_red_cards,
    sum(f.fouls)                                                                            as total_fouls,
    round(sum(f.yellow_cards)::double / count(distinct m.match_sk), 2)                     as avg_yellows_per_match,
    round(sum(f.red_cards)::double / count(distinct m.match_sk), 2)                        as avg_reds_per_match,
    round(sum(f.fouls)::double / count(distinct m.match_sk), 2)                            as avg_fouls_per_match,
    round(sum(f.yellow_cards + f.red_cards * 3)::double / count(distinct m.match_sk), 2)  as card_severity_index
from superligaen.gold.fct_match_results f
join superligaen.gold.dim_referee      ref on ref.referee_sk      = f.referee_sk
join superligaen.gold.dim_match        m   on m.match_sk          = f.match_sk
join superligaen.gold.dim_match_result r   on r.match_result_sk  = f.match_result_sk
where r.match_result in ('Win', 'Draw', 'Loss')
  and ref.referee_name not like '%Unknown%'
  and ref.referee_name not like '%Applicable%'
group by ref.referee_name, m.season
order by m.season desc, matches_managed desc

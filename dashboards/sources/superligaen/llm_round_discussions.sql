select
    s.season,
    s.round_number,
    s.match_name,
    p.persona_name,
    p.sort_order,
    s.message
from superligaen.silver.llm_match_discussions s
join superligaen.gold.dim_persona             p on p.persona_name = s.persona_name
order by s.season, s.round_number, s.match_name, p.sort_order

select
    season,
    round_number,
    match_name,
    persona_name,
    persona_icon,
    sort_order,
    message,
    generated_at
from superligaen.gold.llm_round_discussions
order by season, round_number, match_name, sort_order

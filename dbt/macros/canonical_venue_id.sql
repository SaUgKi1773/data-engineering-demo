-- Sportmonks sometimes issues a second venue id for a ground it already holds,
-- leaving one physical stadium split across two ids. Left alone that splits a
-- club's home record in two: separate rows in the fortress ranking, two pins on
-- the map, and understated totals on both.
--
-- Aliases are conformed here, at the single point where a venue id enters gold,
-- so dim_stadium emits one row per ground and every fact resolves to that one
-- stadium_sk.


{% macro canonical_venue_id(venue_id_col) %}
    {#-
        Maps a known duplicate venue id onto the id we keep. Deliberately a hand
        curated list rather than a coordinate or name heuristic: real grounds do
        sit within a few hundred metres of each other (shared complexes, rebuilt
        stadiums next to their predecessor), so an automatic rule would merge
        venues that are genuinely distinct.

        17691 "Brøndby IF's anlæg" -> 5659 "Brøndby Stadion". Same 29,000
        capacity, 160 m apart, both grass; only Brøndby ever played home at
        either, and the two labels alternate mid-season (Stadion in Feb and
        March 2022, anlæg on 3 April, Stadion again on 14 April), which no real
        ground move does. 17691 is the thinner record — null address, null
        country, city repeating its own name — and 5659 is the id carrying
        current fixtures.

        The canonical id on the right must exist in silver venues; it is the row
        whose attributes the dimension keeps.
    -#}
    (CASE {{ venue_id_col }}
        WHEN 17691 THEN 5659
        ELSE {{ venue_id_col }}
    END)
{% endmacro %}

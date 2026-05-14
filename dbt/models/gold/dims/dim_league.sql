SELECT
    ROW_NUMBER() OVER (ORDER BY l.id) AS league_sk,
    l.id                              AS league_id,
    l.name                            AS league_name,
    l.type                            AS league_type,
    l.image_path                      AS league_logo,
    c.name                            AS league_country,
    c.iso2                            AS league_country_code,
    c.flag_image_path                 AS league_country_flag
FROM {{ ref('league') }} l
LEFT JOIN {{ ref('core_countries') }} c ON c.id = l.country_id
WHERE l.id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown League',        NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable League', NULL, NULL, NULL, NULL, NULL

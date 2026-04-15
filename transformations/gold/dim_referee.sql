-- Dimension: referee
-- One row per distinct referee.
-- SK is stable: new referees get the next available SK; existing referees keep theirs.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_referee (
    referee_sk   INTEGER NOT NULL,
    referee_name VARCHAR
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_referee
SELECT * FROM (VALUES
    (-1, 'Unknown Referee'),
    (-2, 'Not Applicable Referee')
) t(referee_sk, referee_name)
WHERE t.referee_sk NOT IN (SELECT referee_sk FROM {db}.gold.dim_referee);

-- Insert new referees not yet in the dim
INSERT INTO {db}.gold.dim_referee
SELECT
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {db}.gold.dim_referee WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.referee_name) AS referee_sk,
    src.referee_name
FROM (
    SELECT DISTINCT referee AS referee_name
    FROM {db}.silver.fixtures
    WHERE referee IS NOT NULL AND referee <> ''
) src
WHERE src.referee_name NOT IN (
    SELECT referee_name FROM {db}.gold.dim_referee WHERE referee_name IS NOT NULL
);

SELECT  1 AS prediction_model_sk,
        'poisson-v1' AS prediction_model_version,
        'Poisson goals model: attack/defense strength vs league average with home advantage, time decay and shrinkage toward the mean. Published by the data science pipeline (ingestion/datascience).' AS prediction_model_description
UNION ALL SELECT -1, 'Unknown Prediction Model',        'Unknown Prediction Model'
UNION ALL SELECT -2, 'Not Applicable Prediction Model', 'Not Applicable Prediction Model'

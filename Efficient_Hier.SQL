-- Create series table
DROP TABLE TG;
CREATE COLUMN TABLE TG
(
TS INTEGER,
DUMMY INTEGER
)
SERIES
(
EQUIDISTANT
INCREMENT BY 1 
MINVALUE 0
MAXVALUE 36500
PERIOD FOR SERIES (TS)
);

-- Populate series table
SELECT GENERATED_PERIOD_START, 1
FROM SERIES_GENERATE_INTEGER(SERIES TABLE TG)
INTO TG;

-- ALTER TABLE TG SERIES REORGANIZE;
MERGE DELTA OF TG;

/*
> consider adding another column (incremented), perhaps, to improve join speed (for hierarchy building)
> and/or consider using window functions, can create basis for hierarchy traversal (maybe)
> and/or use window functions strictly, to solve this...
*/
DO
BEGIN

	hier =
		SELECT 
			*
		FROM 
			HIERARCHY
			(
				SOURCE
				(
					SELECT 
						MAP(LAG(TS) OVER (PARTITION BY DUMMY ORDER BY TS), TS - 1, TS - 1, NULL) AS PARENT_ID,
						TS AS NODE_ID
					FROM
					(
						SELECT DISTINCT 
							TS,
							DUMMY
						FROM 
							SOURCE_DATA
						INNER JOIN TG ON
							TG.TS BETWEEN SOURCE_DATA.START_DATE AND SOURCE_DATA.END_DATE
					)
				)
			);
	
	working_set =
		SELECT
			*
		FROM
			HIERARCHY_ANCESTORS
			(
				SOURCE :hier
				START 
				(
					SELECT 
						node_id AS start_id, hierarchy_rank AS start_rank
					FROM 
						:hier
				)
			);
			
		SELECT *
		FROM :working_set;
			
	A_windows =
		SELECT 
			START_ID AS NODE_ID,
			MIN(PARENT_ID) AS BLOCK_START
		FROM
			:working_set
		GROUP BY
			START_ID;
			
	windows =
		SELECT 
			BLOCK_START,
			MAX(NODE_ID) AS BLOCK_END,
			1 AS DUMMY
		FROM
			:A_windows
		WHERE
			BLOCK_START IS NOT NULL
		GROUP BY
			BLOCK_START;
		
	SELECT DISTINCT
		BLOCK_START,
		BLOCK_END,
		COALESCE(LAG(BLOCK_END) OVER (PARTITION BY DUMMY ORDER BY BLOCK_START) + 1, 1) AS WINDOW_START,
		COALESCE(BLOCK_START - 1, 100) AS WINDOW_END
	FROM
		:windows;

END


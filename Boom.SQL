DROP TABLE HIERT;
CREATE COLUMN TABLE HIERT
(
    PARENT_ID BIGINT,
    NODE_ID BIGINT
    -- PK should be both fields, but root node usually has PARENT_ID = NULL, so disregarding PK altogether
    -- also because NODE_ID can theoretically have multiple parents
);

DROP TABLE HIER_ANALYSIS;
CREATE COLUMN TABLE HIER_ANALYSIS
(
    NUM_NODES INTEGER,
    NUM_SOURCE_RECORDS INTEGER,
    NUM_HIER_RECORDS BIGINT,
    NUM_SPANTREE_RECORDS INTEGER,
    PRIMARY KEY (NUM_NODES)
);

DO
BEGIN

    DECLARE N INTEGER := 10;
    DECLARE I INTEGER := 0;
    DECLARE J INTEGER := 0;
    DECLARE K INTEGER := 0;
    DECLARE CNT INTEGER := 0;
    
    /*
        Hack to quickly build a table variable of incremeting values up to N.
        Should prob use an array, but getting errors when using array functions
        against "scalar" variable arrays (instead of arrays as a column type in a 
        table variable).
    */
    a =
        SELECT ROW_NUMBER() OVER (PARTITION BY F) AS VAL
        FROM
        (
            SELECT TOP :N '' AS F
            FROM OBJECTS
        );
        
    SELECT COUNT(*)
    INTO CNT
    FROM :a;

    -- should just use RECORD_COUNT() on table variable, but getting obscure error. 
    -- Old school way - leverage CNT, populated above. 
    FOR K IN 1 .. :CNT DO
    
        N := :K;
    
        FOR I IN 1 .. N DO
        
            INSERT INTO HIERT VALUES(NULL, :I);
            
            FOR J IN 1 .. N DO
    
                INSERT INTO HIERT VALUES(:I, :J);
                
            END FOR;
        
        END FOR;
        
        -- collect your data
        SELECT 
            :N AS NUM_NODES, 
            (SELECT COUNT(*) FROM HIERT) AS NUM_SOURCE_RECORDS,
            (SELECT COUNT(*) FROM HIERARCHY(SOURCE(SELECT NODE_ID, PARENT_ID FROM HIERT ORDER BY PARENT_ID, NODE_ID))) AS NUM_HIER_RECORDS,
            (SELECT COUNT(*) FROM HIERARCHY_SPANTREE(SOURCE(SELECT NODE_ID, PARENT_ID FROM HIERT ORDER BY PARENT_ID, NODE_ID))) AS NUM_HIER_RECORDS
        FROM
            DUMMY
        INTO
            HIER_ANALYSIS;

        -- truncate the source table
        TRUNCATE TABLE HIERT;
        
    END FOR;
    
    SELECT *
    FROM HIER_ANALYSIS
    ORDER BY NUM_NODES;
    
END;

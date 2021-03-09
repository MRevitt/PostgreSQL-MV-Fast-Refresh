/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: generateTestDataPg.sql
Author:       Mike Revitt
Date:         25/11/2020
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
25/11/2020  | M Revitt      | Initial version
------------+---------------+-------------------------------------------------------------------------------------------------------
Background:     These series of scripts create a set of test data that can be used for testing, the tables are created as
                Parent, Child, Grandchild and the names of the schema and tables can be passed as parameters.
                Not all parents have children and not all children have grandchildren
                The format of the tables is best described as customer, order and order items.
                These sripts also populate the tables with random data, which is always identical due to the use of a seed value
                Table format is as follows

                  T - 1       Parent
                 /  |  \
                T2  T4 T5     Child
                |   |
                T3  T6        Grand Child

Description:    This script creates the PostgreSQL Test Data, all dynamically generated but identical every time through the use
                of seeds

************************************************************************************************************************************
Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
************************************************************************************/

-- psql  -h localhost -p 5432 -d postgres -U mike -f 'generateTestDataPg.sql' -v DataOwner=mike_data -v iNoOfChildTables=$pgNoChildTables -v iRowsToInsert=$pgRowsToInsert -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase

\echo '\nInserting data into the tables'

SET tab.Schema            = :DataOwner;
SET tab.iNoOfChildTables  = :iNoOfChildTables;
SET tab.iRowsToInsert     = :iRowsToInsert;

DO $$
DECLARE
  tStartTime        TIMESTAMP   := clock_timestamp();
  cResult           CHAR(1)     := NULL;
  tSelectStatement  TEXT;
BEGIN
  cResult := mv$createMaterializedViewlog( 't1' );
  cResult := mv$createMaterializedViewlog( 't2' );
  cResult := mv$createMaterializedViewlog( 't3' );

  tSelectStatement := 'SELECT t1.code t1_code, t1.name t1_name FROM t1';
  cResult := mv$createMaterializedView(pViewName  => 'mv1', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  tSelectStatement := 'SELECT t2.code t2_code, t2.name t2_name FROM t2';
  cResult := mv$createMaterializedView(pViewName  => 'mv2', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  tSelectStatement := 'SELECT t3.code t3_code, t3.name t3_name FROM t3';
  cResult := mv$createMaterializedView(pViewName  => 'mv3', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  tSelectStatement := '
    SELECT
            t1.code t1_code, t1.name t1_name, t2.code t2_code, t2.name t2_name, t3.code t3_code, t3.name t3_name
    FROM
            t1, t2
    LEFT
            JOIN t3 ON  t3.parent   = t2.code
    WHERE
            t2.parent   = t1.code';

  cResult := mv$createMaterializedView(pViewName  => 'mv4', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  RAISE NOTICE 'Materialized View creation took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

DO $LoadData$
DECLARE

  tStartTime          TIMESTAMP   := clock_timestamp();
  tLastTime           TIMESTAMP   := clock_timestamp();
  iNoOfChildTables    INTEGER     := current_setting('tab.iNoOfChildTables');
  iRowsToInsert       INTEGER     := current_setting('tab.iRowsToInsert');
  iParentStartRow     INTEGER     := 1;
  iChild2StartRow     INTEGER     := 1;
  iChild4StartRow     INTEGER     := 1;
  iChild5StartRow     INTEGER     := 1;
  iRowCount           INTEGER     := 0;
  iLastCount          INTEGER     := 0;
  nSeedValue          NUMERIC     := 0.19620704;
  tFullTableName      TEXT        := current_setting('tab.Schema') || '.T';
  tSeedOutput         TEXT;

BEGIN
  tSeedOutput :=  SETSEED(nSeedValue);
  
  CALL  insertParentData(tFullTableName || '1', iRowsToInsert);
  iRowCount := iRowsToInsert;
  RAISE INFO '% Records Inserted in % seconds', to_char(iRowCount, '9,999,990'), clock_timestamp() - tLastTime;

  FOR iParentRowNo in iParentStartRow .. iParentStartRow + iRowsToInsert - 1
  LOOP
    if iNoOfChildTables > 0
    THEN
      CALL  insertChildData
            (
              tFullTableName,
              '2',
              '3',
              iParentRowNo,
              iRowsToInsert,
              iChild2StartRow,
              iRowCount
            );
    END IF;
    if iNoOfChildTables > 1
    THEN
      CALL  insertChildData
            (
              tFullTableName,
              '4',
              '6',
              iParentRowNo,
              iRowsToInsert,
              iChild4StartRow,
              iRowCount
            );
    END IF;
    if iNoOfChildTables > 2
    THEN
      CALL  insertChildData
            (
              tFullTableName,
              '5',
              '0',
              iParentRowNo,
              iRowsToInsert,
              iChild4StartRow,
              iRowCount
            );
    END IF;

    IF MOD( iParentRowNo, 4000 ) = 0
    THEN
      RAISE INFO '% Records Inserted in % seconds', to_char(iRowCount - iLastCount, '9,999,990'), clock_timestamp() - tLastTime;
      tLastTime   := clock_timestamp();
      iLastCount  :=  iRowCount;
      COMMIT;
    END IF;
  END LOOP;

  RAISE INFO 'Loaded a total of % Records in %', to_char(iRowCount, '9,999,999,990'), clock_timestamp() - tStartTime;

END $LoadData$;

\c :DataBase :PackageOwner
GRANT SELECT  ON  log$_t1 TO :DataOwner;
GRANT SELECT  ON  log$_t2 TO :DataOwner;
GRANT SELECT  ON  log$_t3 TO :DataOwner;

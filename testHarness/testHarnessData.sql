/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: testHarness.sql
Author:       Mike Revitt
Date:         12/011/2018
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
11/03/2018  | M Revitt      | Initial version
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

*************************************************************************************
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
/*
psql -h localhost -p 5432 -d postgres -U mike_data -q -f testHarnessData.sql
*/

\echo '\nCreate Test Harness Data\n'

DO $LoadData$
DECLARE
  tStartTime      TIMESTAMP := clock_timestamp();

  iRows           INTEGER   := 0;
  iT2Code         INTEGER   := 0;
  iParentRow      INTEGER   := 0;
  iParentRows     INTEGER   := 6;
  iChildRow       INTEGER   := 0;
  iChildRows      INTEGER   := 3;
  iGrandChildRow  INTEGER   := 0;
  iGrandChildRows INTEGER   := 2;

  tSqlStatement   TEXT;

BEGIN
  FOR iParentRow IN 1 .. iParentRows
  LOOP
    tSqlStatement := 'INSERT INTO t1(name, key2) VALUES(''Name ' || iParentRow || ''', ''Key ' || iParentRow || ''')';
    EXECUTE tSqlStatement;
    iRows := iRows + 1;

    FOR iChildRow IN 1 .. iChildRows
    LOOP
      iT2Code       := ( iParentRow * iParentRows ) + iChildRow;
      tSqlStatement := 'INSERT INTO t2(code, parent, name, key2) VALUES(' || iT2Code || ',' || iParentRow || ',''Name ' || iChildRow || ''', ''Key ' || iChildRow || ''')';
      EXECUTE tSqlStatement;
      iRows := iRows + 1;

      FOR iGrandChildRow IN 1 .. iGrandChildRows
      LOOP
        IF  MOD(iRows,    3 ) > 0
        AND MOD(iT2Code,  4 ) > 0
        THEN
          tSqlStatement := 'INSERT INTO t3(parent, name, key2) VALUES(' || iT2Code || ',''Name ' || iGrandChildRow || ''', ''Key ' || iGrandChildRow || ''')';
          EXECUTE tSqlStatement;
          iRows := iRows + 1;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RAISE INFO 'Loaded a total of % Records in %', to_char(iRows, '990'), clock_timestamp() - tStartTime;

  EXCEPTION
  WHEN OTHERS
  THEN
    RAISE INFO      '%',            tSqlStatement;
    RAISE INFO      'Error %:- %:', SQLSTATE, SQLERRM;
    RAISE EXCEPTION '%',            SQLSTATE;
END
$LoadData$
LANGUAGE    plpgsql;

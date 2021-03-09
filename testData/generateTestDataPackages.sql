/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: generateTestDataPackages.sql
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

Description:    This script creates the Generic Packages that create the PostgreSQL Test Data
                all dynamically generated but identical every time through the use of seeds

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

-- psql -h localhost -p 5432 -d postgres -U mike -q -f generateTestData.sql -v DataOwner=mike_data


/* ****************************************************************************************************************************** */
CREATE OR REPLACE
PROCEDURE :DataOwner.insertParentData( tFullTableName  IN  TEXT, iParentRowsToInsert IN INTEGER )
AS
$BODY$
DECLARE
    tSqlStatement TEXT;
BEGIN
    tSqlStatement := 'INSERT
                      INTO '||tFullTableName  ||
                     '(
                              name, key2, description
                      )
                      SELECT
                              LEFT(MD5(RANDOM()::TEXT), ROUND(RANDOM() * 9 + 6 )::INTEGER),
                              MD5(v::TEXT),
                              MD5(RANDOM()::TEXT) || MD5(v::TEXT)
                      FROM
                              GENERATE_SERIES(1,' || iParentRowsToInsert || ') v';
    EXECUTE tSqlStatement;

    EXCEPTION
    WHEN OTHERS
    THEN
        RAISE INFO      'PROCEDURE link_test.insertParentData( %, % )', tFullTableName, iParentRowsToInsert;
        RAISE INFO      '%',            tSqlStatement;
        RAISE INFO      'Error %:- %:', SQLSTATE, SQLERRM;
        RAISE EXCEPTION '%',            SQLSTATE;
END
$BODY$
LANGUAGE    plpgsql
SECURITY    DEFINER;
/* ****************************************************************************************************************************** */
CREATE OR REPLACE
PROCEDURE :DataOwner.insertChildData
          (
            tFullTableName      IN    TEXT,
            iChildTableNo       IN    INTEGER,
            iGrandChildTableNo  IN    INTEGER,
            iParentRowNo        IN    INTEGER,
            iParentRowsToInsert IN    INTEGER,
            iChildStartRow      INOUT INTEGER,
            iRowCount           INOUT INTEGER
          )
AS
$BODY$
DECLARE
    nMonthsOfData       NUMERIC := iParentRowsToInsert / ((365/12) * 24 * 60);
    iChildRowNo         INTEGER;
    iChildRecords       INTEGER;
    iGrandChildRecords  INTEGER;
    tSqlStatement       TEXT;

BEGIN
    iChildRecords := FLOOR(RANDOM() * 12);
    tSqlStatement :=  'INSERT '                                                                 ||
                      'INTO '||tFullTableName  || iChildTableNo                                 ||
                      '('                                                                       ||
                      '        parent, name, key2, order_date, description'                     ||
                      ')'                                                                       ||
                      'SELECT '                                                                 ||
                              iParentRowNo  || ','                                              ||
                            ' LEFT(MD5(RANDOM()::TEXT), ROUND(RANDOM() * 9 + 6 )::INTEGER),'    ||
                            ' MD5(v::TEXT),'                                                    ||
                            ' clock_timestamp() +  ''-'     || nMonthsOfData || ' Months'' '    ||
                                                    '+ '''  || iParentRowNo  || ' Minutes'','   ||
                            ' MD5(RANDOM()::TEXT) || MD5(v::TEXT)'                              ||
                      'FROM'                                                                    ||
                            ' GENERATE_SERIES(1, ' || iChildRecords || ' ) v';
    EXECUTE tSqlStatement;

    iRowCount := iRowCount + iChildRecords;

    IF  iChildRecords       > 0
    AND iGrandChildTableNo  > 0
    THEN
      FOR iChildRowNo IN iChildStartRow .. iChildStartRow + iChildRecords - 1
      LOOP
        iGrandChildRecords := FLOOR(RANDOM() * 30);
        tSqlStatement :=  'INSERT '                                                                 ||
                          'INTO '||tFullTableName || iGrandChildTableNo                             ||
                          '('                                                                       ||
                          '        parent, name, key2, order_date, order_value, description'        ||
                          ')'                                                                       ||
                          'SELECT '                                                                 ||
                                  iChildRowNo  || ','                                               ||
                                ' LEFT(MD5(RANDOM()::TEXT), ROUND(RANDOM() * 9 + 6 )::INTEGER),'    ||
                                ' MD5(v::TEXT),'                                                    ||
                                ' clock_timestamp() +  ''-'     || nMonthsOfData  || ' Months'' '   ||
                                                        '+ '''  || iParentRowNo   || ' Minutes'' '  ||
                                                        '+ '''  || iChildRowNo    || ' Seconds'','  ||
                                ' ROUND((RANDOM() * 2400)::NUMERIC, 2),'                            ||
                                ' MD5(RANDOM()::TEXT) || MD5(v::TEXT)'                              ||
                          'FROM'                                                                    ||
                                ' GENERATE_SERIES(1, ' || iGrandChildRecords || ' ) v';
        EXECUTE tSqlStatement;

        iRowCount := iRowCount + iGrandChildRecords;
      END LOOP;
      iChildStartRow := iChildStartRow + iChildRecords;
    END IF;

    EXCEPTION
    WHEN OTHERS
    THEN
        RAISE INFO      'PROCEDURE link_test.insertChildData( %, %, %, %, %, % )',
                                        tFullTableName, iChildTableNo, iGrandChildTableNo, iParentRowNo, iChildStartRow, iRowCount;
        RAISE INFO      '%',            tSqlStatement;
        RAISE INFO      'Error %:- %:', SQLSTATE, SQLERRM;
        RAISE EXCEPTION '%',            SQLSTATE;
END
$BODY$
LANGUAGE    plpgsql
SECURITY    DEFINER;

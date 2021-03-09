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
Background:     PostGre does not support Materialized View Fast Refreshes, this suite of scripts is a PL/SQL coded mechanism to
                provide that functionality, the next phase of this projecdt is to fold these changes into the PostGre kernel.

Description:    This script creates the SCHEMA and USER to hold the Materialized View Fast Refresh code along with the necessary
                data dictionary views

Issues:         There is a bug in RDS for PostGres version 10.4 that prevents this code from working, this but is fixed in
                versions 10.5 and 10.3

                https://forums.aws.amazon.com/thread.jspa?messageID=860564

Help:           Help can be invoked by running the rollowing command from within PostGre

                DO $$ BEGIN RAISE NOTICE '%', mv$stringConstants('HELP_TEXT'); END $$;

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
psql -h localhost -p 5432 -d postgres -U mike_data -q -f testHarness.sql -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase
*/

SET CLIENT_MIN_MESSAGES = NOTICE;

\prompt 'Query the data from the base tables LEFT OUTER JOIN t3' mike
\C 'Base Tables'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent   = t2.code
WHERE
        t2.parent   = t1.code
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Query the data from the base tables RIGHT OUTER JOIN t2' mike
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t3
RIGHT   OUTER JOIN t2
ON      t3.parent   = t2.code
WHERE
        t2.parent   = t1.code
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Create materialized view Logs' mike
DO $$
DECLARE
  tStartTime  TIMESTAMP := clock_timestamp();
  cResult     TEXT      := NULL;
BEGIN
  cResult := mv$createMaterializedViewlog( 't1' );
  cResult := mv$createMaterializedViewlog( 't2' );
  cResult := mv$createMaterializedViewlog( 't3' );
  RAISE NOTICE 'Materialized View Log creation took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\prompt 'Create materialized view using LEFT OUTER JOIN t3' mike
DO $$
DECLARE
  tStartTime    TIMESTAMP := clock_timestamp();
  cResult       CHAR(1)   := NULL;
  pSqlStatement TEXT;
BEGIN
  pSqlStatement := '
    SELECT
            t1.code t1_code, t1.name t1_name, t2.code t2_code, t2.name t2_name, t3.code t3_code, t3.name t3_name
    FROM
            t1, t2
    LEFT
            JOIN t3 ON  t3.parent   = t2.code
    WHERE
            t2.parent   = t1.code';

    cResult := mv$createMaterializedView
    (
        pViewName           => 'mv4',
        pSelectStatement    =>  pSqlStatement,
        pFastRefresh        =>  TRUE
    );
    RAISE NOTICE 'Complex Materialized View creation took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\prompt 'The first thing to do is check the contents of our new Materialized View' mike
\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Then insert some records into the Child table, INSERT INTO t2 WHERE code = 100' mike
INSERT  INTO
t2(     code,   parent, name,       key2)
VALUES( 100,    1,     'Name 100', 'Key 100');

\prompt 'Check the log file - NOTE: This will fail as we do not have sufficient privileges to see them' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t2;

\prompt 'So grant some temporary permissions onto the log tables and try again' mike
\c :DataBase :PackageOwner
GRANT SELECT  ON  log$_t1 TO :DataOwner;
GRANT SELECT  ON  log$_t2 TO :DataOwner;
GRANT SELECT  ON  log$_t3 TO :DataOwner;
\c :DataBase :DataOwner

SET CLIENT_MIN_MESSAGES = NOTICE;
-- \set VERBOSITY terse

\prompt 'Now that we have granted temporary permissions you should be able to see the data' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t2;

\prompt 'Now Compare the data between the base tables and Materialized View - Base Tables First' mike
\C 'Base Tables'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent   = t2.code
WHERE
        t2.parent   = t1.code
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Then the Materialized View' mike
\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Now refresh the Materialized View and check again' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'And if we check the Materialized View Log, it is now empty' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t2;

\prompt 'Next I will insert some records into the Grandchild table, INSERT INTO t3 WHERE code = 1000' mike

INSERT  INTO
t3(     code,   parent, name,        key2)
VALUES( 1000,   100,   'Name 1000', 'Key 1000');

\prompt 'And check the Materialized View Log' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t3;

\prompt 'Now Compare the data between the base tables and Materialized View - Base Tables First' mike
\C 'Base Tables'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent   = t2.code
WHERE
        t2.parent   = t1.code
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Then the Materialized View' mike
\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Now refresh the Materialized View and check again' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'Note that even though this was an insert, it has applied an update to the Materialized View\n'

\prompt 'Now lets perform an update on the Parent table. UPDATE t1 WHERE code = 1' mike
UPDATE  t1
SET     name  = 'New Name'
WHERE   code  = 1;

\prompt 'And check the Materialized View Log - NOTE: the dmltype is an UPDATE this time' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t1;

\prompt 'Compare the data between the base tables and Materialized View - Base Tables First' mike
\C 'Base Tables'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent   = t2.code
WHERE
        t2.parent   = t1.code
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Then the Materialized View' mike
\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Now refresh the Materialized View and check again' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'This time you should notice that a single update to the Parent table, updated 4 rows in the Materialized View\n'

\prompt 'Now I will update a child table row. UPDATE t2 WHERE code = 15' mike
UPDATE  t2
SET     name  = 'Second Update'
WHERE   code  =  15;

\prompt 'Check the Materialized View Log - again you should see a single UPDATE record' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t2;

\prompt 'Now refresh the Materialized View and we should see the changes to the 2 affected records' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Finally I will update a grandchild table row. UPDATE t3 WHERE code = 18' mike
UPDATE  t3
SET     name  = 'Third Update'
WHERE   code  =  18;

\prompt 'Check the Materialized View Log - again there is a single update entry' mike
SELECT  *
FROM    log$_t3;

\prompt 'And refresh the Materialized View to see the results' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\prompt 'Now I am going to try some deletes, starting by removing a grandchild row from t3 WHERE code = 14' mike
DELETE
FROM    t3
WHERE   code  = 14;

\prompt 'Check the Materialized View Log - NOTE: the dmltype is a DELETE this time' mike
\C 'Materialized View Log'
SELECT  *
FROM    log$_t3;

\prompt 'Now refresh the Materialized View and check the result' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\C 'Materialized View'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\echo   'Now I will delete a child row'
\echo   'First delete the grandchild records,  DELETE FROM t3 WHERE parent = 26'
\prompt 'And then delete the child record,     DELETE FROM t2 WHERE code   = 26' mike
DELETE
FROM    t3
WHERE   parent  = 26;

DELETE
FROM    t2
WHERE   code    = 26;

\echo   '\nNote that this time there are 2 records in the log table for the grandchild table'
\C 'Materialized View Log'
SELECT  *
FROM    log$_t3;

\echo   'But only 1 record in the log table for the child table'
SELECT  *
FROM    log$_t2;

\prompt 'Lets apply those changes by refreshing the Materialized View and check the results' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'You should be able to spot that row 26 is now missing\n'

\echo   'Now I am going to delete a parent row'
\echo   'First delete the grandchild records,  DELETE FROM t3 WHERE parent IN ( SELECT code FROM t2 WHERE parent = 1 )'
\echo   'And then delete the child record,     DELETE FROM t2 WHERE parent = 1'
\prompt 'And finally delete the parent,        DELETE FROM t1 WHERE code = 1' mike
DELETE
FROM    t3
WHERE   parent
IN(     SELECT  code
        FROM    t2
        WHERE   parent = 1
);

DELETE
FROM    t2
WHERE   parent  = 1;

DELETE
FROM    t1
WHERE   code    = 1;

\prompt 'Now lets look at all the log tables' mike
\C 'Materialized View Log T3'
SELECT  *
FROM    log$_t3;

\C 'Materialized View Log T2'
SELECT  *
FROM    log$_t2;

\C 'Materialized View Log T1'
SELECT  *
FROM    log$_t1;
\echo   'This time there are a lot more rows in the log tables\n'

\prompt 'So lets refresh the View and look at the records in the Materialized View' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'You should be able to spot that parent row 1 is now missing\n'

\echo   'For the next test I will show you what happens when you remove the last Grandchild row from an outer joined table'
\prompt 'Keep your eye on t2_code 37' mike
DELETE
FROM    t3
WHERE   code = 17;

DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'Note that the row is still there but the Grandchild values are now NULL'
\echo   'As with the insert earllier on, this delete has been applied as an update to the Materialized View\n'

\prompt 'Now I will create a set of additional Materialized Views on the base tables, 1 for each base table' mike
DO $$
DECLARE
    tStartTime        TIMESTAMP   := clock_timestamp();
    cResult           CHAR(1)     := NULL;
    tSelectStatement  TEXT;
BEGIN
  tSelectStatement  := 'SELECT t1.code t1_code, t1.name t1_name FROM t1';
  cResult := mv$createMaterializedView(pViewName  => 'mv1', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  tSelectStatement  := 'SELECT t2.code t2_code, t2.name t2_name FROM t2';
  cResult := mv$createMaterializedView(pViewName  => 'mv2', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  tSelectStatement  := 'SELECT t3.code t3_code, t3.name t3_name FROM t3';
  cResult := mv$createMaterializedView(pViewName  => 'mv3', pSelectStatement  =>  tSelectStatement,  pFastRefresh  =>  TRUE);

  RAISE NOTICE 'Simple Snapshot Creation took %', clock_timestamp() - tStartTime;
END $$;

\prompt 'Lets have a look at these new Materialized Views' mike
\C 'Materialized View mv1'
SELECT
        t1_code, t1_name
FROM
        mv1;
\prompt 'Press <Return> for mv2' mike

\C 'Materialized View mv2'
SELECT
        t2_code, t2_name
FROM
        mv2;

\prompt 'Press <Return> for mv3' mike
\C 'Materialized View mv3'
SELECT
        t3_code, t3_name
FROM
        mv3;

\prompt 'Press <Return> for mv4' mike
\C 'Materialized View mv4'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;

\echo   'Now lets see what happens when I insert a row into the Child table t2 and refresh only the Materialized View mv2'
\prompt 'INSERT INTO t2 WHERE code = 100' mike

INSERT  INTO
t2(     code, parent, name,       key2)
VALUES( 100,  2,     'Name 100', 'Key 100' );

\C 'Materialized View Log'
SELECT  *
FROM    log$_t2;
\echo   'The first thing to note is the value in the bitmap value which is now 3'
\echo   'signifying that 2 Materialized Views have an interest in the base table.'
\echo   'Indicated by the bitmap value of 3, (2^0 + 2^1)\n'

\prompt 'Now I will refresh the Materialized View mv2 and see what that does' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv2',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\C 'Materialized View mv2'
SELECT
        t2_code, t2_name
FROM
        mv2;
\echo   'You can see that the new row has been inserted into the Materialized View\n'

\prompt 'But what about the Materialized View mv4, lets have a look' mike
\C 'Materialized View mv4'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;
\echo   'As expected the row is not here, because we have not updated this Materialized View yet\n'

\prompt 'But what happened to the log file' mike
\C 'Materialized View Log log$_t2'
SELECT  *
FROM    log$_t2;
\echo   'This was updated to show that the Materialized View with a bit of 1 no longer has an interest in this INSERT'
\echo   'But the Materialized View with a bit of 0 still has an interest.'
\echo   'Indicated by the bitmap value which is now 1, (2^0 only)\n'

\prompt 'Now we can refresh the Materialized View mv4' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView
    (
        pViewName       => 'mv4',
        pFastRefresh    =>  TRUE
    );
    RAISE NOTICE 'Fast Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\C 'Materialized View mv4'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
ORDER
BY      t1_code, t2_code, t3_code;


\prompt 'And have a look at what that did to the log file' mike
\C 'Materialized View Log log$_t2'
SELECT  *
FROM    log$_t2;
\echo   'Note the Materialized View Log record has been removed'
\prompt 'All Materialized Views with an interest in this INSERT have been refreshed' mike


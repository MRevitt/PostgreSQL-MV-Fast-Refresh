/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: loadTest.sql
Author:       Mike Revitt
Date:         09/04/2019
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
09/04/2019  | M Revitt      | Initial version
------------+---------------+-------------------------------------------------------------------------------------------------------
Background:     PostGre does not support Materialized View Fast Refreshes, this suite of scripts is a PL/SQL coded mechanism to
                provide that functionality, the next phase of this projecdt is to fold these changes into the PostGre kernel.

Description:    This script creates 1,000,000 of data to stress test the Materialized View process talong with the necessary
                Materialized Views to run the test scenarios

Issues:         There is a bug in RDS for PostGres version 10.4 that prevents this code from working, this but is fixed in
                versions 10.5 and 10.3

                https://forums.aws.amazon.com/thread.jspa?messageID=860564

************************************************************************************************************************************
Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
***********************************************************************************************************************************/

-- psql -h localhost -p 5432 -d postgres -U mike_data -q -f loadTest.sql -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase

SET CLIENT_MIN_MESSAGES = NOTICE;

\echo   '\nThe first thing to do is refresh all of the Materialized Views'
\prompt 'First check the number of updates and inserts for table t1 and then refresh mv1 with a Full Refresh' mike
\C 'Materialized View log changs in log$_t1'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t1;

DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv1', pFastRefresh => FALSE);
    RAISE NOTICE 'Full Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\echo
\prompt 'Then check the number of updates and inserts for table t2 and then refresh mv2 with a Full Refresh' mike
\C 'Materialized View changs in log log$_t2'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t2;

DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv2', pFastRefresh => FALSE);
    RAISE NOTICE 'Full Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\echo
\prompt 'Finally check the number of updates and inserts for table t3 and then refresh mv3 with a Full Refresh' mike
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t3;

DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv3', pFastRefresh => FALSE);
    RAISE NOTICE 'Full Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\echo   '\nI have now updated all of the simple Materialized Views, but not the Complex Materialized View mv4'
\prompt 'So what was the impact on the Materialized View Logs' mike
\C 'Materialized View log log$_t1'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t1;

\C 'Materialized View log log$_t2'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t2;

\C 'Materialized View log log$_t3'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t3;
\echo   'As you can see each of the Materialized View Log tables has the same number or records as before'
\echo   'So lets look at one at random to see what is going on'

SELECT  *
FROM    log$_t1
WHERE   sequence$ = 10;
\echo   'As you can see there is a value in the bitmap column with a value of 2'
\echo   'This signifies that a Materialized View with a bit of 1 has an interest in the base table, (2^1)\n'


\prompt 'Now I will refresh the complex Materialized View, mv4. Which will perform 4,001,637 record updates' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv4', pFastRefresh => FALSE);
    RAISE NOTICE 'Full Snapshot Refresh took %', clock_timestamp() - tStartTime;
END $$;

\echo
\prompt 'Now that that has finished lets have a look at the Materialized View Logs again' mike
\C 'Materialized View log log$_t1'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t1;

\C 'Materialized View log log$_t2'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t2;

\C 'Materialized View log log$_t3'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total" FROM log$_t3;
\echo   'As you can see these are all now empty as all Materialized Views have been refreshed'
\echo   'And even though we did a Full refresh the Material View Logs were still updated as expected\n'

\prompt 'Now I will add some indexes to the complex Materialized View so I can manipulate the data in specified rows' mike

CREATE
INDEX   t1_code_ind
ON      mv4( t1_code );

\echo   '\nYou should have notied that this failed as we do not have sufficient privileges to modify any of the Materialized View objects'
\prompt 'So I need to connect as the owner of the Materialized View and try again' mike

\c :DataBase :PackageOwner
\echo 'Create index on t1'
CREATE
INDEX   t1_code_ind
ON      mv4( t1_code );

\echo 'Create index on t2'
CREATE
INDEX   t2_code_ind
ON      mv4( t2_code );

\echo 'Create index on t3'
CREATE
INDEX   t3_code_ind
ON      mv4( t3_code );
\c :DataBase :DataOwner

\echo '\n And now perform some simple updates. First identify a Parent row to update\n'
\C 'Base Table Row sample based on t1 & t3 table row'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent =  t2.code
WHERE
        t2.parent =  t1.code
AND     t1.code   = 7461
AND     t3.code   = 600788
ORDER
BY      t1.code, t2.code, t3.code;

\prompt 'Then check how many rows will be affeted by this update' mike
\C 'Total rows to be refreshed in view mv4'
SELECT  TO_CHAR( COUNT(*), '9,999,990' ) "Row Total"
FROM    mv4
WHERE   t1_code = 7461;

\echo 'And perform the update, UPDATE t1 WHERE code = 7461'
UPDATE  t1
SET     name  = 'First Update'
WHERE   code  =  7461;

\prompt 'Now lets have a look at the contents of the Materialized View Log' mike
\C 'Materialized View changs in log log$_t1'
SELECT  *
FROM    log$_t1;
\echo   'Notice that there is only 1 update showing even though 137 rows are impacted\n'

\prompt 'Then refresh Materialized View mv4 and check the results' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv4', pFastRefresh => TRUE);
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\C 'Materialized View Row sample based on t1 & t3 table row'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
WHERE
        t1_code   = 7461
AND     t3_code   = 600788;

\C 'Sum of Materialized View Rows based on t1 table row'
SELECT
        COUNT(t1_code), t1_name
FROM
        mv4
WHERE
        t1_code   = 7461
GROUP
BY      t1_name;


\echo   'Now lets perform a bulk update on the child table t2'
\prompt 'First identify the Child rows to update based on all t2 rows created between minutes 3 and 6' mike
\C 'Total rows to be refreshed in view mv4'
SELECT TO_CHAR( COUNT(*), '9,999,990' ) "Row Total"
FROM    mv4
WHERE   t2_code
IN(     SELECT  code
        FROM    t2
        WHERE   created
        BETWEEN(SELECT MIN(created) + INTERVAL '3 minutes' FROM t2)
        AND(    SELECT MIN(created) + INTERVAL '6 minutes' FROM t2)
);

\prompt 'Then update all of the t2 rows created between minutes 3 and 6' mike
UPDATE  t2
SET     name = 'Second Update'
WHERE   code
IN(     SELECT  code
        FROM    t2
        WHERE   created
        BETWEEN(SELECT MIN(created) + INTERVAL '3 minutes' FROM t2)
        AND(    SELECT MIN(created) + INTERVAL '6 minutes' FROM t2)
);

\echo 'And check the number of updates in the Materialized View Log\n'
\C 'Materialized View changs in log log$_t2'
SELECT  TO_CHAR( COUNT(*), '9,999,990' ) "Row Total"
FROM    log$_t2;

\prompt 'Now we will perform a Materialized View Fast Refresh of around 1,300,000 rows' mike
DO $$
DECLARE
    tStartTime  TIMESTAMP   := clock_timestamp();
    cResult     CHAR(1)     := NULL;
BEGIN
    cResult := mv$refreshMaterializedView(pViewName => 'mv4', pFastRefresh => TRUE);
    RAISE NOTICE 'Fast Snapshot Refresh took % % %', clock_timestamp() - tStartTime, chr(10), chr(10);
END $$;

\prompt 'Lets look at a sample row to view the changes' mike
\C 'Materialized View Row sample based on t2 updates'
SELECT
        t1_code, t1_name, t2_code, t2_name, t3_code, t3_name
FROM
        mv4
WHERE
        t1_code   = 16512
AND     t2_code   = 91241;

\prompt 'And check the same row in the base tables' mike
\C 'Base Tables Row sample based on t2 updates'
SELECT
        t1.code, t1.name, t2.code, t2.name, t3.code, t3.name
FROM
        t1, t2
LEFT    OUTER JOIN t3
ON      t3.parent   = t2.code
WHERE
        t2.parent   =  t1.code
AND     t1.code   = 16512
AND     t2.code   = 91241
ORDER
BY      t1.code, t2.code, t3.code;

\prompt '' mike

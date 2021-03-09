/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: CreateMikeTestData.sql
Author:       Mike Revitt
Date:         14/11/2018
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
14/11/2018  | M Revitt      | Initial version
------------+---------------+-------------------------------------------------------------------------------------------------------
Background:     PostGre does not support Materialized View Fast Refreshes, this suite of scripts is a PL/SQL coded mechanism to
                provide that functionality, the next phase of this projecdt is to fold these changes into the PostGre kernel.

Description:    Sample script to create the test database objects, T1 through T6 as Parent, Child, Grandchild


Issues:         There is a bug in RDS for PostGres version 10.4 that prevents this code from working, this but is fixed in
                versions 10.5 and 10.3

                https://forums.aws.amazon.com/thread.jspa?messageID=860564

************************************************************************************************************************************
Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
***********************************************************************************************************************************/

-- psql -h localhost -p 5432 -d postgres -U mike -q -f createMikeTestData.sql -v DataOwner=mike_data -v SuperUser=mike -v Password=aws-oracle -v DataBase=postgres

SET CLIENT_MIN_MESSAGES =  NOTICE;
SET tab.DataOwner       = :DataOwner;

CREATE  ROLE   :DataOwner WITH  LOGIN PASSWORD :Password;

SELECT  TRIM(REPLACE(TRIM(REPLACE(REPLACE(CURRENT_SETTING('search_path'),CURRENT_SETTING('tab.DataOwner'),''),' ','')),',,',','),',') AS "oldSearchPath" \gset

ALTER   DATABASE   :DataBase      SET   SEARCH_PATH=:oldSearchPath, :DataOwner;

GRANT  :DataOwner TO  :SuperUser;

CREATE  SCHEMA :DataOwner AUTHORIZATION :DataOwner;

\c :DataBase :DataOwner

SET tab.Schema  = :DataOwner;

\echo '\nCreating Test Data Objects with the following structure'
\echo '-------------------------------------------------------'
\echo '         T - 1     Parent'
\echo '        /  |  \\'
\echo '      T2   T4  T5  Child'
\echo '      |    |'
\echo '      T3   T6      Grand Child\n\n'

DO $$
DECLARE
    iTableNo            INTEGER;

    tChildColumns       TEXT;
    tCreateTable        TEXT;
    tFullTableName      TEXT  := current_setting('tab.Schema') || '.T';
    tOtherColumns       TEXT;
    tParentColumns      TEXT;
    tSqlStatement       TEXT;
BEGIN
    tCreateTable        := 'CREATE TABLE '          || tFullTableName;
    tParentColumns      := '
    (
        code            SERIAL  NOT NULL  PRIMARY KEY';

    tChildColumns   := '
    (
        code            SERIAL  NOT NULL  PRIMARY         KEY,
        parent          INTEGER NOT NULL  REFERENCES ' || tFullTableName;

    tOtherColumns   := ',
        name            TEXT        NOT NULL,
        key1            SERIAL      NOT NULL,
        key2            TEXT        NOT NULL,
        created         TIMESTAMP   NOT NULL  DEFAULT clock_timestamp(),
        expiry_date     TIMESTAMP   NOT NULL  DEFAULT clock_timestamp() + ''2 Years'',
        order_date      TIMESTAMP       NULL,
        order_value     MONEY           NULL,
        description     TEXT            NULL,
        updated         TIMESTAMP       NULL
    )';

    iTableNo := 1;
    tSqlStatement   :=  tCreateTable   || iTableNo  || tParentColumns || tOtherColumns;
    EXECUTE tSqlStatement;
    RAISE   INFO  'Create Table %', tFullTableName || iTableNo;

    FOR iTableNo IN 2 .. 6
    LOOP
      tSqlStatement   :=  tCreateTable  || iTableNo || tChildColumns  ||
                          CASE iTableNo
                            WHEN 2 THEN '1'
                            WHEN 3 THEN '2'
                            WHEN 4 THEN '1'
                            WHEN 5 THEN '1'
                            WHEN 6 THEN '4'
                          END ||
                          tOtherColumns;
      EXECUTE tSqlStatement;
      RAISE   INFO  'Create Table %', tFullTableName || iTableNo;
    END LOOP;
END $$;

\echo '\n'


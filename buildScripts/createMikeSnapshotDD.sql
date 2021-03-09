/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: CreateMikeSnapshotDD.sql
Author:       Mike Revitt
Date:         12/11/2018
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
12/11/2018  | M Revitt      | Initial version
------------+---------------+-------------------------------------------------------------------------------------------------------
Background:     PostGre does not support Materialized View Fast Refreshes, this suite of scripts is a PL/SQL coded mechanism to
                provide that functionality, the next phase of this projecdt is to fold these changes into the PostGre kernel.

Description:    This script creates the SCHEMA and USER to hold the Materialized View Fast Refresh code along with the necessary
                data dictionary views, then it calls the create function scripts in the correct order

Notes:          There are 2 data dictionary tables
                o   pg$mview_logs
                o   pg$mviews

                Access is controlled via 3 database roles
                o   pgmv$_execute   -   is given the privileges to run the public materialized view functions
                o   pgmv$_usage     -   is given usage on the :PackageOwner schema
                o   pgmv$_view      -   is given access to the DDL tables

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

-- psql -h localhost -p 5432 -d postgres -U mike -q -f CreateMikeSnapshotDD.sql -v PackageOwner=mike_pgmview -v SuperUser=mike -v Password=aws-oracle -v DataBase=postgres

\echo '\nCreating MV Fast Refresh Data Dictionary Objects\n'

SET     CLIENT_MIN_MESSAGES =  ERROR;
SET     tab.PackageOwner    = :PackageOwner;

CREATE  EXTENSION  IF  NOT  EXISTS"uuid-ossp";

SET     CLIENT_MIN_MESSAGES = NOTICE;

CREATE  ROLE  pgmv$_execute;
CREATE  ROLE  pgmv$_usage;
CREATE  ROLE  pgmv$_view;
CREATE  ROLE :PackageOwner  WITH  LOGIN PASSWORD :Password;

SELECT  TRIM(REPLACE(TRIM(REPLACE(REPLACE(CURRENT_SETTING('search_path'),CURRENT_SETTING('tab.PackageOwner'),''),' ','')),',,',','),',') AS "oldSearchPath" \gset

ALTER   DATABASE   :DataBase      SET   SEARCH_PATH=:oldSearchPath, :PackageOwner;

GRANT   pgmv$_view, pgmv$_usage   TO  :PackageOwner;
GRANT  :PackageOwner              TO  :SuperUser;

CREATE  SCHEMA     :PackageOwner  AUTHORIZATION :PackageOwner
    CREATE
    TABLE   pg$mview_logs
    (
        owner           TEXT    NOT NULL,
        pglog$_name     TEXT    NOT NULL,
        table_name      TEXT    NOT NULL,
        trigger_name    TEXT    NOT NULL,
        pg_mview_bitmap BIGINT  NOT NULL DEFAULT 0,
        CONSTRAINT
            pk_pg$mview_logs
            PRIMARY KEY
            (
                owner,
                table_name
            )
    )

    CREATE
    TABLE   pg$mviews
    (
        owner               TEXT        NOT NULL,
        view_name           TEXT        NOT NULL,
        pgmv_columns        TEXT        NOT NULL,
        select_columns      TEXT        NOT NULL,
        table_names         TEXT        NOT NULL,
        where_clause        TEXT,
        table_array         TEXT[],
        alias_array         TEXT[],
        rowid_array         TEXT[],
        log_array           TEXT[],
        bit_array           SMALLINT[],
        outer_table_array   TEXT[],
        inner_alias_array   TEXT[],
        inner_rowid_array   TEXT[],
        CONSTRAINT
            pk_pg$mviews
            PRIMARY KEY
            (
                owner,
                view_name
            )
    );

GRANT SELECT  ON  ALL TABLES  IN  SCHEMA :PackageOwner  TO  pgmv$_view;

GRANT USAGE   ON  SCHEMA :PackageOwner  TO  pgmv$_usage;

GRANT pgmv$_usage TO pgmv$_execute;

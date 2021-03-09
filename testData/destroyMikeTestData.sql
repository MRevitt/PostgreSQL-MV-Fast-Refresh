/* ---------------------------------------------------------------------------------------------------------------------------------
Routine Name: destroyMikeTestData.sql
Author:       Mike Revitt
Date:         08/04/2018
------------------------------------------------------------------------------------------------------------------------------------
Revision History    Push Down List
------------------------------------------------------------------------------------------------------------------------------------
Date        | Name          | Description
------------+---------------+-------------------------------------------------------------------------------------------------------
            |               |
23/02/2021  | M Revitt      | Parameterise
08/04/2018  | M Revitt      | Initial version
------------+---------------+-------------------------------------------------------------------------------------------------------
Background:     PostGre does not support Materialized View Fast Refreshes, this suite of scripts is a PL/SQL coded mechanism to
                provide that functionality, the next phase of this projecdt is to fold these changes into the PostGre kernel.

Description:    Remove Mike Test Data objects

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

-- psql -h localhost -p 5432 -d postgres -U mike_data -q -f destroyMikeTestData.sql -v DataOwner=mike_data -v SuperUser=mike -v DataBase=postgres

SET CLIENT_MIN_MESSAGES = ERROR;

DROP        TRIGGER IF  EXISTS  trig$_t1  ON  :DataOwner.t1;
DROP        TRIGGER IF  EXISTS  trig$_t2  ON  :DataOwner.t2;
DROP        TRIGGER IF  EXISTS  trig$_t3  ON  :DataOwner.t3;
DROP        TRIGGER IF  EXISTS  trig$_t4  ON  :DataOwner.t4;
DROP        TRIGGER IF  EXISTS  trig$_t5  ON  :DataOwner.t5;

DROP        TABLE   IF  EXISTS  :DataOwner.mv1;
DROP        TABLE   IF  EXISTS  :DataOwner.mv2;
DROP        TABLE   IF  EXISTS  :DataOwner.mv3;
DROP        TABLE   IF  EXISTS  :DataOwner.mv4;
DROP        TABLE   IF  EXISTS  :DataOwner.mv5;
DROP        TABLE   IF  EXISTS  :DataOwner.pgmv$_mv1  CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.pgmv$_mv2  CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.pgmv$_mv3  CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.pgmv$_mv4  CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.pgmv$_mv5  CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.log$_t1    CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.log$_t2    CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.log$_t3    CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.log$_t4    CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.log$_t5    CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.t1         CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.t2         CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.t3         CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.t4         CASCADE;
DROP        TABLE   IF  EXISTS  :DataOwner.t5         CASCADE;

\c :DataBase :SuperUser

SET CLIENT_MIN_MESSAGES = ERROR;
SET tab.DataOwner       = :DataOwner;

DROP  SCHEMA  IF  EXISTS  :DataOwner  CASCADE;

DO $$ BEGIN
IF EXISTS(SELECT rolname FROM pg_roles WHERE rolname = current_setting('tab.DataOwner'))
THEN
  EXECUTE 'DROP OWNED BY ' || current_setting('tab.DataOwner');
END IF;
END $$;

DROP  ROLE  IF  EXISTS  :DataOwner;

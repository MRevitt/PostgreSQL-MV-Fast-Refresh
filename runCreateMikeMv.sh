#! /bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Routine Name: runCreateMikeMv.sh
# Author:       Mike Revitt
# Date:         30/10/2019
#-----------------------------------------------------------------------------------------------------------------------------------
# Revision History    Push Down List
# ----------------------------------------------------------------------------------------------------------------------------------
# Date       | Name          | Description
# -----------+---------------+------------------------------------------------------------------------------------------------------
# 21/05/2020 | M Revitt      | Parameterise
# 30/10/2019 | M Revitt      | Initial version
#------------+---------------+------------------------------------------------------------------------------------------------------
# Description:  This is the calling engine for the SCT Windows Host creation, it calls the other routines in order
#               This host has also been setup to run SCT in batch mode and has Oracle Instant Client installed
#
# Issues:       None
#
OPTIONS="h:p:d:U:P:D:V:f:e:l:r:c:H"

pgTestDataHome='testData'
pgTestHarnessHome='testHarness'
pgMvHome='buildScripts'
pgMvGrants='mvGrants'

pgDatabase='postgres'
pgDataOwner='mike_data'
pgHostName='localhost'
pgPackageOwner='mike_pgmview'
pgPort='5432'
pgSuperUser='mike'
pgViewOwner='mike_view'
pgPassword='aws-oracle'

pgFullRebuild=Y
pgRunLoadTest=Y
pgTestHarness=Y
pgRunLoadTest=Y
pgNoChildTables=1
pgRowsToInsert=50000 # Created at the rate of ~ 100 child and grand child records per parent record, 50,000 will create 5,000,000 records
pgRemoveViews=Y

usage()
{
    echo -e "\nUsage: runCreateMikeMv -h [hostname] -p [port] -d [DB name] -U [DB user]"
    echo -e "                       -P [Package Owner] -D [Data Owner]      -V [View Owner]"
    echo -e "                       -f [Full Rebuild]  -e [execute Harness] -l [Load Test] -r [Rows to Create] -c [Cleanup]\n"
    echo -e "\t-h [hostname]\t\t[$pgHostName]\tThe RDS database host identifier, this forms the DNS name"
    echo -e "\t-p [port]\t\t[$pgPort]\t\tThe RDS database port"
    echo -e "\t-d [DB name]\t\t[$pgDatabase]\tThe database name"
    echo -e "\t-U [DB user]\t\t[$pgSuperUser]\t\tThe database admin account username"
    echo -e "\t-P [Package Owner]\t[$pgPackageOwner]\tThe PostGre Materialized View Package Owner"
    echo -e "\t-D [Data Owner]\t\t[$pgDataOwner]\tThe Owner of the PostGre Source Database Tables"
    echo -e "\t-V [View Owner]\t\t[$pgViewOwner]\tThe Owner of the PostGre Materialized Views"
    echo -e "\t-f [Full Rebuild]]\t[$pgFullRebuild]\t\tDo you want to perform a Full Test Data environment rebuild [Y|N]"
    echo -e "\t-e [Execute Harness]\t[$pgTestHarness]\t\tDo you want to execute the Matarialized View Test Harness [Y|N] "
    echo -e "\t-l [Load Test]\t\t[$pgRunLoadTest]\t\tDo you want to perform a Load Test [Y|N]"
    echo -e "\t-r [Rows to Create]\t[$pgRowsToInsert]\t\tNo of Parent rows to create for load Test. 50,000 will create ~ 4,000,000 rows"
    echo -e "\t-c [Cleanup]\t\t[$pgRemoveViews]\t\tDo you want to remove the Materialized Views [Y|N]"
    echo -e "\n"
    exit
}

while getopts $OPTIONS option
do
    case "$option" in
    h)  pgHostName=${OPTARG}
        ;;
    p)  pgPort=${OPTARG}
        ;;
    d)  pgDatabase=${OPTARG}
        ;;
    U)  pgSuperUser=${OPTARG}
        ;;
    P)  pgPackageOwner=${OPTARG}
        ;;
    D)  pgDataOwner=${OPTARG}
        ;;
    V)  pgViewOwner=${OPTARG}
        ;;
    f)  pgFullRebuild=$(echo $OPTARG | tr '[a-z]' '[A-Z]')
        ;;
    e)  pgTestHarness=$(echo $OPTARG | tr '[a-z]' '[A-Z]')
        ;;
    l)  pgRunLoadTest=$(echo $OPTARG | tr '[a-z]' '[A-Z]')
        ;;
    r)  pgRowsToInsert=${OPTARG}
        ;;
    c)  pgRemoveViews=$(echo $OPTARG | tr '[a-z]' '[A-Z]')
        ;;
    H)  usage
        ;;
    ?)  usage
        ;;
    esac
done

date

if [ $pgFullRebuild == 'Y' ]
then
    echo  'Building Materailized View Environment'
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgMvHome/destroyMikeSnapshotDD.sql" -v PackageOwner=$pgPackageOwner -v SuperUser=$pgSuperUser -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgMvHome/createMikeSnapshotDD.sql"  -v PackageOwner=$pgPackageOwner -v SuperUser=$pgSuperUser -v Password="'"$pgPassword"'" -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvTypes.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvConstants.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvSimpleFunctions.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvComplexFunctions.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvApplicationFunctions.sql"
fi

if [ $pgTestHarness == 'Y' ]
then
    echo  'Running Simple Functionality Tests'
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser -q -f "$pgTestDataHome/destroyMikeTestData.sql"       -v DataOwner=$pgDataOwner -v SuperUser=$pgSuperUser -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser -q -f "$pgTestDataHome/createMikeTestDataObjects.sql" -v DataOwner=$pgDataOwner -v SuperUser=$pgSuperUser -v Password="'"$pgPassword"'" -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser    -f "$pgMvGrants/grantMvExecuteToUser.sql"          -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgDataOwner -q -f "$pgTestHarnessHome/testHarnessData.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgDataOwner -q -f "$pgTestHarnessHome/testHarness.sql"            -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase
fi

if [ $pgRunLoadTest == 'Y' ]
then
    echo  'Running Bulk Data Load Tests'
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgMvHome/destroyMikeSnapshotDD.sql"           -v PackageOwner=$pgPackageOwner -v SuperUser=$pgSuperUser -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgMvHome/createMikeSnapshotDD.sql"            -v PackageOwner=$pgPackageOwner -v SuperUser=$pgSuperUser -v Password="'"$pgPassword"'" -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvTypes.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvConstants.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvSimpleFunctions.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvComplexFunctions.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgPackageOwner  -q -f "$pgMvHome/mvApplicationFunctions.sql"
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgTestDataHome/destroyMikeTestData.sql"       -v DataOwner=$pgDataOwner -v SuperUser=$pgSuperUser -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgTestDataHome/createMikeTestDataObjects.sql" -v DataOwner=$pgDataOwner -v SuperUser=$pgSuperUser -v Password="'"$pgPassword"'" -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser        -f "$pgMvGrants/grantMvExecuteToUser.sql"          -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgSuperUser     -q -f "$pgTestDataHome/generateTestDataPackages.sql"  -v DataOwner=$pgDataOwner
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgDataOwner     -q -f "$pgTestDataHome/generateBulkTestData.sql"      -v DataOwner=$pgDataOwner -v iNoOfChildTables=$pgNoChildTables -v iRowsToInsert=$pgRowsToInsert -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgDataOwner     -q -f "$pgTestHarnessHome/loadTest.sql"               -v DataOwner=$pgDataOwner -v PackageOwner=$pgPackageOwner -v DataBase=$pgDatabase
fi

if [ $pgRemoveViews == 'Y' ]
then
    echo  'Testing Material View Removal'
    psql -h $pgHostName -p $pgPort -d $pgDatabase -U $pgDataOwner -q -f "$pgTestHarnessHome/removeMaterializedViews.sql"
fi

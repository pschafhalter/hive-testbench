#!/bin/bash

set -x
set -e

(cd tpcds-gen; make)

# Tables in the TPC-DS schema.
LIST="date_dim time_dim item customer customer_demographics household_demographics customer_address store promotion warehouse ship_mode reason income_band call_center web_page catalog_page inventory store_sales store_returns web_sales web_returns web_site catalog_sales catalog_returns"

SCALE=$1
DIR=$2
BUCKETS=13
RETURN_BUCKETS=1
SPLIT=16
STORE_CLAUSES=( "orc" )
FILE_FORMATS=( "orc" )
SERDES=( "org.apache.hadoop.hive.ql.io.orc.OrcSerde" )

hadoop dfs -ls ${DIR}/${SCALE} || (cd tpcds-gen; hadoop jar target/*.jar -d ${DIR}/${SCALE}/ -s ${SCALE})
hadoop dfs -ls ${DIR}/${SCALE}

# Generate the text/flat tables. These will be later be converted to ORCFile.
if true; then
for t in ${LIST}
do
    hive -i settings/load.sql -f ddl/text/${t}.sql -d DB=tpcds_text_${SCALE} -d LOCATION=${DIR}/${SCALE}/${t}
done
fi

# Generate the partitioned schema in ORCFile format.
i=0
for file in "${STORE_CLAUSES[@]}"
do
    for t in ${LIST}
    do
	hive -i settings/load.sql -f ddl/bin_partitioned/${t}.sql -d DB=tpcds_bin_partitioned_${FILE_FORMATS[$i]}_${SCALE} -d SOURCE=tpcds_text_${SCALE} -d BUCKETS=${BUCKETS} -d RETURN_BUCKETS=${RETURN_BUCKETS} -d FILE="${file}" -d SERDE=${SERDES[$i]} -d SPLIT=${SPLIT}
    done

    i=$((i+1))
done
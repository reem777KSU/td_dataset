#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

import_table_file() {
    local -r table_file=$1
    local -r basename=$(basename $table_file)
    local -r no_csv=${basename%.csv}
    local -r table_name=${no_csv%-*}
    local -r headerless_file=$WORKSPACE_DIR/$no_csv-NO_HEADER.csv

    tail -n +2 $table_file > $headerless_file

    echo -e ".mode csv\n.import $headerless_file $table_name" | sqlite3 $DATABASE_PATH
}

for table_file in $THIS_SCRIPT_DIR/generated_tables/*.csv
do
    import_table_file $table_file
done

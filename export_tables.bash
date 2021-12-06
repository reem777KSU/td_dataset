#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

export_author_experience() {
    local -ri count_total=$(run_query 'SELECT COUNT(*) FROM AUTHOR_EXPERIENCE;')
    local -ri parts=5
    let       count_per_file=(count_total/parts)+1
    for part in $(seq 1 $parts)
    do
        let offset=(part-1)*count_per_file || true
        sqlite3 -header -csv $DATABASE_PATH  "
              SELECT *
                FROM AUTHOR_EXPERIENCE
            ORDER BY ISSUE_KEY, IS_FIX
               LIMIT $count_per_file
              OFFSET $offset;
        " > $THIS_SCRIPT_DIR/generated_tables/AUTHOR_EXPERIENCE-${part}_of_${parts}.csv
    done
}

export_author_experience

for table in PROJECT_COMMIT_STATS PROJECT_COMMIT_RULE_VIOLATIONS
do
    sqlite3 -header -csv $DATABASE_PATH "
          SELECT *
            FROM $table
        ORDER BY PROJECT_ID, COMMIT_HASH;
    " > $THIS_SCRIPT_DIR/generated_tables/${table}.csv
done

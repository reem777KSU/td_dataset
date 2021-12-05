#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

declare -r  LOCK_FILE=$WORKSPACE_DIR/LOCK.txt
declare -ra COMMIT_TABLES=(PROJECT_COMMIT_STATS PROJECT_COMMIT_RULE_VIOLATIONS AUTHOR_EXPERIENCE)

for table in "${COMMIT_TABLES[@]}"
do
    for column in NUM_PROJECT_FILES NUM_PROJECT_LINES NUM_PROJECT_SOURCE_FILES NUM_PROJECT_SOURCE_LINES
    do
        run_query "
            ALTER TABLE $table
            ADD COLUMN $column INTEGER DEFAULT 0 NOT NULL;
        " || true
    done
done

update_project_commit_stats() {
    local -r project_id=$1
    local -r commit_hash=$2
    local -r EMPTY_TREE_HASH='4b825dc642cb6eb9a060e54bf8d69288fbee4904'

    cd $PROJECTS_DIR/$project_id

    read num_project_files        num_project_lines        <<< $(git diff --shortstat $EMPTY_TREE_HASH $commit_hash             | cut -d' ' -f2,5)
    read num_project_source_files num_project_source_lines <<< $(git diff --shortstat $EMPTY_TREE_HASH $commit_hash -- '*.java' | cut -d' ' -f2,5)

    if [ -z "$num_project_files" ]
    then
        log "BAD OBJECT: project_id=\"$project_id\", commit_hash=\"$commit_hash\""
        return
    fi

    local -ri lock_fd=222
    for table in "${COMMIT_TABLES[@]}"
    do
        (flock $lock_fd
        {
            run_query "
                UPDATE $table
                   SET NUM_PROJECT_FILES        = $num_project_files,
                       NUM_PROJECT_LINES        = $num_project_lines,
                       NUM_PROJECT_SOURCE_FILES = $num_project_source_files,
                       NUM_PROJECT_SOURCE_LINES = $num_project_source_lines
                 WHERE PROJECT_ID  = \"$project_id\"  AND
                       COMMIT_HASH = \"$commit_hash\";
            "
        }) 222>$LOCK_FILE
    done
}

while read project_id commit_hash
do
    update_project_commit_stats "$project_id" "$commit_hash" &
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
done <<< $(run_query "
      SELECT PROJECT_ID, COMMIT_HASH
        FROM PROJECT_COMMIT_STATS
       WHERE NUM_PROJECT_FILES = 0 OR
             NUM_PROJECT_LINES = 0;
" )

wait
log "DONE"

for table in "${COMMIT_TABLES[@]}"
do
    cd $PROJECTS_DIR
    for project_id in *
    do
        read num_project_files num_project_lines num_project_source_files num_project_source_lines <<< $(
            run_query "
                SELECT FILES, LINES, SOURCE_FILES, SOURCE_FILE_LINES
                  FROM PROJECT_STATS
                 WHERE PROJECT_ID = \"$project_id\";
            "
        )
    
        run_query "
            UPDATE $table
               SET NUM_PROJECT_FILES        = $num_project_files,
                   NUM_PROJECT_LINES        = $num_project_lines,
                   NUM_PROJECT_SOURCE_FILES = $num_project_source_files,
                   NUM_PROJECT_SOURCE_LINES = $num_project_source_lines
             WHERE NUM_PROJECT_FILES = 0
               AND PROJECT_ID        = \"$project_id\";
        "
    done
done

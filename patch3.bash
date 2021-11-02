#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

declare -r PROJECT_COMMITS_QUEUE_FILE=$WORKSPACE_DIR/PROJECT_COMMITS_QUEUE.csv
declare -r PROJECT_COMMITS_LOCK_FILE=$WORKSPACE_DIR/PROJECT_COMMITS_LOCK.txt

for kind in '' '_SOURCE'
do
    for item in FILES DIRECTORIES
    do
        run_query "
            ALTER TABLE PROJECT_COMMIT_RULE_VIOLATIONS
             ADD COLUMN NUM${kind}_${item} INTEGER DEFAULT 0 NOT NULL;
        " || true
    done
done

get_commit_delta() {
    local -r project_id=$1
    local -r commit_hash=$2
    local -ra source_files_pattern=("${@:2}")
    local -r empty_tree_commit_hash='4b825dc642cb6eb9a060e54bf8d69288fbee4904'
    local -r previous_commit_hash="$commit_hash~"
    cd $PROJECTS_DIR/$project_id
    local -ra files=(
        $(git diff --name-only $previous_commit_hash   $commit_hash 2>/dev/null "${source_files_pattern[@]}" ||
          git diff --name-only $empty_tree_commit_hash $commit_hash             "${source_files_pattern[@]}")
    )
    local -ri num_directories=$(dirname "${files[@]}" | sort -u | wc -l)

    echo ${#files[@]} $num_directories
}

mine_project_commit() {
    local -r project_id=$1
    local -r commit_hash=$2

    read num_files        num_directories        <<< $(get_commit_delta "$project_id" "$commit_hash")
    read num_source_files num_source_directories <<< $(get_commit_delta "$project_id" "$commit_hash" -- '*.java')

    local -ri lock_fd=222
    (flock $lock_fd
    {
        run_query "
            UPDATE PROJECT_COMMIT_RULE_VIOLATIONS
               SET NUM_FILES              = $num_files,
                   NUM_DIRECTORIES        = $num_directories,
                   NUM_SOURCE_FILES       = $num_source_files,
                   NUM_SOURCE_DIRECTORIES = $num_source_directories
             WHERE PROJECT_ID  = \"$project_id\"  AND
                   COMMIT_HASH = \"$commit_hash\";
        "
    }) 222>$PROJECT_COMMITS_LOCK_FILE
}

run_query '
    SELECT PROJECT_ID, COMMIT_HASH
      FROM PROJECT_COMMIT_RULE_VIOLATIONS;
' > $PROJECT_COMMITS_QUEUE_FILE
declare -ri NUM_LINES=$(wc -l < $PROJECT_COMMITS_QUEUE_FILE)
declare -i  LINE=0
while read project_id commit_hash
do
    ((++LINE))
    mine_project_commit "$project_id" "$commit_hash" &
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    log "DONE processing \"$project_id\",\"$commit_hash\" ($LINE/$NUM_LINES)"
done < $PROJECT_COMMITS_QUEUE_FILE
wait
log "DONE"

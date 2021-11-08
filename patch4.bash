#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

declare -r  PROJECT_COMMITS_QUEUE_FILE=$WORKSPACE_DIR/PROJECT_COMMITS_QUEUE.csv
declare -r  PROJECT_COMMITS_LOCK_FILE=$WORKSPACE_DIR/PROJECT_COMMITS_LOCK.txt
declare -ri RECENT_DAY_DIFF=30

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

commit_history() {
    git rev-list --count "$@" 2>/dev/null || echo 0
}

detailed_commit_history() {
    local -ri total_commits=$(commit_history "$@")
    local -i  total_line_additions=0
    local -i  total_line_subtractions=0
    if  [ $total_commits  -ne 0 ]
    then
        while read line_additions line_subtractions _file
        do
            # line changes aren't counted for binary source_files
            if [ $line_additions = '-' ]
            then
                line_additions=0
            fi
            if [ $line_subtractions = '-' ]
            then
                line_subtractions=0
            fi
            ((total_line_additions+=line_additions)) || true
            ((total_line_subtractions+=line_subtractions)) || true
        done <<< $(git log --pretty=tformat: --numstat "$@")
    fi
    let total_line_changes=(total_line_additions+total_line_subtractions) || true

    echo $total_commits $total_line_additions $total_line_subtractions $total_line_changes
}

escape_regex() {
    local -r string=$1

    echo $string | sed -e 's/[]\/$*.^[]/\\&/g'
}

mine_project_commit() {
    local -r project_id=$1
    local -r commit_hash=$2
    local -r author="$3"
    local -r commit_date="$4"
    log "project_id=$project_id"
    log "commit_hash=$commit_hash"
    log "author=$author"
    log "commit_date=$commit_date"

    cd $PROJECTS_DIR/$project_id

    # local -r  regex_escaped_author="^$(escape_regex "$author") <"
    # local -r  source_file_pattern="*.java"
    local -r  previous_revision="$commit_hash~"
    # local -r  since_date="$(date -d "$(date -d  "$commit_date")-$RECENT_DAY_DIFF days")"

    # read num_files        num_directories        <<< $(get_commit_delta "$project_id" "$commit_hash")
    # read num_source_files num_source_directories <<< $(get_commit_delta "$project_id" "$commit_hash" -- '*.java')

    read num_commits           \
         num_line_additions    \
         num_line_subtractions \
         num_line_changes      <<< $(detailed_commit_history "$previous_revision".."$commit_hash")
    if [ $num_commits -eq 0 ]
    then
        read num_commits           \
             num_line_additions    \
             num_line_subtractions \
             num_line_changes      <<< $(detailed_commit_history "$commit_hash")
    fi
    #read num_source_commits           \
    #     num_source_line_additions    \
    #     num_source_line_subtractions \
    #     num_source_line_changes      <<< $(detailed_commit_history "$previous_revision".."$commit_hash" -- "$source_file_pattern")
    #if [ $num_source_commits -eq 0 ]
    #then
    #    read num_commits                  \
    #         num_source_line_additions    \
    #         num_source_line_subtractions \
    #         num_source_line_changes      <<< $(detailed_commit_history "$commit_hash" -- "$source_file_pattern")
    #fi
    #read total_source_file_commits                  \
    #     total_source_file_line_additions           \
    #     total_source_file_line_subtractions        \
    #     total_source_file_line_changes             <<< $(detailed_commit_history "$previous_revision" -- "$source_file_pattern")
    #read total_project_commits                      \
    #     total_project_line_additions               \
    #     total_project_line_subtractions            \
    #     total_project_line_changes                 <<< $(detailed_commit_history "$previous_revision")
    #read total_recent_source_file_commits           \
    #     total_recent_source_file_line_additions    \
    #     total_recent_source_file_line_subtractions \
    #     total_recent_source_file_line_changes      <<< $(detailed_commit_history "$previous_revision" --since="$since_date" -- "$source_file_pattern")
    #read total_recent_project_commits               \
    #     total_recent_project_line_additions        \
    #     total_recent_project_line_subtractions     \
    #     total_recent_project_line_changes          <<< $(detailed_commit_history "$previous_revision" --since="$since_date")
    #read author_source_file_commits                  \
    #     author_source_file_line_additions           \
    #     author_source_file_line_subtractions        \
    #     author_source_file_line_changes             <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" -- "$source_file_pattern")
    #read author_project_commits                      \
    #     author_project_line_additions               \
    #     author_project_line_subtractions            \
    #     author_project_line_changes                 <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision")
    #read author_recent_source_file_commits           \
    #     author_recent_source_file_line_additions    \
    #     author_recent_source_file_line_subtractions \
    #     author_recent_source_file_line_changes      <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date" -- "$source_file_pattern")
    #read author_recent_project_commits               \
    #     author_recent_project_line_additions        \
    #     author_recent_project_line_subtractions     \
    #     author_recent_project_line_changes          <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date")

    local -ri lock_fd=222
    (flock $lock_fd
    {
        run_query "
            UPDATE PROJECT_COMMIT_RULE_VIOLATIONS
               SET NUM_LINE_ADDITIONS                         = $num_line_additions,
                   NUM_LINE_SUBTRACTIONS                      = $num_line_subtractions,
                   NUM_LINE_CHANGES                           = $num_line_changes

             WHERE PROJECT_ID  = \"$project_id\"  AND
                   COMMIT_HASH = \"$commit_hash\";
        "
    }) 222>$PROJECT_COMMITS_LOCK_FILE
}

run_query '
    SELECT PROJECT_ID, COMMIT_HASH, AUTHOR, COMMIT_DATE
      FROM PROJECT_COMMIT_RULE_VIOLATIONS;
' '|' > $PROJECT_COMMITS_QUEUE_FILE
declare -ri NUM_LINES=$(wc -l < $PROJECT_COMMITS_QUEUE_FILE)
declare -i  LINE=0
while IFS='|' read project_id commit_hash author commit_date
do
    ((++LINE))
    mine_project_commit "$project_id" "$commit_hash" "$author" "$commit_date" &
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    log "DONE processing \"$project_id\",\"$commit_hash\" ($LINE/$NUM_LINES)"
done < $PROJECT_COMMITS_QUEUE_FILE
wait
log "DONE"

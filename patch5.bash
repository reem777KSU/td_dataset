#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

declare -r  GIT_COMMITS_QUEUE_FILE=$WORKSPACE_DIR/GIT_COMMITS_QUEUE.csv
declare -r  PROJECT_COMMITS_LOCK_FILE=$WORKSPACE_DIR/PROJECT_COMMITS_LOCK.txt
declare -ri RECENT_DAY_DIFF=30

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
    local -i num_directories=0
    if [ ${#files[@]} -ne 0 ]
    then
        num_directories=$(dirname "${files[@]}" | sort -u | wc -l)
    fi  
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
            if [ "$line_additions" = '-' ]
            then
                line_additions=0
            fi
            if [ "$line_subtractions" = '-' ]
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

get_first_commit_date() {
    local -r regex_escaped_author="$1"

    git log --reverse --author="$regex_escaped_author" --date=format:'%Y-%m-%d %H:%M:%S' |
    sed '3!d ; s/^Date: \+//'
}

hours_since_last_touch() {
    local -r commit="$1"
    local -r source_file_pattern="$2"
    local -r author="$3"

    local -r last_commit="$(git rev-list -n 1 --author="$author" "$commit~" -- "$source_file_pattern")"
    if [ -z "$last_commit" ]
    then
        echo NULL
        return
    fi
    local -r ts_commit="$(     git log -n 1 --format=%ct "$commit")"
    local -r ts_last_commit="$(git log -n 1 --format=%ct "$last_commit" 2>/dev/null)"
    if [ -z "$ts_last_commit" ]
    then
        echo NULL
        return
    fi
    let delta_hours=($ts_commit - $ts_last_commit)/3600 || true
    echo $delta_hours
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

    local -r  regex_escaped_author="^$(escape_regex "$author") <"
    local -r  source_file_pattern="*.java"
    local -r  previous_revision="$commit_hash~"
    local -r  since_date="$(date -d "$(date -d  "$commit_date")-$RECENT_DAY_DIFF days")"
    local -r  first_commit_date=$(       get_first_commit_date ".*")
    local -r  author_first_commit_date=$(get_first_commit_date "$regex_escaped_author")

    read num_files        num_directories        <<< $(get_commit_delta "$project_id" "$commit_hash")
    read num_source_files num_source_directories <<< $(get_commit_delta "$project_id" "$commit_hash" -- '*.java')

    local -r  total_hours_since_last_touch=$(hours_since_last_touch "$commit_hash" "$source_file_pattern" ".*")
    let       total_hours_since_first_project_commit=($(date -d "$commit_date" +%s)-$(date -d "$first_commit_date" +%s ))/3600 || true

    local -r  author_hours_since_last_touch=$(hours_since_last_touch "$commit_hash" "$source_file_pattern" "$regex_escaped_author")
    let       author_hours_since_first_project_commit=($(date -d "$commit_date" +%s)-$(date -d "$author_first_commit_date" +%s ))/3600 || true

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
    read num_source_commits           \
         num_source_line_additions    \
         num_source_line_subtractions \
         num_source_line_changes      <<< $(detailed_commit_history "$previous_revision".."$commit_hash" -- "$source_file_pattern")
    if [ $num_source_commits -eq 0 ]
    then
        read num_commits                  \
             num_source_line_additions    \
             num_source_line_subtractions \
             num_source_line_changes      <<< $(detailed_commit_history "$commit_hash" -- "$source_file_pattern")
    fi
    read total_source_file_commits                  \
         total_source_file_line_additions           \
         total_source_file_line_subtractions        \
         total_source_file_line_changes             <<< $(detailed_commit_history "$previous_revision" -- "$source_file_pattern")
    read total_project_commits                      \
         total_project_line_additions               \
         total_project_line_subtractions            \
         total_project_line_changes                 <<< $(detailed_commit_history "$previous_revision")
    read total_recent_source_file_commits           \
         total_recent_source_file_line_additions    \
         total_recent_source_file_line_subtractions \
         total_recent_source_file_line_changes      <<< $(detailed_commit_history "$previous_revision" --since="$since_date" -- "$source_file_pattern")
    read total_recent_project_commits               \
         total_recent_project_line_additions        \
         total_recent_project_line_subtractions     \
         total_recent_project_line_changes          <<< $(detailed_commit_history "$previous_revision" --since="$since_date")
    read author_source_file_commits                  \
         author_source_file_line_additions           \
         author_source_file_line_subtractions        \
         author_source_file_line_changes             <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" -- "$source_file_pattern")
    read author_project_commits                      \
         author_project_line_additions               \
         author_project_line_subtractions            \
         author_project_line_changes                 <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision")
    read author_recent_source_file_commits           \
         author_recent_source_file_line_additions    \
         author_recent_source_file_line_subtractions \
         author_recent_source_file_line_changes      <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date" -- "$source_file_pattern")
    read author_recent_project_commits               \
         author_recent_project_line_additions        \
         author_recent_project_line_subtractions     \
         author_recent_project_line_changes          <<< $(detailed_commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date")

    local -ri lock_fd=222
    (flock $lock_fd
    {
        run_query "
            INSERT INTO PROJECT_COMMIT_RULE_VIOLATIONS
                  (PROJECT_ID,
                   COMMIT_HASH,
                   COMMIT_DATE,
                   AUTHOR,
                   NUM_FILES,
                   NUM_DIRECTORIES,
                   NUM_LINE_ADDITIONS,
                   NUM_LINE_SUBTRACTIONS,
                   NUM_LINE_CHANGES,
                   NUM_SOURCE_FILES,
                   NUM_SOURCE_DIRECTORIES,
                   NUM_SOURCE_LINE_ADDITIONS,
                   NUM_SOURCE_LINE_SUBTRACTIONS,
                   NUM_SOURCE_LINE_CHANGES,

                   TOTAL_HOURS_SINCE_LAST_TOUCH,
                   TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   TOTAL_SOURCE_FILE_COMMITS,
                   TOTAL_SOURCE_FILE_LINE_ADDITIONS,
                   TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS,
                   TOTAL_SOURCE_FILE_LINE_CHANGES,
                   TOTAL_PROJECT_COMMITS,
                   TOTAL_PROJECT_LINE_ADDITIONS,
                   TOTAL_PROJECT_LINE_SUBTRACTIONS,
                   TOTAL_PROJECT_LINE_CHANGES,
                   TOTAL_RECENT_SOURCE_FILE_COMMITS,
                   TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES,
                   TOTAL_RECENT_PROJECT_COMMITS,
                   TOTAL_RECENT_PROJECT_LINE_ADDITIONS,
                   TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   TOTAL_RECENT_PROJECT_LINE_CHANGES,

                   AUTHOR_HOURS_SINCE_LAST_TOUCH,
                   AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   AUTHOR_SOURCE_FILE_COMMITS,
                   AUTHOR_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_SOURCE_FILE_LINE_CHANGES,
                   AUTHOR_PROJECT_COMMITS,
                   AUTHOR_PROJECT_LINE_ADDITIONS,
                   AUTHOR_PROJECT_LINE_SUBTRACTIONS,
                   AUTHOR_PROJECT_LINE_CHANGES,
                   AUTHOR_RECENT_SOURCE_FILE_COMMITS,
                   AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES,
                   AUTHOR_RECENT_PROJECT_COMMITS,
                   AUTHOR_RECENT_PROJECT_LINE_ADDITIONS,
                   AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   AUTHOR_RECENT_PROJECT_LINE_CHANGES)
            VALUES
                  (/* PROJECT_ID                                  = */ \"$project_id\",
                   /* COMMIT_HASH                                 = */ \"$commit_hash\",
                   /* COMMIT_DATE                                 = */ \"$commit_date\",
                   /* AUTHOR                                      = */ \"$author\",
                   /* NUM_FILES                                   = */ $num_files,
                   /* NUM_DIRECTORIES                             = */ $num_directories,
                   /* NUM_LINE_ADDITIONS                          = */ $num_line_additions,
                   /* NUM_LINE_SUBTRACTIONS                       = */ $num_line_subtractions,
                   /* NUM_LINE_CHANGES                            = */ $num_line_changes,
                   /* NUM_SOURCE_FILES                            = */ $num_source_files,
                   /* NUM_SOURCE_DIRECTORIES                      = */ $num_source_directories,
                   /* NUM_SOURCE_LINE_ADDITIONS                   = */ $num_source_line_additions,
                   /* NUM_SOURCE_LINE_SUBTRACTIONS                = */ $num_source_line_subtractions,
                   /* NUM_SOURCE_LINE_CHANGES                     = */ $num_source_line_changes,

                   /* TOTAL_HOURS_SINCE_LAST_TOUCH                = */ $total_hours_since_last_touch,
                   /* TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      = */ $total_hours_since_first_project_commit,

                   /* TOTAL_SOURCE_FILE_COMMITS                   = */ $total_source_file_commits,
                   /* TOTAL_SOURCE_FILE_LINE_ADDITIONS            = */ $total_source_file_line_additions,
                   /* TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         = */ $total_source_file_line_subtractions,
                   /* TOTAL_SOURCE_FILE_LINE_CHANGES              = */ $total_source_file_line_changes,
                   /* TOTAL_PROJECT_COMMITS                       = */ $total_project_commits,
                   /* TOTAL_PROJECT_LINE_ADDITIONS                = */ $total_project_line_additions,
                   /* TOTAL_PROJECT_LINE_SUBTRACTIONS             = */ $total_project_line_subtractions,
                   /* TOTAL_PROJECT_LINE_CHANGES                  = */ $total_project_line_changes,
                   /* TOTAL_RECENT_SOURCE_FILE_COMMITS            = */ $total_recent_source_file_commits,
                   /* TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     = */ $total_recent_source_file_line_additions,
                   /* TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  = */ $total_recent_source_file_line_subtractions,
                   /* TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       = */ $total_recent_source_file_line_changes,
                   /* TOTAL_RECENT_PROJECT_COMMITS                = */ $total_recent_project_commits,
                   /* TOTAL_RECENT_PROJECT_LINE_ADDITIONS         = */ $total_recent_project_line_additions,
                   /* TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS      = */ $total_recent_project_line_subtractions,
                   /* TOTAL_RECENT_PROJECT_LINE_CHANGES           = */ $total_recent_project_line_changes,

                   /* AUTHOR_HOURS_SINCE_LAST_TOUCH               = */ $author_hours_since_last_touch,
                   /* AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT     = */ $author_hours_since_first_project_commit,

                   /* AUTHOR_SOURCE_FILE_COMMITS                  = */ $author_source_file_commits,
                   /* AUTHOR_SOURCE_FILE_LINE_ADDITIONS           = */ $author_source_file_line_additions,
                   /* AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        = */ $author_source_file_line_subtractions,
                   /* AUTHOR_SOURCE_FILE_LINE_CHANGES             = */ $author_source_file_line_changes,
                   /* AUTHOR_PROJECT_COMMITS                      = */ $author_project_commits,
                   /* AUTHOR_PROJECT_LINE_ADDITIONS               = */ $author_project_line_additions,
                   /* AUTHOR_PROJECT_LINE_SUBTRACTIONS            = */ $author_project_line_subtractions,
                   /* AUTHOR_PROJECT_LINE_CHANGES                 = */ $author_project_line_changes,
                   /* AUTHOR_RECENT_SOURCE_FILE_COMMITS           = */ $author_recent_source_file_commits,
                   /* AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    = */ $author_recent_source_file_line_additions,
                   /* AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS = */ $author_recent_source_file_line_subtractions,
                   /* AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      = */ $author_recent_source_file_line_changes,
                   /* AUTHOR_RECENT_PROJECT_COMMITS               = */ $author_recent_project_commits,
                   /* AUTHOR_RECENT_PROJECT_LINE_ADDITIONS        = */ $author_recent_project_line_additions,
                   /* AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS     = */ $author_recent_project_line_subtractions,
                   /* AUTHOR_RECENT_PROJECT_LINE_CHANGES)         = */ $author_recent_project_line_changes);
        "
    }) 222>$PROJECT_COMMITS_LOCK_FILE
}

run_query 'DELETE FROM PROJECT_COMMIT_RULE_VIOLATIONS;'

run_query '
      SELECT PROJECT_ID, COMMIT_HASH, AUTHOR, AUTHOR_DATE
        FROM GIT_COMMITS
    ORDER BY PROJECT_ID, COMMIT_HASH, AUTHOR, AUTHOR_DATE;
' '|' > $GIT_COMMITS_QUEUE_FILE
declare -ri NUM_LINES=$(wc -l < $GIT_COMMITS_QUEUE_FILE)
declare -i  LINE=0
while IFS='|' read project_id commit_hash author commit_date
do
    ((++LINE))
    mine_project_commit "$project_id" "$commit_hash" "$author" "$commit_date" &
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    log "DONE processing \"$project_id\",\"$commit_hash\" ($LINE/$NUM_LINES)"
done < $GIT_COMMITS_QUEUE_FILE
wait
log "DONE"

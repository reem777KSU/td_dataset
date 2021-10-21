#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

# global variables
declare -r  PROJECTS_DIR=$WORKSPACE_DIR/projects
declare -r  AUTHOR_EXPERIENCE_QUEUE_SOURCE_FILE=$WORKSPACE_DIR/AUTHOR_EXPERIENCE_QUEUE.csv
declare -r  AUTHOR_EXPERIENCE_LOCK_SOURCE_FILE=$WORKSPACE_DIR/AUTHOR_EXPERIENCE_LOCK.txt
declare -ri RECENT_DAY_DIFF=30

update_author_project_commits() {
    local -r author=$1
    local -r project_id=$2
    local -r commits=$3
    local -r source_file_commits=$4
    local -r first_commit_date=$5

    run_query "
        INSERT OR IGNORE INTO AUTHOR_PROJECT_COMMITS
            (AUTHOR, PROJECT_ID, COMMITS, SOURCE_FILE_COMMITS, FIRST_COMMIT_DATE)
        VALUES
            (\"$author\", \"$project_id\", 0, 0, \"9999-99-99 99:99:99\");
    "
    run_query "
        UPDATE AUTHOR_PROJECT_COMMITS
           SET COMMITS             = COMMITS             + $commits,
               SOURCE_FILE_COMMITS = SOURCE_FILE_COMMITS + $source_file_commits,
               FIRST_COMMIT_DATE   = MIN(FIRST_COMMIT_DATE, \"$first_commit_date\")
         WHERE AUTHOR     = \"$author\"     AND
               PROJECT_ID = \"$project_id\";
    "
}

ensure_author_project_source_file_changes() {
    local -r author=$1
    local -r project_id=$2
    local -r source_file=$3

    run_query "
        INSERT OR IGNORE INTO AUTHOR_PROJECT_SOURCE_FILE_CHANGES
            (AUTHOR, PROJECT_ID, SOURCE_FILE)
        VALUES
            (\"$author\", \"$project_id\", \"$source_file\");
    "
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

update_project_stats() {
    local -r  project_id="$1"
    local -ra source_files_pattern=("${@:2}")

    local -ra file_list=($(git ls-files))
    log "got file_list"
    local -ri files=$(printf '%s\n' "${file_list[@]}" | wc -l)
    local -ri lines=$(cat "${file_list[@]}" 2>/dev/null | wc -l)
    log "lines=${lines}"
    local -ra source_file_list=($(git ls-files -- "${source_files_pattern[@]}"))
    local -ri source_files=$(printf '%s\n' "${file_list[@]}" | wc -l)
    log "got source_file_list"
    local -ri source_file_lines=$(cat "${source_file_list[@]}" 2>/dev/null | wc -l)
    log "source_file_lines=${source_file_lines}"
    local -ri commits=$(git rev-list --count HEAD)
    log "commits=${commits}"
    local -ri source_file_commits=$(git rev-list --count HEAD -- "${source_files_pattern[@]}")
    log "source_file_commits=${source_file_commits}"
    run_query "
        INSERT INTO PROJECT_STATS
            (PROJECT_ID,      FILES,  SOURCE_FILES,  LINES,  SOURCE_FILE_LINES,  COMMITS,  SOURCE_FILE_COMMITS)
        VALUES
            (\"$project_id\", $files, $source_files, $lines, $source_file_lines, $commits, $source_file_commits);
    "
}

mine_project() {
    local -r project_id="$1"

    cd $PROJECTS_DIR/$project_id

    local -ra source_files_pattern=($(
        run_query "
            SELECT DISTINCT(REPLACE(COMPONENT, RTRIM(COMPONENT, REPLACE(COMPONENT, '.', '')), ''))
              FROM SONAR_ISSUES
             WHERE PROJECT_ID = '$project_id' AND
                   TYPE       = 'CODE_SMELL'  AND
                   (RULE =    'common-java' OR
                    RULE LIKE 'squid:%');
        " | sed "s/^/*./" 
    ))
    log "source_files_pattern=${source_files_pattern[@]}"

    mkdir -p $WORKSPACE_DIR/author_queues
    local -r author_queue_file=$WORKSPACE_DIR/author_queues/$project_id-AUTHOR_QUEUE.csv
    git shortlog --summary --numbered | sed 's/^\s*\([0-9]\+\)\s\+\(.*\)$/\1|\2/' > $author_queue_file
    while IFS=$'|\n' read -u 9 commits author
    do
        log "commits=$commits"
        log "author=$author"
        regex_escaped_author="^$(escape_regex "$author") <"
        source_file_commits="$(git shortlog --summary --numbered --author="$regex_escaped_author" -- "${source_files_pattern[@]}" | cut -f1)"
        if [ -z "$source_file_commits" ]
        then
            source_file_commits=0
        fi
        first_commit_date=$(get_first_commit_date "$regex_escaped_author")
        log "source_file_commits=$source_file_commits"
        update_author_project_commits "$author" "$project_id" "$commits" "$source_file_commits" "$first_commit_date"
        git log --author="$regex_escaped_author" --pretty=tformat: --numstat -- "${source_files_pattern[@]}" |
        while IFS=$' \t\n' read line_additions line_subtractions source_file
        do
            if echo $source_file | grep --quiet ' => '
            then
                # is source_file rename
                read old_source_file new_source_file <<< $(echo $source_file | perl -pe 's|(.*){(.*?) => (.*?)}(.*)|\1\2\4 \1\3\4|')
                for renamed_source_file in $old_source_file $new_source_file
                do
                    ensure_author_project_source_file_changes "$author" "$project_id" "$renamed_source_file"
                    run_query "
                        UPDATE AUTHOR_PROJECT_SOURCE_FILE_CHANGES
                           SET RENAMES       = RENAMES + 1,
                               TOTAL_CHANGES = TOTAL_CHANGES + 1
                         WHERE AUTHOR      = \"$author\"       AND
                               PROJECT_ID  = \"$project_id\"   AND
                               SOURCE_FILE = \"$renamed_source_file\";
                    "
                done
            else
                # is in-place change
                # line changes aren't counted for binary source_files, for example
                if [ -z $line_additions ] || [ $line_additions = '-' ]
                then
                    line_additions=0
                fi
                if [ -z $line_subtractions ] || [ $line_subtractions = '-' ]
                then
                    line_subtractions=0
                fi
                ensure_author_project_source_file_changes "$author" "$project_id" "$source_file"
                run_query "
                    UPDATE AUTHOR_PROJECT_SOURCE_FILE_CHANGES
                       SET LINE_ADDITIONS     = LINE_ADDITIONS     + $line_additions,
                           LINE_SUBTRACTIONS  = LINE_SUBTRACTIONS  + $line_subtractions,
                           TOTAL_LINE_CHANGES = TOTAL_LINE_CHANGES + $line_additions    + $line_subtractions,
                           TOTAL_CHANGES      = TOTAL_CHANGES      + 1
                     WHERE AUTHOR      = \"$author\"     AND
                           PROJECT_ID  = \"$project_id\" AND
                           SOURCE_FILE = \"$source_file\";
                "
            fi
        done
    done 9< $author_queue_file
}

# clone git projects
mkdir -p $PROJECTS_DIR
cd $PROJECTS_DIR

run_query 'SELECT project_id, git_link from PROJECTS;' | (
    while read project_id git_link
    do
        echo "project_id: $project_id, git_link: $git_link"
        if [ -d $project_id ]
        then
            log "already have project: '$project_id', skipping..."
        else
            log "cloning project '$project_id'"
            git clone --recursive $git_link $project_id &
        fi
    done

    # wait for clones to finish
    wait $(jobs -p)
)

cd $PROJECTS_DIR/org.apache:felix
git checkout archived
cd -

# Create the table 'COMMIT_TIME_DIFFS' from 'SONAR_ISSUES', 'SONAR_ANALYSIS',
# and 'GIT_COMMITS'.
run_query '
    INSERT OR IGNORE INTO COMMIT_TIME_DIFFS
        SELECT SONAR_ISSUES.ISSUE_KEY,
               SONAR_ISSUES.RULE,
               SONAR_ISSUES.CREATION_ANALYSIS_KEY,
               CASE WHEN SONAR_ISSUES.CLOSE_ANALYSIS_KEY = ""
                    THEN NULL
                    ELSE SONAR_ISSUES.CLOSE_ANALYSIS_KEY
                    END
               AS CLOSE_ANALYSIS_KEY,
               SONAR_ISSUES.CREATION_DATE,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE = ""
                    THEN NULL
                    ELSE SONAR_ISSUES.CLOSE_DATE
                    END
               AS CLOSE_DATE,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE = ""
                    THEN NULL
                    ELSE CAST((JULIANDAY(SONAR_ISSUES.CLOSE_DATE) - JULIANDAY(SONAR_ISSUES.CREATION_DATE)) AS INTEGER)
                    END
               AS DAY_DIFF,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE = ""
                    THEN NULL
                    ELSE CAST((JULIANDAY(SONAR_ISSUES.CLOSE_DATE) - JULIANDAY(SONAR_ISSUES.CREATION_DATE)) AS INTEGER) * 24
                    END
               AS HOURS_DIFF,
               CREATION_ANALYSIS.REVISION AS CREATION_COMMIT_HASH,
               CLOSE_ANALYSIS.REVISION    AS CLOSE_COMMIT_HASH,
               CREATION_COMMITS.AUTHOR    AS CREATION_AUTHOR,
               FIX_COMMITS.AUTHOR         AS FIX_AUTHOR,
               SONAR_ISSUES.PROJECT_ID,
               REPLACE(SONAR_ISSUES.COMPONENT, RTRIM(SONAR_ISSUES.COMPONENT, REPLACE(SONAR_ISSUES.COMPONENT, ":", "")), "") AS SOURCE_FILE
          FROM SONAR_ISSUES
    INNER JOIN SONAR_ANALYSIS CREATION_ANALYSIS
            ON SONAR_ISSUES.CREATION_ANALYSIS_KEY = CREATION_ANALYSIS.ANALYSIS_KEY
    INNER JOIN GIT_COMMITS    CREATION_COMMITS
            ON CREATION_ANALYSIS.REVISION = CREATION_COMMITS.COMMIT_HASH
     LEFT JOIN SONAR_ANALYSIS CLOSE_ANALYSIS
            ON (SONAR_ISSUES.CLOSE_ANALYSIS_KEY != "" AND
                SONAR_ISSUES.CLOSE_ANALYSIS_KEY  = CLOSE_ANALYSIS.ANALYSIS_KEY)
     LEFT JOIN GIT_COMMITS    FIX_COMMITS
            ON (FIX_COMMITS.AUTHOR      != "" AND
                CLOSE_ANALYSIS.REVISION =  FIX_COMMITS.COMMIT_HASH)
         WHERE SONAR_ISSUES.TYPE = "CODE_SMELL" AND
               (SONAR_ISSUES.RULE =    "common-java" OR
                SONAR_ISSUES.RULE LIKE "squid:%");
'

# build AUTHOR_PROJECT_COMMITS and AUTHOR_PROJECT_SOURCE_FILE_CHANGES
# FIXME: parallelize
cd $PROJECTS_DIR
for project_id in *
do
    mine_project "$project_id"
done

commit_history() {
    git rev-list --count "$@" 2>/dev/null || echo 0
}

detailed_commit_history() {
    local -ri total_commits=$(commit_history "$@")
    local -i  total_line_additions=0
    local -i  total_line_subtractions=0
    if  [ $total_commits  -ne 0 ]
    then
        git log --pretty=tformat: --numstat "$@" |
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
            ((total_line_additions+=line_additions))
            ((total_line_subtractions+=line_subtractions))
        done
    fi
    let total_line_changes=(total_line_additions+total_line_subtractions)

    echo $total_commits $total_line_additions $total_line_subtractions $total_line_changes
}

hours_since_last_touch() {
    local -r commit="$1"
    local -r source_file_pattern="$2"
    local -r author="$3"

    local -r last_commit="$(git rev-list -n 1 --author="$author" "$commit" -- "$source_file_pattern")"
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
    local -r delta=$(( $ts_commit - $ts_last_commit ));
    date -d @$delta +'%H'
}

insert_author_experience() {
    local -r  issue_key="$1"
    local -ri is_fix="$2"
    local -r  author="$3"
    local -r  project_id="$4"
    local -r  source_file="$5"
    local -r  commit_hash="$6"
    local -r  commit_date="$7"
    pushd $PROJECTS_DIR/$project_id

    local -r  regex_escaped_author="^$(escape_regex "$author") <"
    local -r  source_file_pattern="*${source_file#*/src}"
    local -r  previous_revision="$commit_hash~"
    local -r  since_date="$(date -d "$(date -d  "$commit_date")-$RECENT_DAY_DIFF days")"
    local -r  first_commit_date=$(       get_first_commit_date ".*")
    local -r  author_first_commit_date=$(get_first_commit_date "$regex_escaped_author")

    local -r  total_hours_since_last_touch=$(hours_since_last_touch "$commit_hash" "$source_file_pattern" ".*")
    let       total_hours_since_first_project_commit=($(date -d "$commit_date" +%s)-$(date -d "$first_commit_date" +%s ))/3600
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

    local -r  author_hours_since_last_touch=$(hours_since_last_touch "$commit_hash" "$source_file_pattern" "$regex_escaped_author")
    let       author_hours_since_first_project_commit=($(date -d "$commit_date" +%s)-$(date -d "$author_first_commit_date" +%s ))/3600
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
    log "    issue_key,is_fix=\"$issue_key\",$is_fix\n" \
        "        author=\"$author\"\n" \
        "        since_date=\"$since_date\"\n" \
        "        commit_hash=\"$commit_hash\"\n" \
        "        commit_date=\"$commit_date\"\n" \ \
        "        total_hours_since_last_touch=\"$total_hours_since_last_touch\"\n" \
        "        total_hours_since_first_project_commit=$total_hours_since_first_project_commit\n" \
        "        total_source_file_commits=\"$total_source_file_commits\"\n" \
        "        total_project_commits=\"$total_project_commits\"\n" \
        "        total_recent_source_file_commits=\"$total_recent_source_file_commits\"\n" \
        "        total_recent_project_commits=\"$total_recent_project_commits\"\n" \
        "        author_hours_since_last_touch=\"$author_hours_since_last_touch\"\n" \
        "        author_hours_since_first_project_commit=$author_hours_since_first_project_commit\n" \
        "        author_source_file_commits=\"$author_source_file_commits\"\n" \
        "        author_project_commits=\"$author_project_commits\"\n" \
        "        author_recent_source_file_commits=\"$author_recent_source_file_commits\"\n" \
        "        author_recent_project_commits=\"$author_recent_project_commits\"\n" \

    local -ri lock_fd=222
    (flock $lock_fd
    {
        run_query "
            INSERT INTO AUTHOR_EXPERIENCE
            VALUES
                (\"$issue_key\",
                 $is_fix,
                 \"$author\",
                 \"$project_id\",
                 \"$source_file\",
                 \"$commit_hash\",
                 \"$commit_date\",
                 $total_hours_since_last_touch,
                 $total_hours_since_first_project_commit,
                 $total_source_file_commits,
                 $total_source_file_line_additions,
                 $total_source_file_line_subtractions,
                 $total_source_file_line_changes,
                 $total_project_commits,
                 $total_project_line_additions,
                 $total_project_line_subtractions,
                 $total_project_line_changes,
                 $total_recent_source_file_commits,
                 $total_recent_source_file_line_additions,
                 $total_recent_source_file_line_subtractions,
                 $total_recent_source_file_line_changes,
                 $total_recent_project_commits,
                 $total_recent_project_line_additions,
                 $total_recent_project_line_subtractions,
                 $total_recent_project_line_changes,
                 $author_hours_since_last_touch,
                 $author_hours_since_first_project_commit,
                 $author_source_file_commits,
                 $author_source_file_line_additions,
                 $author_source_file_line_subtractions,
                 $author_source_file_line_changes,
                 $author_project_commits,
                 $author_project_line_additions,
                 $author_project_line_subtractions,
                 $author_project_line_changes,
                 $author_recent_source_file_commits,
                 $author_recent_source_file_line_additions,
                 $author_recent_source_file_line_subtractions,
                 $author_recent_source_file_line_changes,
                 $author_recent_project_commits,
                 $author_recent_project_line_additions,
                 $author_recent_project_line_subtractions,
                 $author_recent_project_line_changes);
        "
    }) 222>$AUTHOR_EXPERIENCE_LOCK_SOURCE_FILE

    popd
}

run_query '
       SELECT COMMIT_TIME_DIFFS.ISSUE_KEY,
              COMMIT_TIME_DIFFS.PROJECT_ID,
              COMMIT_TIME_DIFFS.CREATION_AUTHOR,
              COMMIT_TIME_DIFFS.FIX_AUTHOR,
              COMMIT_TIME_DIFFS.CREATION_COMMIT_HASH,
              COMMIT_TIME_DIFFS.CLOSE_COMMIT_HASH,
              COMMIT_TIME_DIFFS.SOURCE_FILE,
              COMMIT_TIME_DIFFS.CREATION_DATE,
              COMMIT_TIME_DIFFS.CLOSE_DATE
         FROM COMMIT_TIME_DIFFS
    LEFT JOIN AUTHOR_EXPERIENCE
           ON COMMIT_TIME_DIFFS.ISSUE_KEY = AUTHOR_EXPERIENCE.ISSUE_KEY
        WHERE AUTHOR_EXPERIENCE.ISSUE_KEY IS NULL
     ORDER BY COMMIT_TIME_DIFFS.ISSUE_KEY;
' '|' > $AUTHOR_EXPERIENCE_QUEUE_SOURCE_FILE

declare -ri NUM_ISSUES=$(wc -l < $AUTHOR_EXPERIENCE_QUEUE_SOURCE_FILE)
declare -i  ISSUE_INDEX=0
while IFS='|' read issue_key            \
                   project_id           \
                   creation_author      \
                   fix_author           \
                   creation_commit_hash \
                   close_commit_hash    \
                   source_file          \
                   creation_date        \
                   close_date
do
    ((++ISSUE_INDEX))
    log "START processing \"$issue_key\" $ISSUE_INDEX/$NUM_ISSUES"
    log "    issue_key=\"$issue_key\""
    log "    project_id=\"$project_id\""
    log "    creation_author=\"$creation_author\""
    log "    fix_author=\"$fix_author\""
    log "    creation_commit_hash=\"$creation_commit_hash\""
    log "    close_commit_hash=\"$close_commit_hash\""
    log "    source_file=\"$source_file\""
    log "    creation_date=\"$creation_date\""
    log "    close_date=\"$close_date\""
    insert_author_experience "$issue_key" 0 "$creation_author" "$project_id" "$source_file" "$creation_commit_hash" "$creation_date" &
    if [ -n "$fix_author" ]
    then
        insert_author_experience "$issue_key" 1 "$fix_author" "$project_id" "$source_file" "$close_commit_hash" "$close_date" &
    fi
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    log "DONE processing \"$issue_key\" $ISSUE_INDEX/$NUM_ISSUES"
done < $AUTHOR_EXPERIENCE_QUEUE_SOURCE_FILE

wait
log "DONE"

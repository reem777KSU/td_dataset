#!/bin/bash

# use strict mode
set -euo pipefail
declare IFS=$' \t\n'

# global variables
declare -r  THIS_SCRIPT_DIR=$(dirname $0)
declare -r  ORIGINAL_DIR=$(pwd -P)
declare -r  WORKSPACE_DIR=${1:-${ORIGINAL_DIR}/ws}
declare -r  PROJECTS_DIR=$WORKSPACE_DIR/projects
declare -r  INITIAL_DATABASE_PATH=$WORKSPACE_DIR/td_V2-initial.db
declare -r  DATABASE_PATH=$WORKSPACE_DIR/td_V2-modified.db
declare -r  DATABASE_DOWNLOAD_LINK='https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db'
declare -r  AUTHOR_EXPERIENCE_QUEUE_FILE=$WORKSPACE_DIR/AUTHOR_EXPERIENCE_QUEUE.csv
declare -r  AUTHOR_EXPERIENCE_LOCK_FILE=$WORKSPACE_DIR/AUTHOR_EXPERIENCE_LOCK.txt
declare -ri RECENT_DAY_DIFF=30

log() {
    echo >&2 "$@"
}

run_query() {
    local -r query=$1
    local -r separator=${2:- }

    log "running query: '$query'"
    sqlite3 -separator "$separator" $DATABASE_PATH "$query"
}

ensure_author_project_file_changes() {
    local -r author=$1
    local -r project_id=$2
    local -r file=$3

    run_query "
        INSERT OR IGNORE INTO AUTHOR_PROJECT_FILE_CHANGES
            (AUTHOR, PROJECT_ID, FILE)
        VALUES
            (\"$author\", \"$project_id\", \"$file\");
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

mine_project() {
    local -r project_id="$1"

    cd $PROJECTS_DIR/$project_id
    git shortlog --summary --numbered --email |
    while read commits author
    do
        regex_escaped_author=$(escape_regex "$author")
        first_commit_date=$(get_first_commit_date "$regex_escaped_author")
        run_query "
            INSERT INTO AUTHOR_PROJECT_COMMITS
            VALUES
                (\"$author\", \"$project_id\", $commits, \"$first_commit_date\");
        "
        git log --author="$regex_escaped_author" --pretty=tformat: --numstat -- '*.java' |
        while read line_additions line_subtractions file
        do
            if echo $file | grep --quiet ' => '
            then
                # is file rename
                read old_file new_file <<< $(echo $file | perl -pe 's|(.*){(.*?) => (.*?)}(.*)|\1\2\4 \1\3\4|')
                for renamed_file in $old_file $new_file
                do
                    ensure_author_project_file_changes "$author" "$project_id" "$renamed_file"
                    run_query "
                        UPDATE AUTHOR_PROJECT_FILE_CHANGES
                           SET RENAMES       = RENAMES + 1,
                               TOTAL_CHANGES = TOTAL_CHANGES + 1
                         WHERE AUTHOR     = \"$author\"       AND
                               PROJECT_ID = \"$project_id\"   AND
                               FILE       = \"$renamed_file\";
                    "
                done
            else
                # is in-place change
                # line changes aren't counted for binary files, for example
                if [ -z $line_additions ] || [ $line_additions = '-' ]
                then
                    line_additions=0
                fi
                if [ -z $line_subtractions ] || [ $line_subtractions = '-' ]
                then
                    line_subtractions=0
                fi
                ensure_author_project_file_changes "$author" "$project_id" "$file"
                run_query "
                    UPDATE AUTHOR_PROJECT_FILE_CHANGES
                       SET LINE_ADDITIONS     = LINE_ADDITIONS     + $line_additions,
                           LINE_SUBTRACTIONS  = LINE_SUBTRACTIONS  + $line_subtractions,
                           TOTAL_LINE_CHANGES = TOTAL_LINE_CHANGES + $line_additions    + $line_subtractions,
                           TOTAL_CHANGES      = TOTAL_CHANGES      + 1
                     WHERE AUTHOR     = \"$author\"     AND
                           PROJECT_ID = \"$project_id\" AND
                           FILE       = \"$file\";
                "
            fi
        done
    done
}


# move to workspace
mkdir -p $WORKSPACE_DIR
cd $WORKSPACE_DIR

# pull down database
if [ -f $INITIAL_DATABASE_PATH ]
then
    log "already downloaded database: '$INITIAL_DATABASE_PATH', skipping..."
else
    log "downloading database to '$INITIAL_DATABASE_PATH'"
    wget -O $INITIAL_DATABASE_PATH $DATABASE_DOWNLOAD_LINK
fi

# copy database for modification (if not already present)
cp --update $INITIAL_DATABASE_PATH $DATABASE_PATH

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

# Create the table 'COMMIT_TIME_DIFFS' from 'SONAR_ISSUES', 'SONAR_ANALYSIS',
# and 'GIT_COMMITS'.
run_query '
    CREATE TABLE IF NOT EXISTS COMMIT_TIME_DIFFS AS
        SELECT SONAR_ISSUES.ISSUE_KEY,
               SONAR_ISSUES.RULE,
               SONAR_ISSUES.CREATION_ANALYSIS_KEY,
               CASE WHEN SONAR_ISSUES.CLOSE_ANALYSIS_KEY IS ""
                    THEN NULL
                    ELSE SONAR_ISSUES.CLOSE_ANALYSIS_KEY
                    END
               AS CLOSE_ANALYSIS_KEY,
               SONAR_ISSUES.CREATION_DATE,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE IS ""
                    THEN NULL
                    ELSE SONAR_ISSUES.CLOSE_DATE
                    END
               AS CLOSE_DATE,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE IS NULL
                    THEN NULL
                    ELSE CAST((JULIANDAY(SONAR_ISSUES.CLOSE_DATE) - JULIANDAY(SONAR_ISSUES.CREATION_DATE)) AS INTEGER)
                    END
               AS DAY_DIFF,
               CASE WHEN SONAR_ISSUES.CLOSE_DATE IS NULL
                    THEN NULL
                    ELSE CAST((JULIANDAY(SONAR_ISSUES.CLOSE_DATE) - JULIANDAY(SONAR_ISSUES.CREATION_DATE)) AS INTEGER) * 24
                    END
               AS HOURS_DIFF,
               CREATION_ANALYSIS.REVISION AS CREATION_COMMIT_HASH,
               CLOSE_ANALYSIS.REVISION    AS CLOSE_COMMIT_HASH,
               CREATION_COMMITS.AUTHOR    AS CREATION_AUTHOR,
               FIX_COMMITS.AUTHOR         AS FIX_AUTHOR,
               SONAR_ISSUES.PROJECT_ID,
               REPLACE(SONAR_ISSUES.COMPONENT, RTRIM(SONAR_ISSUES.COMPONENT, REPLACE(SONAR_ISSUES.COMPONENT, ":", "")), "") AS FILE
          FROM SONAR_ISSUES
    INNER JOIN SONAR_ANALYSIS CREATION_ANALYSIS
            ON SONAR_ISSUES.CREATION_ANALYSIS_KEY = CREATION_ANALYSIS.ANALYSIS_KEY
    INNER JOIN GIT_COMMITS    CREATION_COMMITS
            ON CREATION_ANALYSIS.REVISION = CREATION_COMMITS.COMMIT_HASH
     LEFT JOIN SONAR_ANALYSIS CLOSE_ANALYSIS
            ON (SONAR_ISSUES.CLOSE_ANALYSIS_KEY != ""                          AND
                SONAR_ISSUES.CLOSE_ANALYSIS_KEY =  CLOSE_ANALYSIS.ANALYSIS_KEY)
     LEFT JOIN GIT_COMMITS    FIX_COMMITS
            ON CLOSE_ANALYSIS.REVISION = FIX_COMMITS.COMMIT_HASH
         WHERE SONAR_ISSUES.TYPE       =  "CODE_SMELL" AND
               (SONAR_ISSUES.RULE =    "common-java" OR
                SONAR_ISSUES.RULE LIKE "squid:%");
'
run_query '
    CREATE UNIQUE INDEX IF NOT EXISTS COMMIT_TIME_DIFFS_ISSUE_KEY_INDEX
        ON COMMIT_TIME_DIFFS (ISSUE_KEY);
'
run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
        AUTHOR            TEXT    NOT NULL,
        PROJECT_ID        TEXT    NOT NULL,
        COMMITS           INTEGER NOT NULL,
        FIRST_COMMIT_DATE TEXT    NOT NULL,
        PRIMARY KEY (AUTHOR, PROJECT_ID)
    );
'
run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_FILE_CHANGES (
        AUTHOR             TEXT              NOT NULL,
        PROJECT_ID         TEXT              NOT NULL,
        FILE               TEXT              NOT NULL,
        TOTAL_CHANGES      INTEGER DEFAULT 0 NOT NULL,
        RENAMES            INTEGER DEFAULT 0 NOT NULL,
        LINE_ADDITIONS     INTEGER DEFAULT 0 NOT NULL,
        LINE_SUBTRACTIONS  INTEGER DEFAULT 0 NOT NULL,
        TOTAL_LINE_CHANGES INTEGER DEFAULT 0 NOT NULL,
        PRIMARY KEY (AUTHOR, PROJECT_ID, FILE)
    );
'

run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_EXPERIENCE (
        ISSUE_KEY                               TEXT    NOT NULL,
        IS_FIX                                  INTEGER NOT NULL,
        AUTHOR                                  TEXT    NOT NULL,
        PROJECT_ID                              TEXT    NOT NULL,
        FILE                                    TEXT    NOT NULL,
        COMMIT_HASH                             TEXT    NOT NULL,
        COMMIT_DATE                             TEXT    NOT NULL,
        TOTAL_HOURS_SINCE_LAST_TOUCH            INTEGER,
        TOTAL_FILE_COMMITS                      INTEGER NOT NULL,
        TOTAL_PROJECT_COMMITS                   INTEGER NOT NULL,
        TOTAL_RECENT_FILE_COMMITS               INTEGER NOT NULL,
        TOTAL_RECENT_PROJECT_COMMITS            INTEGER NOT NULL,
        AUTHOR_HOURS_SINCE_LAST_TOUCH           INTEGER,
        AUTHOR_FILE_COMMITS                     INTEGER NOT NULL,
        AUTHOR_PROJECT_COMMITS                  INTEGER NOT NULL,
        AUTHOR_RECENT_FILE_COMMITS              INTEGER NOT NULL,
        AUTHOR_RECENT_PROJECT_COMMITS           INTEGER NOT NULL,
        AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT INTEGER NOT NULL,
        PRIMARY KEY (ISSUE_KEY, IS_FIX)
    );
'

# UNCOMMENT TO GENERATE REMAINING TABLES
# --------------------------------------
# build AUTHOR_PROJECT_COMMITS and AUTHOR_PROJECT_FILE_CHANGES
# FIXME: parallelize
# cd $PROJECTS_DIR
# for project_id in *
# do
#     mine_project "$project_id"
# done

# wait for mining to finish

commit_history() {
    git rev-list --count "$@" 2>/dev/null || echo 0
}

hours_since_last_touch() {
    local -r commit="$1"
    local -r file_pattern="$2"
    local -r author="$3"

    local -r last_commit="$(git rev-list -n 1 --author="$author" "$commit" -- "$file_pattern")"
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
    local -r  file="$5"
    local -r  commit_hash="$6"
    local -r  commit_date="$7"
    pushd $PROJECTS_DIR/$project_id

    local -r  regex_escaped_author=$(escape_regex "$author")
    local -r  file_pattern="*${file#*/src}"
    local -r  previous_revision="$commit_hash~"
    local -r  since_date="$(date -d "$(date -d  "$commit_date")-$RECENT_DAY_DIFF days")"
    local -r  first_commit_date=$(get_first_commit_date "$regex_escaped_author")

    local -r  total_hours_since_last_touch=$( hours_since_last_touch "$commit_hash" "$file_pattern" ".*")
    local -ri total_file_commits=$(          commit_history "$previous_revision" -- "$file_pattern")
    local -ri total_project_commits=$(       commit_history "$previous_revision")
    local -ri total_recent_file_commits=$(   commit_history "$previous_revision" --since="$since_date" -- "$file_pattern")
    local -ri total_recent_project_commits=$(commit_history "$previous_revision" --since="$since_date")
    local -r  author_hours_since_last_touch=$(hours_since_last_touch "$commit_hash" "$file_pattern" "$regex_escaped_author")
    local -ri author_file_commits=$(          commit_history --author="$regex_escaped_author" "$previous_revision" -- "$file_pattern")
    local -ri author_project_commits=$(       commit_history --author="$regex_escaped_author" "$previous_revision")
    local -ri author_recent_file_commits=$(   commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date" -- "$file_pattern")
    local -ri author_recent_project_commits=$(commit_history --author="$regex_escaped_author" "$previous_revision" --since="$since_date")
    let       author_hours_since_first_project_commit=($(date -d "$commit_date" +%s)-$(date -d "$first_commit_date" +%s ))/3600
    log "    issue_key,is_fix=\"$issue_key\",$is_fix"
    log "        author=\"$author\""
    log "        since_date=\"$since_date\""
    log "        commit_hash=\"$commit_hash\""
    log "        commit_date=\"$commit_date\""
    log "        total_hours_since_last_touch=\"$total_hours_since_last_touch\""
    log "        total_file_commits=\"$total_file_commits\""
    log "        total_project_commits=\"$total_project_commits\""
    log "        total_recent_file_commits=\"$total_recent_file_commits\""
    log "        total_recent_project_commits=\"$total_recent_project_commits\""
    log "        author_hours_since_last_touch=\"$author_hours_since_last_touch\""
    log "        author_file_commits=\"$author_file_commits\""
    log "        author_project_commits=\"$author_project_commits\""
    log "        author_recent_file_commits=\"$author_recent_file_commits\""
    log "        author_recent_project_commits=\"$author_recent_project_commits\""
    log "        author_hours_since_first_project_commit=$author_hours_since_first_project_commit"

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
                 \"$file\",
                 \"$commit_hash\",
                 \"$commit_date\",
                 $total_hours_since_last_touch,
                 $total_file_commits,
                 $total_project_commits,
                 $total_recent_file_commits,
                 $total_recent_project_commits,
                 $author_hours_since_last_touch,
                 $author_file_commits,
                 $author_project_commits,
                 $author_recent_file_commits,
                 $author_recent_project_commits,
                 $author_hours_since_first_project_commit);
        "
    }) 222>$AUTHOR_EXPERIENCE_LOCK_FILE

    popd
}

run_query '
    SELECT ISSUE_KEY,
           PROJECT_ID,
           CREATION_AUTHOR,
           FIX_AUTHOR,
           CREATION_COMMIT_HASH,
           CLOSE_COMMIT_HASH,
           FILE,
           CREATION_DATE,
           CLOSE_DATE
      FROM COMMIT_TIME_DIFFS
  ORDER BY ISSUE_KEY;
' '|' > $AUTHOR_EXPERIENCE_QUEUE_FILE

declare -ri NUM_ISSUES=$(run_query 'SELECT count(*) FROM COMMIT_TIME_DIFFS;')
declare -i  ISSUE_ID=0
while IFS='|' read issue_key            \
                   project_id           \
                   creation_author      \
                   fix_author           \
                   creation_commit_hash \
                   close_commit_hash    \
                   file                 \
                   creation_date        \
                   close_date
do
    ((++ISSUE_ID))
    log "START processing \"$issue_key\" $ISSUE_ID/$NUM_ISSUES"
    log "    issue_key=\"$issue_key\""
    log "    project_id=\"$project_id\""
    log "    creation_author=\"$creation_author\""
    log "    fix_author=\"$fix_author\""
    log "    creation_commit_hash=\"$creation_commit_hash\""
    log "    close_commit_hash=\"$close_commit_hash\""
    log "    file=\"$file\""
    log "    creation_date=\"$creation_date\""
    log "    close_date=\"$close_date\""
    insert_author_experience "$issue_key" 0 "$creation_author" "$project_id" "$file" "$creation_commit_hash" "$creation_date" &
    if [ -n "$fix_author" ]
    then
        insert_author_experience "$issue_key" 1 "$fix_author" "$project_id" "$file" "$close_commit_hash" "$close_date" &
    fi
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    log "DONE processing \"$issue_key\" $ISSUE_ID/$NUM_ISSUES"
done < $AUTHOR_EXPERIENCE_QUEUE_FILE

wait
log "DONE"

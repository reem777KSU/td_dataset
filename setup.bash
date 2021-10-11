#!/bin/bash

# use strict mode
set -euo pipefail
declare -r IFS=$' \t\n'

# global variables
declare -r THIS_SCRIPT_DIR=$(dirname $0)
declare -r ORIGINAL_DIR=$(pwd -P)
declare -r WORKSPACE_DIR=${1:-${ORIGINAL_DIR}/ws}
declare -r PROJECTS_DIR=$WORKSPACE_DIR/projects
declare -r INITIAL_DATABASE_PATH=$WORKSPACE_DIR/td_V2-initial.db
declare -r DATABASE_PATH=$WORKSPACE_DIR/td_V2-modified.db
declare -r DATABASE_DOWNLOAD_LINK='https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db'

log() {
    echo >&2 "$@"
}

run_query() {
    local -r query="$@"

    log "running query: '$query'"
    sqlite3 -separator ' ' $DATABASE_PATH "$query"
}
# SELECT DISTINCT SUBSTR(component, 0, INSTR(component, ':')) FROM sonar_issues;

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

mine_project() {
    local -r project_id="$1"

    cd $PROJECTS_DIR/$project_id
    git shortlog --summary --numbered --email |
    while read commits author
    do
        run_query "
            INSERT INTO AUTHOR_PROJECT_COMMITS
            VALUES
                (\"$author\", \"$project_id\", $commits);
        "
	regex_escaped=$(echo $author | sed -e 's/[]\/$*.^[]/\\&/g')
        git log --author="$regex_escaped" --pretty=tformat: --numstat -- '*.java' |
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
               SONAR_ISSUES.CLOSE_ANALYSIS_KEY,
               SONAR_ISSUES.CREATION_DATE,
               SONAR_ISSUES.CLOSE_DATE,
               SONAR_ISSUES.TYPE,
               CAST((julianday(SONAR_ISSUES.CLOSE_DATE) - julianday(SONAR_ISSUES.CREATION_DATE)) AS INTEGER)      AS DAY_DIFF,
               CAST((julianday(SONAR_ISSUES.CLOSE_DATE) - julianday(SONAR_ISSUES.CREATION_DATE)) * 24 AS INTEGER) AS HOURS_DIFF,
               CREATION_ANALYSIS.REVISION                                                                         AS CREATION_COMMIT_HASH,
               CLOSE_ANALYSIS.REVISION                                                                            AS CLOSE_COMMIT_HASH,
               CREATION_COMMITS.AUTHOR                                                                            AS CREATION_AUTHOR,
               FIX_COMMITS.AUTHOR                                                                                 AS FIX_AUTHOR
          FROM SONAR_ISSUES
    INNER JOIN SONAR_ANALYSIS CREATION_ANALYSIS
            ON CREATION_ANALYSIS_KEY      = CREATION_ANALYSIS.ANALYSIS_KEY
    INNER JOIN GIT_COMMITS    CREATION_COMMITS
            ON CREATION_ANALYSIS.REVISION = CREATION_COMMITS.COMMIT_HASH
    INNER JOIN SONAR_ANALYSIS CLOSE_ANALYSIS
            ON CLOSE_ANALYSIS_KEY         = CLOSE_ANALYSIS.ANALYSIS_KEY
    INNER JOIN GIT_COMMITS    FIX_COMMITS
            ON CLOSE_ANALYSIS.REVISION    = FIX_COMMITS.COMMIT_HASH
         WHERE SONAR_ISSUES.CLOSE_DATE != ""           AND
               SONAR_ISSUES.TYPE       =  "CODE_SMELL" AND
               (SONAR_ISSUES.RULE =    "common-java" OR
                SONAR_ISSUES.RULE LIKE "squid:%");
'

# UNCOMMENT TO GENERATE REMAINING TABLES
# --------------------------------------
# build AUTHOR_PROJECT_COMMITS and AUTHOR_PROJECT_FILE_CHANGES
# run_query '
#     CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
#         AUTHOR     TEXT    NOT NULL,
#         PROJECT_ID TEXT    NOT NULL,
#         COMMITS    INTEGER NOT NULL,
#         PRIMARY KEY (AUTHOR, PROJECT_ID)
#     );
#
#     CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_FILE_CHANGES (
#         AUTHOR             TEXT              NOT NULL,
#         PROJECT_ID         TEXT              NOT NULL,
#         FILE               TEXT              NOT NULL,
#         TOTAL_CHANGES      INTEGER DEFAULT 0 NOT NULL,
#         RENAMES            INTEGER DEFAULT 0 NOT NULL,
#         LINE_ADDITIONS     INTEGER DEFAULT 0 NOT NULL,
#         LINE_SUBTRACTIONS  INTEGER DEFAULT 0 NOT NULL,
#         TOTAL_LINE_CHANGES INTEGER DEFAULT 0 NOT NULL,
#         PRIMARY KEY (AUTHOR, PROJECT_ID, FILE)
#     );
# '
# # FIXME: parallelize
# cd $PROJECTS_DIR
# for project_id in *
# do
#     mine_project "$project_id"
# done

# wait for mining to finish

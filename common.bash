#!/bin/bash

# use strict mode
set -euo pipefail
declare IFS=$' \t\n'

declare -r  WORKSPACE_DIR=$THIS_SCRIPT_DIR/ws
declare -r  INITIAL_DATABASE_PATH=$WORKSPACE_DIR/td_V2-initial.db
declare -r  DATABASE_PATH=$THIS_SCRIPT_DIR/td_V2.db
declare -r  DATABASE_DOWNLOAD_LINK='https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db'

log() {
    echo -e >&2 "$@"
}

run_query() {
    local -r query=$1
    local -r separator=${2:- }

    log "running query: '$query'"
    sqlite3 -separator "$separator" $DATABASE_PATH "$query"
}

# create workspace dir if doesn't exist
mkdir -p $WORKSPACE_DIR

# pull down database
if [ -f $INITIAL_DATABASE_PATH ]
then
    log "already downloaded database: '$INITIAL_DATABASE_PATH', skipping..."
else
    log "downloading database to '$INITIAL_DATABASE_PATH'"
    wget -O $INITIAL_DATABASE_PATH $DATABASE_DOWNLOAD_LINK
fi

# copy database for modification (if not already present)
log "Copying '$DATABASE_PATH' from '$INITIAL_DATABASE_PATH' if out of date..."
cp --update $INITIAL_DATABASE_PATH $DATABASE_PATH

run_query '
    CREATE TABLE IF NOT EXISTS COMMIT_TIME_DIFFS (
        ISSUE_KEY             TEXT NOT NULL,
        RULE                  TEXT NOT NULL,
        CREATION_ANALYSIS_KEY TEXT NOT NULL,
        CLOSE_ANALYSIS_KEY    TEXT,
        CREATION_DATE         TEXT NOT NULL,
        CLOSE_DATE            TEXT,
        DAY_DIFF              INTEGER,
        HOURS_DIFF            INTEGER,
        CREATION_COMMIT_HASH  TEXT NOT NULL,
        CLOSE_COMMIT_HASH     TEXT,
        CREATION_AUTHOR       TEXT NOT NULL,
        FIX_AUTHOR            TEXT,
        PROJECT_ID            TEXT NOT NULL,
        SOURCE_FILE           TEXT NOT NULL,
        PRIMARY KEY (ISSUE_KEY)
    );
'
run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
        AUTHOR              TEXT    NOT NULL,
        PROJECT_ID          TEXT    NOT NULL,
        COMMITS             INTEGER NOT NULL,
        SOURCE_FILE_COMMITS INTEGER NOT NULL,
        FIRST_COMMIT_DATE TEXT      NOT NULL,
        PRIMARY KEY (AUTHOR, PROJECT_ID)
    );
'
run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_SOURCE_FILE_CHANGES (
        AUTHOR             TEXT              NOT NULL,
        PROJECT_ID         TEXT              NOT NULL,
        SOURCE_FILE        TEXT              NOT NULL,
        TOTAL_CHANGES      INTEGER DEFAULT 0 NOT NULL,
        RENAMES            INTEGER DEFAULT 0 NOT NULL,
        LINE_ADDITIONS     INTEGER DEFAULT 0 NOT NULL,
        LINE_SUBTRACTIONS  INTEGER DEFAULT 0 NOT NULL,
        TOTAL_LINE_CHANGES INTEGER DEFAULT 0 NOT NULL,
        PRIMARY KEY (AUTHOR, PROJECT_ID, SOURCE_FILE)
    );
'
run_query '
    CREATE TABLE IF NOT EXISTS AUTHOR_EXPERIENCE (
        ISSUE_KEY                                   TEXT    NOT NULL,
        IS_FIX                                      INTEGER NOT NULL,
        AUTHOR                                      TEXT    NOT NULL,
        PROJECT_ID                                  TEXT    NOT NULL,
        SOURCE_FILE                                 TEXT    NOT NULL,
        COMMIT_HASH                                 TEXT    NOT NULL,
        COMMIT_DATE                                 TEXT    NOT NULL,

        TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,

        TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,

        TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,

        TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,

        TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,

        AUTHOR_HOURS_SINCE_LAST_TOUCH               INTEGER,
        AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT     INTEGER NOT NULL,

        AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,

        AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,

        AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,

        AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,

        PRIMARY KEY (ISSUE_KEY, IS_FIX)
    );
'
run_query '
    CREATE TABLE IF NOT EXISTS PROJECT_STATS (
        PROJECT_ID          TEXT    NOT NULL,
        FILES               INTEGER NOT NULL,
        SOURCE_FILES        INTEGER NOT NULL,
        LINES               INTEGER NOT NULL,
        SOURCE_FILE_LINES   INTEGER NOT NULL,
        COMMITS             INTEGER NOT NULL,
        SOURCE_FILE_COMMITS INTEGER NOT NULL,
        PRIMARY KEY (PROJECT_ID)
    );
'

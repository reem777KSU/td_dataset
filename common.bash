#!/bin/bash

# use strict mode
set -euo pipefail
declare IFS=$' \t\n'

declare -r  WORKSPACE_DIR=$THIS_SCRIPT_DIR/ws
declare -r  PROJECTS_DIR=$WORKSPACE_DIR/projects
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
    
        ANALYSIS_KEY                                TEXT    DEFAULT "" NOT NULL,
        SQALE_INDEX                                 INTEGER DEFAULT 0  NOT NULL,
        IS_FAULT_INDUCING                           INTEGER DEFAULT 0  NOT NULL,
        IS_FAULT_FIXING                             INTEGER DEFAULT 0  NOT NULL,

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
run_query '
    CREATE TABLE IF NOT EXISTS PROJECT_COMMIT_RULE_VIOLATIONS (
        PROJECT_ID                              TEXT               NOT NULL, 
        COMMIT_HASH                             TEXT    DEFAULT "" NOT NULL, 
        COMMIT_DATE                             TEXT    DEFAULT "" NOT NULL, 
        AUTHOR                                  TEXT    DEFAULT "" NOT NULL, 
        ANALYSIS_KEY                            TEXT    DEFAULT "" NOT NULL,
        SQALE_INDEX                             INTEGER DEFAULT 0  NOT NULL,
        IS_FAULT_INDUCING                       INTEGER DEFAULT 0  NOT NULL,
        IS_FAULT_FIXING                         INTEGER DEFAULT 0  NOT NULL,
        NUM_FILES                               INTEGER DEFAULT 0  NOT NULL,
        NUM_DIRECTORIES                         INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_FILES                        INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_DIRECTORIES                  INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_ADDITIONS               INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_SUBTRACTIONS            INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_CHANGES                 INTEGER DEFAULT 0  NOT NULL,

        TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,

        TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,

        TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,
        TOTAL_PROJECT_LINE_ADDITIONS                INTEGER NOT NULL, -- NEW
        TOTAL_PROJECT_LINE_SUBTRACTIONS             INTEGER NOT NULL, -- NEW
        TOTAL_PROJECT_LINE_CHANGES                  INTEGER NOT NULL, -- NEW

        TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,

        TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,
        TOTAL_RECENT_PROJECT_LINE_ADDITIONS         INTEGER NOT NULL, -- NEW
        TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS      INTEGER NOT NULL, -- NEW
        TOTAL_RECENT_PROJECT_LINE_CHANGES           INTEGER NOT NULL, -- NEW

        AUTHOR_HOURS_SINCE_LAST_TOUCH               INTEGER,
        AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT     INTEGER NOT NULL,

        AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,

        AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,
        AUTHOR_PROJECT_LINE_ADDITIONS               INTEGER NOT NULL, -- NEW
        AUTHOR_PROJECT_LINE_SUBTRACTIONS            INTEGER NOT NULL, -- NEW
        AUTHOR_PROJECT_LINE_CHANGES                 INTEGER NOT NULL, -- NEW

        AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,

        AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,
        AUTHOR_RECENT_PROJECT_LINE_ADDITIONS        INTEGER NOT NULL, -- NEW
        AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS     INTEGER NOT NULL, -- NEW
        AUTHOR_RECENT_PROJECT_LINE_CHANGES          INTEGER NOT NULL, -- NEW

        `squid:AssignmentInSubExpressionCheck`  INTEGER DEFAULT 0  NOT NULL,
        `squid:ClassCyclomaticComplexity`       INTEGER DEFAULT 0  NOT NULL,
        `squid:CommentedOutCodeLine`            INTEGER DEFAULT 0  NOT NULL,
        `squid:EmptyStatementUsageCheck`        INTEGER DEFAULT 0  NOT NULL,
        `squid:ForLoopCounterChangedCheck`      INTEGER DEFAULT 0  NOT NULL,
        `squid:HiddenFieldCheck`                INTEGER DEFAULT 0  NOT NULL,
        `squid:LabelsShouldNotBeUsedCheck`      INTEGER DEFAULT 0  NOT NULL,
        `squid:MethodCyclomaticComplexity`      INTEGER DEFAULT 0  NOT NULL,
        `squid:MissingDeprecatedCheck`          INTEGER DEFAULT 0  NOT NULL,
        `squid:ModifiersOrderCheck`             INTEGER DEFAULT 0  NOT NULL,
        `squid:RedundantThrowsDeclarationCheck` INTEGER DEFAULT 0  NOT NULL,
        `squid:RightCurlyBraceStartLineCheck`   INTEGER DEFAULT 0  NOT NULL,
        `squid:S00100`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00101`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00105`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00107`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00108`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00112`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00114`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00115`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00116`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00117`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00119`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00120`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S00122`                          INTEGER DEFAULT 0  NOT NULL,
        `squid:S106`                            INTEGER DEFAULT 0  NOT NULL,
        `squid:S1065`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1066`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1067`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1068`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1118`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1125`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1126`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1132`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1133`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1134`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1135`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1141`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1147`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1149`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1150`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1151`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1153`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1155`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1157`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1158`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1160`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1161`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1163`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1165`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1166`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1168`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1170`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1171`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1172`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1174`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1181`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1185`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1186`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1188`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1190`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1191`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1192`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1193`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1194`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1195`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1197`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1199`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1213`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1214`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1215`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1219`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1220`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1223`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1226`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S128`                            INTEGER DEFAULT 0  NOT NULL,
        `squid:S1301`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1312`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1314`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1319`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S134`                            INTEGER DEFAULT 0  NOT NULL,
        `squid:S135`                            INTEGER DEFAULT 0  NOT NULL,
        `squid:S1452`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1479`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1481`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1488`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1596`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1598`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1700`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1905`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S1994`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2065`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2094`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2130`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2131`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2133`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2160`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2165`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2166`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2176`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2178`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2232`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2235`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2250`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2274`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2326`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2388`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2437`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2438`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2440`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2442`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S2447`                           INTEGER DEFAULT 0  NOT NULL,
        `squid:S888`                            INTEGER DEFAULT 0  NOT NULL,
        `squid:SwitchLastCaseIsDefaultCheck`    INTEGER DEFAULT 0  NOT NULL,
        `squid:UnusedPrivateMethod`             INTEGER DEFAULT 0  NOT NULL,
        `squid:UselessImportCheck`              INTEGER DEFAULT 0  NOT NULL,
        `squid:UselessParenthesesCheck`         INTEGER DEFAULT 0  NOT NULL,
        PRIMARY KEY (PROJECT_ID, COMMIT_HASH)
    );
'

run_query '
    CREATE TABLE IF NOT EXISTS PROJECT_COMMIT_STATISTICS (
        PROJECT_ID                              TEXT               NOT NULL, 
        COMMIT_HASH                             TEXT    DEFAULT "" NOT NULL, 
        COMMIT_DATE                             TEXT    DEFAULT "" NOT NULL, 
        AUTHOR                                  TEXT    DEFAULT "" NOT NULL, 
        NUM_FILES                               INTEGER DEFAULT 0  NOT NULL,
        NUM_DIRECTORIES                         INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        NUM_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_FILES                        INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_DIRECTORIES                  INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_ADDITIONS               INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_SUBTRACTIONS            INTEGER DEFAULT 0  NOT NULL,
        NUM_SOURCE_LINE_CHANGES                 INTEGER DEFAULT 0  NOT NULL,

        TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,

        TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
        TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,

        TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,
        TOTAL_PROJECT_LINE_ADDITIONS                INTEGER NOT NULL, -- NEW
        TOTAL_PROJECT_LINE_SUBTRACTIONS             INTEGER NOT NULL, -- NEW
        TOTAL_PROJECT_LINE_CHANGES                  INTEGER NOT NULL, -- NEW

        TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
        TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,

        TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,
        TOTAL_RECENT_PROJECT_LINE_ADDITIONS         INTEGER NOT NULL, -- NEW
        TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS      INTEGER NOT NULL, -- NEW
        TOTAL_RECENT_PROJECT_LINE_CHANGES           INTEGER NOT NULL, -- NEW

        AUTHOR_HOURS_SINCE_LAST_TOUCH               INTEGER,
        AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT     INTEGER NOT NULL,

        AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
        AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,

        AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,
        AUTHOR_PROJECT_LINE_ADDITIONS               INTEGER NOT NULL, -- NEW
        AUTHOR_PROJECT_LINE_SUBTRACTIONS            INTEGER NOT NULL, -- NEW
        AUTHOR_PROJECT_LINE_CHANGES                 INTEGER NOT NULL, -- NEW

        AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
        AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,

        AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,
        AUTHOR_RECENT_PROJECT_LINE_ADDITIONS        INTEGER NOT NULL, -- NEW
        AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS     INTEGER NOT NULL, -- NEW
        AUTHOR_RECENT_PROJECT_LINE_CHANGES          INTEGER NOT NULL, -- NEW

        PRIMARY KEY (PROJECT_ID, COMMIT_HASH)
    );
'

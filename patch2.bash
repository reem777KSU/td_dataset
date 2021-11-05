#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash

# declare -r PROJECT_COMMIT_RULE_VIOLATIONS_LOCK_FILE=$WORKSPACE_DIR/PROJECT_COMMIT_RULE_VIOLATIONS_LOCK.txt
# 
# update_project_commit_rule_violations() {
#     local -r project_id=$1
#     local -r commit_hash=$2
#     local -r rule=$3
#     local -r count=$4
# 
#     local -ri lock_fd=222
#     (flock $lock_fd
#     {
#         run_query "
#             INSERT OR IGNORE INTO PROJECT_COMMIT_RULE_VIOLATIONS
#                 (PROJECT_ID, COMMIT_HASH)
#             VALUES
#                 (\"$project_id\", \"$commit_hash\");
#         "
#     }) 222>$PROJECT_COMMIT_RULE_VIOLATIONS_LOCK_FILE
#     (flock $lock_fd
#     {
#         run_query "
#             UPDATE PROJECT_COMMIT_RULE_VIOLATIONS
#                SET \`$rule\` = \`$rule\` + $count
#              WHERE PROJECT_ID  = \"$project_id\"  AND
#                    COMMIT_HASH = \"$commit_hash\";
#         "
#     }) 222>$PROJECT_COMMIT_RULE_VIOLATIONS_LOCK_FILE
# }
# 
# while read project_id commit_hash rule count
# do
#     update_project_commit_rule_violations "$project_id" "$commit_hash" "$rule" "$count" &
#     [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
# done <<< $(run_query '
#       SELECT PROJECT_ID, CREATION_COMMIT_HASH, RULE, COUNT(*) AS COUNT
#         FROM COMMIT_TIME_DIFFS
#     GROUP BY PROJECT_ID, CREATION_COMMIT_HASH, RULE
#     ORDER BY PROJECT_ID, CREATION_COMMIT_HASH, RULE, COUNT;
# ' )
# 
# wait
# log "DONE"

run_query '
    DROP TABLE IF EXISTS PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
'

run_query '
    ALTER TABLE PROJECT_COMMIT_RULE_VIOLATIONS
      RENAME TO PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
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
    INSERT OR IGNORE INTO PROJECT_COMMIT_RULE_VIOLATIONS
            SELECT PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH,
                   AUTHOR_EXPERIENCE.COMMIT_DATE,
                   AUTHOR_EXPERIENCE.AUTHOR,
                   AUTHOR_EXPERIENCE.ANALYSIS_KEY,
                   AUTHOR_EXPERIENCE.SQALE_INDEX,
                   AUTHOR_EXPERIENCE.IS_FAULT_INDUCING,
                   AUTHOR_EXPERIENCE.IS_FAULT_FIXING,
                   /* NUM_FILES                    = */ 0,
                   /* NUM_DIRECTORIES              = */ 0,
                   GIT_COMMITS_CHANGES.LINES_ADDED,
                   GIT_COMMITS_CHANGES.LINES_REMOVED,
                   GIT_COMMITS_CHANGES.LINES_ADDED + GIT_COMMITS_CHANGES.LINES_REMOVED,
                   /* NUM_SOURCE_FILES             = */ 0,
                   /* NUM_SOURCE_DIRECTORIES       = */ 0,
                   /* NUM_SOURCE_LINE_ADDITIONS    = */ 0,
                   /* NUM_SOURCE_LINE_SUBTRACTIONS = */ 0,
                   /* NUM_SOURCE_LINE_CHANGES      = */ 0,
                   AUTHOR_EXPERIENCE.TOTAL_HOURS_SINCE_LAST_TOUCH,
                   AUTHOR_EXPERIENCE.TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   AUTHOR_EXPERIENCE.TOTAL_SOURCE_FILE_COMMITS,
                   AUTHOR_EXPERIENCE.TOTAL_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_EXPERIENCE.TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_EXPERIENCE.TOTAL_SOURCE_FILE_LINE_CHANGES,

                   AUTHOR_EXPERIENCE.TOTAL_PROJECT_COMMITS,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_LINE_ADDITIONS    = */ 0,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_LINE_SUBTRACTIONS = */ 0,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_LINE_CHANGES      = */ 0,

                   AUTHOR_EXPERIENCE.TOTAL_RECENT_SOURCE_FILE_COMMITS,
                   AUTHOR_EXPERIENCE.TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_EXPERIENCE.TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_EXPERIENCE.TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES,

                   AUTHOR_EXPERIENCE.TOTAL_RECENT_PROJECT_COMMITS,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_RECENT_LINE_ADDITIONS    = */ 0,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_RECENT_LINE_SUBTRACTIONS = */ 0,
                   /* AUTHOR_EXPERIENCE.TOTAL_PROJECT_RECENT_LINE_CHANGES      = */ 0,

                   AUTHOR_EXPERIENCE.AUTHOR_HOURS_SINCE_LAST_TOUCH,
                   AUTHOR_EXPERIENCE.AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   AUTHOR_EXPERIENCE.AUTHOR_SOURCE_FILE_COMMITS,
                   AUTHOR_EXPERIENCE.AUTHOR_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_EXPERIENCE.AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_EXPERIENCE.AUTHOR_SOURCE_FILE_LINE_CHANGES,

                   AUTHOR_EXPERIENCE.AUTHOR_PROJECT_COMMITS,
                   /* AUTHOR_EXPERIENCE.AUTHOR_PROJECT_LINE_ADDITIONS    = */ 0,
                   /* AUTHOR_EXPERIENCE.AUTHOR_PROJECT_LINE_SUBTRACTIONS = */ 0,
                   /* AUTHOR_EXPERIENCE.AUTHOR_PROJECT_LINE_CHANGES      = */ 0,

                   AUTHOR_EXPERIENCE.AUTHOR_RECENT_SOURCE_FILE_COMMITS,
                   AUTHOR_EXPERIENCE.AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   AUTHOR_EXPERIENCE.AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   AUTHOR_EXPERIENCE.AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES,

                   AUTHOR_EXPERIENCE.AUTHOR_RECENT_PROJECT_COMMITS,
                   /* AUTHOR_EXPERIENCE.AUTHOR_RECENT_PROJECT_LINE_ADDITIONS    = */ 0,
                   /* AUTHOR_EXPERIENCE.AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS = */ 0,
                   /* AUTHOR_EXPERIENCE.AUTHOR_RECENT_PROJECT_LINE_CHANGES      = */ 0,

                   `squid:AssignmentInSubExpressionCheck`,
                   `squid:ClassCyclomaticComplexity`,
                   `squid:CommentedOutCodeLine`,
                   `squid:EmptyStatementUsageCheck`,
                   `squid:ForLoopCounterChangedCheck`,
                   `squid:HiddenFieldCheck`,
                   `squid:LabelsShouldNotBeUsedCheck`,
                   `squid:MethodCyclomaticComplexity`,
                   `squid:MissingDeprecatedCheck`,
                   `squid:ModifiersOrderCheck`,
                   `squid:RedundantThrowsDeclarationCheck`,
                   `squid:RightCurlyBraceStartLineCheck`,
                   `squid:S00100`,
                   `squid:S00101`,
                   `squid:S00105`,
                   `squid:S00107`,
                   `squid:S00108`,
                   `squid:S00112`,
                   `squid:S00114`,
                   `squid:S00115`,
                   `squid:S00116`,
                   `squid:S00117`,
                   `squid:S00119`,
                   `squid:S00120`,
                   `squid:S00122`,
                   `squid:S106`,
                   `squid:S1065`,
                   `squid:S1066`,
                   `squid:S1067`,
                   `squid:S1068`,
                   `squid:S1118`,
                   `squid:S1125`,
                   `squid:S1126`,
                   `squid:S1132`,
                   `squid:S1133`,
                   `squid:S1134`,
                   `squid:S1135`,
                   `squid:S1141`,
                   `squid:S1147`,
                   `squid:S1149`,
                   `squid:S1150`,
                   `squid:S1151`,
                   `squid:S1153`,
                   `squid:S1155`,
                   `squid:S1157`,
                   `squid:S1158`,
                   `squid:S1160`,
                   `squid:S1161`,
                   `squid:S1163`,
                   `squid:S1165`,
                   `squid:S1166`,
                   `squid:S1168`,
                   `squid:S1170`,
                   `squid:S1171`,
                   `squid:S1172`,
                   `squid:S1174`,
                   `squid:S1181`,
                   `squid:S1185`,
                   `squid:S1186`,
                   `squid:S1188`,
                   `squid:S1190`,
                   `squid:S1191`,
                   `squid:S1192`,
                   `squid:S1193`,
                   `squid:S1194`,
                   `squid:S1195`,
                   `squid:S1197`,
                   `squid:S1199`,
                   `squid:S1213`,
                   `squid:S1214`,
                   `squid:S1215`,
                   `squid:S1219`,
                   `squid:S1220`,
                   `squid:S1223`,
                   `squid:S1226`,
                   `squid:S128`,
                   `squid:S1301`,
                   `squid:S1312`,
                   `squid:S1314`,
                   `squid:S1319`,
                   `squid:S134`,
                   `squid:S135`,
                   `squid:S1452`,
                   `squid:S1479`,
                   `squid:S1481`,
                   `squid:S1488`,
                   `squid:S1596`,
                   `squid:S1598`,
                   `squid:S1700`,
                   `squid:S1905`,
                   `squid:S1994`,
                   `squid:S2065`,
                   `squid:S2094`,
                   `squid:S2130`,
                   `squid:S2131`,
                   `squid:S2133`,
                   `squid:S2160`,
                   `squid:S2165`,
                   `squid:S2166`,
                   `squid:S2176`,
                   `squid:S2178`,
                   `squid:S2232`,
                   `squid:S2235`,
                   `squid:S2250`,
                   `squid:S2274`,
                   `squid:S2326`,
                   `squid:S2388`,
                   `squid:S2437`,
                   `squid:S2438`,
                   `squid:S2440`,
                   `squid:S2442`,
                   `squid:S2447`,
                   `squid:S888`,
                   `squid:SwitchLastCaseIsDefaultCheck`,
                   `squid:UnusedPrivateMethod`,
                   `squid:UselessImportCheck`,
                   `squid:UselessParenthesesCheck`
              FROM PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL
        INNER JOIN AUTHOR_EXPERIENCE
                ON AUTHOR_EXPERIENCE.PROJECT_ID  = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID AND
                   AUTHOR_EXPERIENCE.COMMIT_HASH = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH
        INNER JOIN GIT_COMMITS_CHANGES
                ON GIT_COMMITS_CHANGES.PROJECT_ID  = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID AND
                   GIT_COMMITS_CHANGES.COMMIT_HASH = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH
             WHERE AUTHOR_EXPERIENCE.IS_FIX = 0;
'

run_query '
    DROP TABLE PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
'

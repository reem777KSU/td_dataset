#!/bin/bash

# global variables
declare -r THIS_SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

. $THIS_SCRIPT_DIR/common.bash


run_query '
    DROP TABLE IF EXISTS PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
'

run_query '
    ALTER TABLE PROJECT_COMMIT_RULE_VIOLATIONS
      RENAME TO PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
'

run_query '
    INSERT OR IGNORE INTO PROJECT_COMMIT_STATISTICS
            SELECT PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_DATE,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_FILES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_DIRECTORIES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_CHANGES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_FILES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_DIRECTORIES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_HOURS_SINCE_LAST_TOUCH,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_HOURS_SINCE_LAST_TOUCH,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_CHANGES
              FROM PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
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
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_DATE,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR,
                   SONAR_ANALYSIS.ANALYSIS_KEY,
                   SONAR_MEASURES.SQALE_INDEX,
                   CASE WHEN FAULT_INDUCING_COMMITS.FAULT_INDUCING_COMMIT_HASH IS NULL
                        THEN 0
                        ELSE 1
                        END
                   AS IS_FAULT_INDUCING,
                   CASE WHEN FAULT_FIXING_COMMITS.FAULT_FIXING_COMMIT_HASH IS NULL
                        THEN 0
                        ELSE 1
                        END
                   AS IS_FAULT_FIXING,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_FILES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_DIRECTORIES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_LINE_CHANGES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_FILES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_DIRECTORIES,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.NUM_SOURCE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_HOURS_SINCE_LAST_TOUCH,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.TOTAL_RECENT_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_HOURS_SINCE_LAST_TOUCH,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_PROJECT_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES,

                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_COMMITS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_ADDITIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS,
                   PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.AUTHOR_RECENT_PROJECT_LINE_CHANGES,

                   /* `squid:AssignmentInSubExpressionCheck`  = */ 0,
                   /* `squid:ClassCyclomaticComplexity`       = */ 0,
                   /* `squid:CommentedOutCodeLine`            = */ 0,
                   /* `squid:EmptyStatementUsageCheck`        = */ 0,
                   /* `squid:ForLoopCounterChangedCheck`      = */ 0,
                   /* `squid:HiddenFieldCheck`                = */ 0,
                   /* `squid:LabelsShouldNotBeUsedCheck`      = */ 0,
                   /* `squid:MethodCyclomaticComplexity`      = */ 0,
                   /* `squid:MissingDeprecatedCheck`          = */ 0,
                   /* `squid:ModifiersOrderCheck`             = */ 0,
                   /* `squid:RedundantThrowsDeclarationCheck` = */ 0,
                   /* `squid:RightCurlyBraceStartLineCheck`   = */ 0,
                   /* `squid:S00100`                          = */ 0,
                   /* `squid:S00101`                          = */ 0,
                   /* `squid:S00105`                          = */ 0,
                   /* `squid:S00107`                          = */ 0,
                   /* `squid:S00108`                          = */ 0,
                   /* `squid:S00112`                          = */ 0,
                   /* `squid:S00114`                          = */ 0,
                   /* `squid:S00115`                          = */ 0,
                   /* `squid:S00116`                          = */ 0,
                   /* `squid:S00117`                          = */ 0,
                   /* `squid:S00119`                          = */ 0,
                   /* `squid:S00120`                          = */ 0,
                   /* `squid:S00122`                          = */ 0,
                   /* `squid:S106`                            = */ 0,
                   /* `squid:S1065`                           = */ 0,
                   /* `squid:S1066`                           = */ 0,
                   /* `squid:S1067`                           = */ 0,
                   /* `squid:S1068`                           = */ 0,
                   /* `squid:S1118`                           = */ 0,
                   /* `squid:S1125`                           = */ 0,
                   /* `squid:S1126`                           = */ 0,
                   /* `squid:S1132`                           = */ 0,
                   /* `squid:S1133`                           = */ 0,
                   /* `squid:S1134`                           = */ 0,
                   /* `squid:S1135`                           = */ 0,
                   /* `squid:S1141`                           = */ 0,
                   /* `squid:S1147`                           = */ 0,
                   /* `squid:S1149`                           = */ 0,
                   /* `squid:S1150`                           = */ 0,
                   /* `squid:S1151`                           = */ 0,
                   /* `squid:S1153`                           = */ 0,
                   /* `squid:S1155`                           = */ 0,
                   /* `squid:S1157`                           = */ 0,
                   /* `squid:S1158`                           = */ 0,
                   /* `squid:S1160`                           = */ 0,
                   /* `squid:S1161`                           = */ 0,
                   /* `squid:S1163`                           = */ 0,
                   /* `squid:S1165`                           = */ 0,
                   /* `squid:S1166`                           = */ 0,
                   /* `squid:S1168`                           = */ 0,
                   /* `squid:S1170`                           = */ 0,
                   /* `squid:S1171`                           = */ 0,
                   /* `squid:S1172`                           = */ 0,
                   /* `squid:S1174`                           = */ 0,
                   /* `squid:S1181`                           = */ 0,
                   /* `squid:S1185`                           = */ 0,
                   /* `squid:S1186`                           = */ 0,
                   /* `squid:S1188`                           = */ 0,
                   /* `squid:S1190`                           = */ 0,
                   /* `squid:S1191`                           = */ 0,
                   /* `squid:S1192`                           = */ 0,
                   /* `squid:S1193`                           = */ 0,
                   /* `squid:S1194`                           = */ 0,
                   /* `squid:S1195`                           = */ 0,
                   /* `squid:S1197`                           = */ 0,
                   /* `squid:S1199`                           = */ 0,
                   /* `squid:S1213`                           = */ 0,
                   /* `squid:S1214`                           = */ 0,
                   /* `squid:S1215`                           = */ 0,
                   /* `squid:S1219`                           = */ 0,
                   /* `squid:S1220`                           = */ 0,
                   /* `squid:S1223`                           = */ 0,
                   /* `squid:S1226`                           = */ 0,
                   /* `squid:S128`                            = */ 0,
                   /* `squid:S1301`                           = */ 0,
                   /* `squid:S1312`                           = */ 0,
                   /* `squid:S1314`                           = */ 0,
                   /* `squid:S1319`                           = */ 0,
                   /* `squid:S134`                            = */ 0,
                   /* `squid:S135`                            = */ 0,
                   /* `squid:S1452`                           = */ 0,
                   /* `squid:S1479`                           = */ 0,
                   /* `squid:S1481`                           = */ 0,
                   /* `squid:S1488`                           = */ 0,
                   /* `squid:S1596`                           = */ 0,
                   /* `squid:S1598`                           = */ 0,
                   /* `squid:S1700`                           = */ 0,
                   /* `squid:S1905`                           = */ 0,
                   /* `squid:S1994`                           = */ 0,
                   /* `squid:S2065`                           = */ 0,
                   /* `squid:S2094`                           = */ 0,
                   /* `squid:S2130`                           = */ 0,
                   /* `squid:S2131`                           = */ 0,
                   /* `squid:S2133`                           = */ 0,
                   /* `squid:S2160`                           = */ 0,
                   /* `squid:S2165`                           = */ 0,
                   /* `squid:S2166`                           = */ 0,
                   /* `squid:S2176`                           = */ 0,
                   /* `squid:S2178`                           = */ 0,
                   /* `squid:S2232`                           = */ 0,
                   /* `squid:S2235`                           = */ 0,
                   /* `squid:S2250`                           = */ 0,
                   /* `squid:S2274`                           = */ 0,
                   /* `squid:S2326`                           = */ 0,
                   /* `squid:S2388`                           = */ 0,
                   /* `squid:S2437`                           = */ 0,
                   /* `squid:S2438`                           = */ 0,
                   /* `squid:S2440`                           = */ 0,
                   /* `squid:S2442`                           = */ 0,
                   /* `squid:S2447`                           = */ 0,
                   /* `squid:S888`                            = */ 0,
                   /* `squid:SwitchLastCaseIsDefaultCheck`    = */ 0,
                   /* `squid:UnusedPrivateMethod`             = */ 0,
                   /* `squid:UselessImportCheck`              = */ 0,
                   /* `squid:UselessParenthesesCheck`         = */ 0

              FROM PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL
        INNER JOIN SONAR_ANALYSIS
                ON SONAR_ANALYSIS.PROJECT_ID = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID AND
                   SONAR_ANALYSIS.REVISION   = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH
        INNER JOIN SONAR_MEASURES
                ON (SONAR_MEASURES.PROJECT_ID   = SONAR_ANALYSIS.PROJECT_ID AND
                    SONAR_MEASURES.ANALYSIS_KEY = SONAR_ANALYSIS.ANALYSIS_KEY)
         LEFT JOIN SZZ_FAULT_INDUCING_COMMITS  FAULT_INDUCING_COMMITS
                ON (FAULT_INDUCING_COMMITS.PROJECT_ID                 = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID AND
                    FAULT_INDUCING_COMMITS.FAULT_INDUCING_COMMIT_HASH = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH)
         LEFT JOIN SZZ_FAULT_INDUCING_COMMITS  FAULT_FIXING_COMMITS
                ON (FAULT_FIXING_COMMITS.PROJECT_ID               = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.PROJECT_ID AND
                    FAULT_FIXING_COMMITS.FAULT_FIXING_COMMIT_HASH = PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL.COMMIT_HASH);
'

run_query '
    DROP TABLE PROJECT_COMMIT_RULE_VIOLATIONS_ORIGINAL;
'

declare -r PROJECT_COMMIT_RULE_VIOLATIONS_LOCK_FILE=$WORKSPACE_DIR/PROJECT_COMMIT_RULE_VIOLATIONS_LOCK.txt

update_project_commit_rule_violations() {
    local -r project_id=$1
    local -r commit_hash=$2
    local -r rule=$3
    local -r count=$4

    local -ri lock_fd=222
    (flock $lock_fd
    {
        run_query "
            UPDATE PROJECT_COMMIT_RULE_VIOLATIONS
               SET \`$rule\` = \`$rule\` + $count
             WHERE PROJECT_ID  = \"$project_id\"  AND
                   COMMIT_HASH = \"$commit_hash\";
        "
    }) 222>$PROJECT_COMMIT_RULE_VIOLATIONS_LOCK_FILE
}

while read project_id commit_hash rule count
do
    update_project_commit_rule_violations "$project_id" "$commit_hash" "$rule" "$count" &
    [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
done <<< $(run_query "
      SELECT SONAR_ISSUES.PROJECT_ID, SONAR_ANALYSIS.REVISION, SONAR_ISSUES.RULE, COUNT(*) AS COUNT
        FROM SONAR_ISSUES
  INNER JOIN SONAR_ANALYSIS
          ON (SONAR_ISSUES.PROJECT_ID            = SONAR_ANALYSIS.PROJECT_ID AND
              SONAR_ISSUES.CREATION_ANALYSIS_KEY = SONAR_ANALYSIS.ANALYSIS_KEY)
       WHERE (SONAR_ISSUES.TYPE  = 'CODE_SMELL'  AND
              (SONAR_ISSUES.RULE =    'common-java' OR
               SONAR_ISSUES.RULE LIKE 'squid:%'))
    GROUP BY SONAR_ISSUES.PROJECT_ID, SONAR_ANALYSIS.REVISION, SONAR_ISSUES.RULE
    ORDER BY SONAR_ISSUES.PROJECT_ID, SONAR_ANALYSIS.REVISION, SONAR_ISSUES.RULE, COUNT;
" )

wait
log "DONE"


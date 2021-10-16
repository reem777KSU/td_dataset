# Technical Debt Dataset Workspace
This repository contains tools and notes for directed research based on
[The Technical Debt Dataset](https://github.com/clowee/The-Technical-Debt-Dataset).

## Overview
- [Prerequisites](#Prerequisites)
- [Set Up Workspace](#set-up-workspace)
- [Auxillary Tables](#auxillary-tables)
    - [`COMMIT_TIME_DIFFS`](#commit_time_diffs)
    - [`AUTHOR_PROJECT_COMMITS`](#author_project_commits)
    - [`AUTHOR_PROJECT_FILE_CHANGES`](#author_project_file_changes)
    - [`AUTHOR_EXPERIENCE`](#author_experience)
- [Generate Auxillary Tables](#generate-auxillary-tables)

## Prerequisites
The following dependencies are needed to run the `setup.bash` script:
### Workspace Setup
- `bash`
- `git`
- `sqlite3`
- `wget`
### Table Generation
- `perl`

Note that all of these dependencies were available out-of-the box on
[WSL](https://docs.microsoft.com/en-us/windows/wsl/install) with Windows 10 at
the time of this writing (10/07/2021).

## Set Up Workspace
Running the `setup.bash` script will produce the following directory structure:
```
.
|-- td_V2.db
+-- ws
    |-- td_V2-initial.db

```
where `td_V2-initial.db` is an original copy of the
[TD Database](https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db),
and `td_V2.db` is a copy of the database containing the
[auxillary tables](#auxillary-tables) imported from
`<repo dir>/generated_tables/<TABLE_NAME>[-<part>_of_<parts>].csv`.

## Auxillary Tables
Generated tables are checked into this workspace as `.csv` files at
`<repo dir>/generated_tables/<TABLE_NAME>[-<part>_of_<parts>].csv`.
### COMMIT_TIME_DIFFS
`COMMIT_TIME_DIFFS` is a denormalization of the tables `SONAR_ISSES`,
`SONAR_ANALYSIS`, and `GIT_COMMITS`.  It agreggates information regarding the
introduction and, if available, resolution of [SonarQube](https://www.sonarqube.org/)
code smells.

Note that nullable columns are `NULL` where their row corresponds a code smell
(`ISSUE_KEY`) that has not been resolved.

Schema:
```
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
    FILE                  TEXT NOT NULL,
    PRIMARY KEY (ISSUE_KEY)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM COMMIT_TIME_DIFFS LIMIT 1;'
ISSUE_KEY|RULE|CREATION_ANALYSIS_KEY|CLOSE_ANALYSIS_KEY|CREATION_DATE|CLOSE_DATE|DAY_DIFF|HOURS_DIFF|CREATION_COMMIT_HASH|CLOSE_COMMIT_HASH|CREATION_AUTHOR|FIX_AUTHOR|PROJECT_ID|FILE
AV0-0YGZt6tne_r58pS_|squid:HiddenFieldCheck|AV0-0TCKt6tne_r58pS9|AWOg5EgxpsrLjol6S0Fr|2012-03-16 14:57:47|2014-11-07 01:33:53|965|23160|6f88da3061babf49953161012006852e44113722|30570912d4f6be8079c869540a7628f94838f7a5|Ashutosh Chauhan|Ashutosh Chauhan|org.apache:hive|service/src/test/org/apache/hadoop/hive/service/TestHiveServerSessions.java 
```
### AUTHOR_PROJECT_COMMITS
Records the total number of `COMMITS` that an `AUTHOR` has contributed to a
project identified by `PROJECT_ID`, as well as their `FIRST_COMMIT_DATE` for
that project.

Note that `AUTHOR` in this table contains the author's email a la `git log`
output.  Email is exluded from the `AUTHOR` column of all other tables except
[`AUTHOR_PROJECT_FILE_CHANGES`](#author_project_file_changes).

Schema:
```
CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
    AUTHOR            TEXT    NOT NULL,
    PROJECT_ID        TEXT    NOT NULL,
    COMMITS           INTEGER NOT NULL,
    FIRST_COMMIT_DATE TEXT    NOT NULL,
    PRIMARY KEY (AUTHOR, PROJECT_ID)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_PROJECT_COMMITS LIMIT 1;'
AUTHOR|PROJECT_ID|COMMITS|FIRST_COMMIT_DATE
Olivier Lamy <olamy@apache.org>|org.apache:archiva|4152|2011-05-10 20:00:55
```
### AUTHOR_PROJECT_FILE_CHANGES
Records the total kinds of changes that an `AUTHOR` has contributed to a (java) `FILE`
within a project identified by `PROJECT_ID`.

Note that `AUTHOR` in this table contains the author's email a la `git log`
output.  Email is exluded from the `AUTHOR` column of all other tables except
[`AUTHOR_PROJECT_COMMITS`](#author_project_commits).

Schema:
```
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
```
 A commit by an `AUTHOR` that involves a source `FILE` contributes `+1` to
`TOTAL_CHANGES`.  `RENAMES` are counted for both the "moved-from" and
"moved-to" `FILE`s.  Note that `RENAMES` and other changes that do not operate
on source code lines such as changes to file permissions, binary file size,
etc... do not contribute to the tallies of `LINE`-specific changes.
`LINE_ADDTIONS` and `LINE_SUBTRACTIONS` account for the total lines added and
subtracted to `FILE`, respectively, and `TOTAL_LINE_CHANGES = LINE_ADDITIONS +
LINE_SUBTRACTIONS`.

Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_PROJECT_FILE_CHANGES LIMIT 1;'
AUTHOR|PROJECT_ID|FILE|TOTAL_CHANGES|RENAMES|LINE_ADDITIONS|LINE_SUBTRACTIONS|TOTAL_LINE_CHANGES
Olivier Lamy <olamy@apache.org>|org.apache:archiva|archiva-modules/archiva-base/archiva-consumers/archiva-consumer-archetype/src/main/resources/archetype-resources/src/test/java/SimpleArtifactConsumerTest.java|4|0|102|12|114
```
### AUTHOR_EXPERIENCE
`AUTHOR_EXPERIENCE` is an expansion of the tables `COMMIT_TIME_DIFFS`, where
every row corresponds to either the introduction (`IS_FIX=0`) or the resolution
(`IS_FIX=1`) of a [SonarQube](https://www.sonarqube.org/) code smell.  The
columns prefixed with `TOTAL_` take into consideration all contributors of the
issue's project, whereas `AUTHOR_`-prefixed columns only consider the
issue-introducing (or closing) author.  `_COMMITS`-suffixed columns exclude the
issue commit, `COMMIT_HASH`, from their counts.  `_COMMITS`-suffixed columns
that have `FILE` in their names only consider the commits to the issue `FILE`,
whereas those that have `PROJECT` in their names consider commits to the entire
project (`PROJECT_ID`).  `_COMMITS`-suffixed columns that have `RECENT` in
their names only take into consideration commits having dates up to 30 days
prior to `COMMIT_DATE`.

Note that nullable columns `<PREFIX>HOURS_SINCE_LAST_TOUCH` are `NULL` where `COMMIT_HASH`
is `FILE`'s first commit.

Schema:
```
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
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_EXPERIENCE LIMIT 1;'
ISSUE_KEY|IS_FIX|AUTHOR|PROJECT_ID|FILE|COMMIT_HASH|COMMIT_DATE|TOTAL_HOURS_SINCE_LAST_TOUCH|TOTAL_FILE_COMMITS|TOTAL_PROJECT_COMMITS|TOTAL_RECENT_FILE_COMMITS|TOTAL_RECENT_PROJECT_COMMITS|AUTHOR_HOURS_SINCE_LAST_TOUCH|AUTHOR_FILE_COMMITS|AUTHOR_PROJECT_COMMITS|AUTHOR_RECENT_FILE_COMMITS|AUTHOR_RECENT_PROJECT_COMMITS|AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT
AV0-0YGZt6tne_r58pS_|0|Ashutosh Chauhan|org.apache:hive|service/src/test/org/apache/hadoop/hive/service/TestHiveServerSessions.java|6f88da3061babf49953161012006852e44113722|2012-03-16 14:57:47|19|0|1568|0|31|19|0|32|0|17|2411 
```

## Generate Auxillary Tables
Running the `mine.bash` script will produce the following directory structure:
```
.
|-- td_V2.db
+-- ws
    |-- projects
    |   |-- <project ID 1>
    |   |-- <project ID 2>
    |   ...
    |   |-- <project ID N>
    |
    |-- td_V2-initial.db

```
where `projects` contains git clones of all of the projects that are included
in
[The Technical Debt Dataset](https://github.com/clowee/The-Technical-Debt-Dataset),
and `td_V2-initial.db` is an original copy of the
[TD Database](https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db),
and `td_V2.db` is a copy of the database that is kept isolated for modifying.

This script will produce the `sqlite3` database `<repo dir>/td_V2.db`
containing the generated tables above.  Note that the current implementation is
time consuming and will eat up as much processing power as available.  For
reference, it took roughly 3 days to complete on my machine (MD Ryzen 7 2700X
Eight-Core Processor CPU, 32GB of DDR4 RAM) which was running just the script
on [WSL](https://docs.microsoft.com/en-us/windows/wsl/install).

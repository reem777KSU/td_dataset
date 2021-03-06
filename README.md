# Technical Debt Dataset Workspace
This repository contains tools and notes for directed research based on version 2.0 of
[The Technical Debt Dataset](https://github.com/clowee/The-Technical-Debt-Dataset).

## Overview
- [Prerequisites](#Prerequisites)
- [Set Up Workspace](#set-up-workspace)
- [Glossary](#glossary)
    - [Author](#author)
    - [SonarQube Code Smells](#sonarqube-code-smells)
    - [Recent Commits](#recent-commits)
    - [Source File](#source-file)
    - [Total](#total)
- [Auxillary Tables](#auxillary-tables)
    - [`COMMIT_TIME_DIFFS`](#commit_time_diffs)
    - [`AUTHOR_PROJECT_COMMITS`](#author_project_commits)
    - [`AUTHOR_PROJECT_SOURCE_FILE_CHANGES`](#author_project_source_file_changes)
    - [`AUTHOR_EXPERIENCE`](#author_experience)
    - [`PROJECT_STATS`](#project_stats)
    - [`PROJECT_COMMIT_STATS`](#project_commit_stats)
    - [`PROJECT_COMMIT_RULE_VIOLATIONS`](#project_commit_rule_violations)
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

## Glossary
The names of many table and column names include labels that classify the data
that they describe.  There are also terms used in this document that have
precise meaning.  Below is a list of such reoccurring labels and terms, along
with their definitions:
### Author
"Author" refers to the author of a git commit (`AUTHOR` field of `GIT_COMMITS`,
as opposed to the person who committed the code on behalf of the original
author (`COMMITTER` field of `GIT_COMMITS`).  Most of the time these are the
same person.
"Author" as a qualifying label targets objects (files, commits,
etc...) that belong to the author of a reference commit.  For instance, a count
of "author" line changes includes just the line changes contributed by a
particular author.
### SonarQube Code Smells
We focus on a subset of the "code smells" identified by SonarQube in [The
technical Debt Dataset](https://arxiv.org/pdf/1907.00376.pdf):

> Table `SONAR_ISSUES` lists all of the SonarQube issues as well as the
> anti-patterns and code smells detected by Ptidej. The value offield *squid*
> of the issues detected by SonarQube starts with either the prefix `squid:` or
> `common-java`

Accordingly, the following `WHERE` condition may be applied to the
`SONAR_ISSUES` table to select just the SonarQube code smells:

```
sqlite> SELECT *
          FROM SONAR_ISSUES
         WHERE TYPE = "CODE_SMELL" AND
               (RULE =    "common-java" OR
                RULE LIKE "squid:%"));
```
### Recent Commits
"Recent" in the context of data collected from a pool of commits limits its
pool to commits that were authored in the interval of 30 days prior to a
reference commit and up until the time of the reference commit.  For instance,
a count of the latest "recent" commits would not include commits from last year.
### Source File
A "source file" is a file with the ".java" extension.  A more complete
definition is a file with a file extension that belongs to the set of all file
extensions for which there is at least one associated SonarQube code smell
violation:
```
sqlite> SELECT DISTINCT(REPLACE(COMPONENT, RTRIM(COMPONENT, REPLACE(COMPONENT, '.', '')), ''))
          FROM SONAR_ISSUES
         WHERE TYPE = 'CODE_SMELL' AND
               (RULE =    'common-java' OR
                RULE LIKE 'squid:%');
java
```
Any time a label has "file" without the "source" qualifier the data associated
with it has been collected from *all* files that have been checked into `git`.
### Total
"Total" is used to distinguish data from those labeled with "author".  Where
"author" filters just the set of objects (files, commits, etc...) that belong
to the author of a reference commit, "total" has no filter.  For instance, a
count of "total" commits contributed to a project includes all commits, whereas
a count of "author" commits would only include those contributed by a
particular author.

## Auxillary Tables
Generated tables are checked into this workspace as `.csv` files at
`<repo dir>/generated_tables/<TABLE_NAME>[-<part>_of_<parts>].csv`.
### COMMIT_TIME_DIFFS
`COMMIT_TIME_DIFFS` is a denormalization of the tables `SONAR_ISSUES`,
`SONAR_ANALYSIS`, and `GIT_COMMITS`.  It agreggates information regarding the
introduction and, if available, resolution of [SonarQube](https://www.sonarqube.org/)
code smells.  There is one `COMMIT_TIME_DIFFS` row for every SonarQube code
smell in `SONAR_ISSUES`:
```
sqlite> SELECT COUNT(*)
          FROM COMMIT_TIME_DIFFS;
732114
sqlite> SELECT COUNT(*)
          FROM (SELECT ISSUE_KEY
                  FROM COMMIT_TIME_DIFFS
                 UNION 
                SELECT ISSUE_KEY
                  FROM SONAR_ISSUES
                 WHERE TYPE = "CODE_SMELL" AND
                       (RULE =    "common-java" OR
                        RULE LIKE "squid:%"));
742241
```
The missing entries in `COMMIT_TIME_DIFFS` can be attributed to an error in the
original database where not all `SONAR_ISSUE`s point to a `SONAR_ANALYSIS`
through `CREATION_ANALYSIS_KEY`:
```
sqlite>    SELECT COUNT(*)
             FROM SONAR_ISSUES
        LEFT JOIN SONAR_ANALYSIS
               ON CREATION_ANALYSIS_KEY = ANALYSIS_KEY
            WHERE ANALYSIS_KEY IS NULL AND
                  TYPE = "CODE_SMELL"  AND
                  (RULE =    "common-java" OR
                   RULE LIKE "squid:%"));
10127
```

Note that nullable columns are `NULL` where their row corresponds a code smell
(`ISSUE_KEY`) that has not been resolved.

Schema:
```
CREATE TABLE IF NOT EXISTS COMMIT_TIME_DIFFS (
    ISSUE_KEY             TEXT NOT NULL,
        -- Foreign key to 'SONAR_ISSUES'.

    RULE                  TEXT NOT NULL,
        -- Kind of SonarQube code smell.

    CREATION_ANALYSIS_KEY TEXT NOT NULL,
    CLOSE_ANALYSIS_KEY    TEXT,
        -- Foreign keys to analyses that detected the creation and close of
        -- this issue, respectively ('SONAR_ANALYSIS','SONAR_MEASURES').
        -- An issue that has not been fixed will have a 'NULL'
        -- 'CLOSE_ANALYSIS_KEY'.

    CREATION_DATE         TEXT NOT NULL,
    CLOSE_DATE            TEXT,
        -- Dates (YYYY-MM-DD HH:MM:SS) that this issue was created and closed,
        -- respectively.  An issue that has not been fixed will have a 'NULL'
        -- 'CLOSE_DATE'.

    DAY_DIFF              INTEGER,
    HOURS_DIFF            INTEGER,
        -- Time elapsed between issue creation and close.  These columns will
        -- be 'NULL' for issues that have not been fixed.

    CREATION_COMMIT_HASH  TEXT NOT NULL,
    CLOSE_COMMIT_HASH     TEXT,
        -- The project commit hash when this issue was created and fixed,
        -- respectively.  An issue that has not been fixed will have a 'NULL'
        -- 'CLOSE_COMMIT_HASH'.

    CREATION_AUTHOR       TEXT NOT NULL,
    FIX_AUTHOR            TEXT,
        -- The names of the authors of the commits that created and fixed this
        -- issue, respectively.  An issue that has not been fixed will have a
        -- 'NULL' 'FIX_AUTHOR'.

    PROJECT_ID            TEXT NOT NULL,
        -- The project where this issue was introduced (and fixed).

    SOURCE_FILE           TEXT NOT NULL,
        -- The source file where this issue was introduced (relative path from
        -- project root).

    PRIMARY KEY (ISSUE_KEY)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM COMMIT_TIME_DIFFS LIMIT 1;'
ISSUE_KEY|RULE|CREATION_ANALYSIS_KEY|CLOSE_ANALYSIS_KEY|CREATION_DATE|CLOSE_DATE|DAY_DIFF|HOURS_DIFF|CREATION_COMMIT_HASH|CLOSE_COMMIT_HASH|CREATION_AUTHOR|FIX_AUTHOR|PROJECT_ID|SOURCE_FILE
AV0-0YGZt6tne_r58pS_|squid:HiddenFieldCheck|AV0-0TCKt6tne_r58pS9|AWOg5EgxpsrLjol6S0Fr|2012-03-16 14:57:47|2014-11-07 01:33:53|965|23160|6f88da3061babf49953161012006852e44113722|30570912d4f6be8079c869540a7628f94838f7a5|Ashutosh Chauhan|Ashutosh Chauhan|org.apache:hive|service/src/test/org/apache/hadoop/hive/service/TestHiveServerSessions.java
```
### AUTHOR_PROJECT_COMMITS
Records the total number of `COMMITS` that an `AUTHOR` has contributed to a
project identified by `PROJECT_ID`, as well as their `FIRST_COMMIT_DATE` for
that project.

Note that `AUTHOR` in this table contains the author's email a la `git log`
output.  Email is exluded from the `AUTHOR` column of all other tables except
[`AUTHOR_PROJECT_SOURCE_FILE_CHANGES`](#author_project_file_changes).

Schema:
```
CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
    AUTHOR              TEXT    NOT NULL,
        -- The commit author.

    PROJECT_ID          TEXT    NOT NULL,
        -- The project.

    COMMITS             INTEGER NOT NULL,
        -- Total number of commits 'AUTHOR' has contributed to this project.

    SOURCE_FILE_COMMITS INTEGER NOT NULL,
        -- Total number of commits 'AUTHOR' has contributed to files which are
        -- targeted by SonarQube code smell rules (java files).

    FIRST_COMMIT_DATE TEXT      NOT NULL,
        -- Date (YYYY-MM-DD HH:MM:SS) of the author's first commit to this
        -- project.

    PRIMARY KEY (AUTHOR, PROJECT_ID)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_PROJECT_COMMITS LIMIT 1;'
AUTHOR|PROJECT_ID|COMMITS|SOURCE_FILE_COMMITS|FIRST_COMMIT_DATE
Olivier Lamy|org.apache:archiva|4152|1689|2011-05-10 20:00:55
```
### AUTHOR_PROJECT_SOURCE_FILE_CHANGES
Records the total kinds of changes that an `AUTHOR` has contributed to a (java)
`SOURCE_FILE` within a project identified by `PROJECT_ID`.

Note that `AUTHOR` in this table contains the author's email a la `git log`
output.  Email is exluded from the `AUTHOR` column of all other tables except
[`AUTHOR_PROJECT_COMMITS`](#author_project_commits).

Schema:
```
CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_SOURCE_FILE_CHANGES (
    AUTHOR             TEXT              NOT NULL,
        -- The commit author.

    PROJECT_ID         TEXT              NOT NULL,
        -- The project.

    SOURCE_FILE        TEXT              NOT NULL,
        -- The source (java) file.

    TOTAL_CHANGES      INTEGER DEFAULT 0 NOT NULL,
        -- Sum of commits by 'AUTHOR' that affected this file (including
        -- 'RENAMES').

    RENAMES            INTEGER DEFAULT 0 NOT NULL,
        -- Number of times 'AUTHOR' has renamed 'SOURCE_FILE' to another file,
        -- or has renamed another file to 'SOURCE_FILE'.

    LINE_ADDITIONS     INTEGER DEFAULT 0 NOT NULL,
        -- Total number of line additions contributed to this file by 'AUTHOR'

    LINE_SUBTRACTIONS  INTEGER DEFAULT 0 NOT NULL,
        -- Total number of line subtractions contributed to this file by
        -- 'AUTHOR'

    TOTAL_LINE_CHANGES INTEGER DEFAULT 0 NOT NULL,
        -- 'LINE_ADDITIONS + LINE_SUBTRACTIONS'

    PRIMARY KEY (AUTHOR, PROJECT_ID, SOURCE_FILE)
);
```
 A commit by an `AUTHOR` that involves a source `SOURCE_FILE` contributes `+1`
to `TOTAL_CHANGES`.  `RENAMES` are counted for both the "moved-from" and
"moved-to" `SOURCE_FILE`s.  Note that `RENAMES` and other changes that do not
operate on source code lines such as changes to file permissions, binary file
size, etc... do not contribute to the tallies of `LINE`-specific changes.
`LINE_ADDTIONS` and `LINE_SUBTRACTIONS` account for the total lines added and
subtracted to `SOURCE_FILE`, respectively, and `TOTAL_LINE_CHANGES =
LINE_ADDITIONS + LINE_SUBTRACTIONS`.

Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_PROJECT_SOURCE_FILE_CHANGES LIMIT 1;'
AUTHOR|PROJECT_ID|SOURCE_FILE|TOTAL_CHANGES|RENAMES|LINE_ADDITIONS|LINE_SUBTRACTIONS|TOTAL_LINE_CHANGES
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
    ISSUE_KEY                                   TEXT    NOT NULL,
        -- Foreign key to 'SONAR_ISSUES'.

    IS_FIX                                      INTEGER NOT NULL,
        -- '0' if this row corresponds to the introduction of the issue,
        -- '1' if it fixes it.

    AUTHOR                                      TEXT    NOT NULL,
        -- The commit author.

    PROJECT_ID                                  TEXT    NOT NULL,
        -- The project.

    SOURCE_FILE                                 TEXT    NOT NULL,
        -- The path to the affected file (relative to project root).

    COMMIT_HASH                                 TEXT    NOT NULL,
        -- The git commit hash where this issue was introduced ('IS_FIX=0')
        -- or fixed ('IS_FIX=1').

    COMMIT_DATE                                 TEXT    NOT NULL,
        -- Date (YYYY-MM-DD HH:MM:SS) of this commit.

    ANALYSIS_KEY                                TEXT    NOT NULL,
        -- Foreign key to analysis that detected the creation ('IS_FIX=0')
        -- or close ('IS_FIX=1') of this issue ('SONAR_ANALYSIS',
        -- 'SONAR_MEASURES').

    SQALE_INDEX                                 INTEGER NOT NULL,
        -- SonarQube measure of project-wide technical debt after
        -- this commit.

    IS_FAULT_INDUCING                           INTEGER NOT NULL,
        -- '1' if this commit introduced at least 1 JIRA_ISSUE, '0'
        -- otherwise.

    IS_FAULT_FIXING                             INTEGER NOT NULL,
        -- '1' if this commit fixed at least 1 JIRA_ISSUE, '0'
        -- otherwise.

    TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        -- Hours since any author has touched this file at the time of this
        -- commit.

    TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,
        -- Hours since the first project commit by any author at the time
        -- of this commit.

    TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author at the time of the commit (exluding this commit).

    TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,
        -- Total commits to this project by any author at the time of the
        -- commit (excluding this commit).

    TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author *within 30 days of* the time of the commit (exluding
        -- this commit).

    TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,
        -- Total commits to this project by any author *within 30 days of*
        -- the time of the commit (excluding this commit).

    AUTHOR_HOURS_SINCE_LAST_TOUCH               INTEGER,
        -- Hours since 'AUTHOR' has touched this file at the time of this
        -- commit.

    AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT     INTEGER NOT NULL,
        -- Hours since the first project commit by 'AUTHOR' at the time
        -- of this commit.

    AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' at the time of the commit (exluding this commit).

    AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,
        -- Total commits to this project by 'AUTHOR' at the time of the
        -- commit (excluding this commit).

    AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' *within 30 days of* the time of the commit (exluding
        -- this commit).

    AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,
        -- Total commits to this project by 'AUTHOR' *within 30 days of*
        -- the time of the commit (excluding this commit).

    NUM_PROJECT_FILES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of files in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_LINES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of lines in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_FILES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) files in the project at the time of
        -- 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_LINES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) lines in the project at the time of
        -- 'COMMIT_HASH'.

    PRIMARY KEY (ISSUE_KEY, IS_FIX)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM AUTHOR_EXPERIENCE LIMIT 1;'
ISSUE_KEY|IS_FIX|AUTHOR|PROJECT_ID|SOURCE_FILE|COMMIT_HASH|COMMIT_DATE|ANALYSIS_KEY|SQALE_INDEX|IS_FAULT_INDUCING|IS_FAULT_FIXING|TOTAL_HOURS_SINCE_LAST_TOUCH|TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT|TOTAL_SOURCE_FILE_COMMITS|TOTAL_SOURCE_FILE_LINE_ADDITIONS|TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_SOURCE_FILE_LINE_CHANGES|TOTAL_PROJECT_COMMITS|TOTAL_RECENT_SOURCE_FILE_COMMITS|TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS|TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES|TOTAL_RECENT_PROJECT_COMMITS|AUTHOR_HOURS_SINCE_LAST_TOUCH|AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT|AUTHOR_SOURCE_FILE_COMMITS|AUTHOR_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_SOURCE_FILE_LINE_CHANGES|AUTHOR_PROJECT_COMMITS|AUTHOR_RECENT_SOURCE_FILE_COMMITS|AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES|AUTHOR_RECENT_PROJECT_COMMITS
AV0-0YGZt6tne_r58pS_|0|Ashutosh Chauhan|org.apache:hive|service/src/test/org/apache/hadoop/hive/service/TestHiveServerSessions.java|6f88da3061babf49953161012006852e44113722|2012-03-16 14:57:47|AV0-0TCKt6tne_r58pS9|223935|0|0|19|30974|0|0|0|0|1568|0|0|0|0|31|19|2411|0|0|0|0|32|0|0|0|0|17
```
### PROJECT_STATS
`PROJECT_STATS` is a collection of some high-level stats concerning the scale
and history of a project.

Schema:
```
CREATE TABLE IF NOT EXISTS PROJECT_STATS (
    PROJECT_ID          TEXT    NOT NULL,
        -- The project.

    FILES               INTEGER NOT NULL,
        -- Total number of files (any kind).

    SOURCE_FILES        INTEGER NOT NULL,
        -- Total number of files that are targeted by SonarQube code smell
        -- rules (java files).

    LINES               INTEGER NOT NULL,
        -- Total number of lines (all files).

    SOURCE_FILE_LINES   INTEGER NOT NULL,
        -- Total number of lines (only 'SOURCE_FILES').

    COMMITS             INTEGER NOT NULL,
        -- Total number of commits to this project.

    SOURCE_FILE_COMMITS INTEGER NOT NULL,
        -- Total number of commits to 'SOURCE_FILES' in this project.

    PRIMARY KEY (PROJECT_ID)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM PROJECT_STATS LIMIT 1;'
PROJECT_ID|FILES|SOURCE_FILES|LINES|SOURCE_FILE_LINES|COMMITS|SOURCE_FILE_COMMITS
org.apache:archiva|3208|3208|421594|189286|8695|4222
### PROJECT_COMMIT_STATS
`PROJECT_COMMIT_STATS` is a collection of stats about a project commit, as well
as stats that describe the state of the project at the time of the commit.

Schema:
```
CREATE TABLE IF NOT EXISTS PROJECT_COMMIT_STATS (
    PROJECT_ID                              TEXT              NOT NULL,
        -- The project.

    COMMIT_HASH                             TEXT              NOT NULL,
        -- The commit.

    COMMIT_DATE                             TEXT    DEFAULT "" NOT NULL,
        -- Date of 'COMMIT_HASH'.

    AUTHOR                                  TEXT    DEFAULT "" NOT NULL,
        -- Author of 'COMMIT_HASH'.

    NUM_FILES                               INTEGER DEFAULT 0  NOT NULL,
        -- Total number of files touched in 'COMMIT_HASH'.

    NUM_DIRECTORIES                         INTEGER DEFAULT 0  NOT NULL,
        -- Number of unique directories containing all files touched in
        -- 'COMMIT_HASH'.

    NUM_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines added in 'COMMIT_HASH'.

    NUM_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines removed in 'COMMIT_HASH'.

    NUM_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        -- 'NUM_LINE_ADDITIONS + NUM_LINE_SUBTRACTIONS'

    NUM_SOURCE_FILES                        INTEGER DEFAULT 0  NOT NULL,
        -- Total number of files touched in 'COMMIT_HASH' that are targeted by
        -- SonarQube code smell rules (java files).

    NUM_SOURCE_DIRECTORIES                  INTEGER DEFAULT 0  NOT NULL,
        -- Number of unique directories containing source (java) files touched
        -- in 'COMMIT_HASH'.

    NUM_SOURCE_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines added to source (java) files in 'COMMIT_HASH'.

    NUM_SOURCE_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines removed from source (java) files in
        -- 'COMMIT_HASH'.

    NUM_SOURCE_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        -- 'NUM_SOURCE_LINE_ADDITIONS + NUM_SOURCE_LINE_SUBTRACTIONS'.

    TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        -- Hours since the commit previous to 'COMMIT_HASH' was authored, or
        -- 'NULL' if 'COMMIT_HASH' is the first commit.

    TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,
        -- Hours since the first project commit at the time of 'COMMIT_HASH'.
        -- This column will be '0' if 'COMMIT_HASH' is the first project commit.

    TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author to source (java) files at the time of 'COMMIT_HASH'
        -- (exluding 'COMMIT_HASH').

    TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_ADDITIONS                INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_SUBTRACTIONS             INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_CHANGES                  INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author at the time of 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author to source (java) files *within 30 days of* the time of
        -- 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_ADDITIONS         INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS      INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_CHANGES           INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author *within 30 days of* the time of 'COMMIT_HASH' (exluding
        -- 'COMMIT_HASH').

    AUTHOR_HOURS_SINCE_LAST_TOUCH                INTEGER,
        -- Hours since the last commit by 'AUTHOR' prior to 'COMMIT_HASH', or
        -- 'NULL' if 'COMMIT_HASH' is the first commit.

    AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,
        -- Hours since the first project commit by 'AUTHOR' at the time of
        -- 'COMMIT_HASH'.  This column will be '0' if 'COMMIT_HASH' is the
        -- first project commit.

    AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' to source (java) files at the time of 'COMMIT_HASH'
        -- (exluding 'COMMIT_HASH').

    AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_ADDITIONS               INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_SUBTRACTIONS            INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_CHANGES                 INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' at the time of 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' to source (java) files *within 30 days of* the time of
        -- 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_ADDITIONS        INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS     INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_CHANGES          INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' *within 30 days of* the time of 'COMMIT_HASH' (exluding
        -- 'COMMIT_HASH').

    NUM_PROJECT_FILES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of files in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_LINES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of lines in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_FILES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) files in the project at the time of
        -- 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_LINES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) lines in the project at the time of
        -- 'COMMIT_HASH'.

    PRIMARY KEY (PROJECT_ID, COMMIT_HASH)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM PROJECT_COMMIT_STATS LIMIT 1;'
PROJECT_ID|COMMIT_HASH|COMMIT_DATE|AUTHOR|NUM_FILES|NUM_DIRECTORIES|NUM_LINE_ADDITIONS|NUM_LINE_SUBTRACTIONS|NUM_LINE_CHANGES|NUM_SOURCE_FILES|NUM_SOURCE_DIRECTORIES|NUM_SOURCE_LINE_ADDITIONS|NUM_SOURCE_LINE_SUBTRACTIONS|NUM_SOURCE_LINE_CHANGES|TOTAL_HOURS_SINCE_LAST_TOUCH|TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT|TOTAL_SOURCE_FILE_COMMITS|TOTAL_SOURCE_FILE_LINE_ADDITIONS|TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_SOURCE_FILE_LINE_CHANGES|TOTAL_PROJECT_COMMITS|TOTAL_PROJECT_LINE_ADDITIONS|TOTAL_PROJECT_LINE_SUBTRACTIONS|TOTAL_PROJECT_LINE_CHANGES|TOTAL_RECENT_SOURCE_FILE_COMMITS|TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS|TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES|TOTAL_RECENT_PROJECT_COMMITS|TOTAL_RECENT_PROJECT_LINE_ADDITIONS|TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS|TOTAL_RECENT_PROJECT_LINE_CHANGES|AUTHOR_HOURS_SINCE_LAST_TOUCH|AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT|AUTHOR_SOURCE_FILE_COMMITS|AUTHOR_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_SOURCE_FILE_LINE_CHANGES|AUTHOR_PROJECT_COMMITS|AUTHOR_PROJECT_LINE_ADDITIONS|AUTHOR_PROJECT_LINE_SUBTRACTIONS|AUTHOR_PROJECT_LINE_CHANGES|AUTHOR_RECENT_SOURCE_FILE_COMMITS|AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES|AUTHOR_RECENT_PROJECT_COMMITS|AUTHOR_RECENT_PROJECT_LINE_ADDITIONS|AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS|AUTHOR_RECENT_PROJECT_LINE_CHANGES
org.apache:archiva|005800c3403199937c105999523a0225bd73a1f1|2006-05-30 06:38:12+00:00|Ernesto S. Tolentino Jr|1|1|1|1|2|0|0|30534|11936|42470|1527|4489|217|30534|11936|42470|257|34759|12854|47613|0|0|0|0|2|88|23|111||-4|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0
```
```
### PROJECT_COMMIT_RULE_VIOLATIONS
`PROJECT_COMMIT_RULE_VIOLATIONS` summarizes the number of SonarQube code smell
violations that were introduced in a commit, by rule.  There is an entry in
`PROJECT_COMMIT_RULE_VIOLATIONS` for every commit in `GIT_COMMITS` where a
`SONAR_ANALYSIS` was executed and a corresponding `SONAR_MEASURES` is available:
```
sqlite> SELECT COUNT(*)
        FROM PROJECT_COMMIT_RULE_VIOLATIONS; 
66711 
sqlite> SELECT COUNT(*)
          FROM (    SELECT PROJECT_ID, COMMIT_HASH
                      FROM PROJECT_COMMIT_RULE_VIOLATIONS
                     UNION
                    SELECT GIT_COMMITS.PROJECT_ID, COMMIT_HASH
                      FROM GIT_COMMITS
                INNER JOIN SONAR_ANALYSIS
                        ON GIT_COMMITS.PROJECT_ID = SONAR_ANALYSIS.PROJECT_ID AND
                           COMMIT_HASH            = REVISION
                INNER JOIN SONAR_MEASURES
                        ON SONAR_ANALYSIS.ANALYSIS_KEY = SONAR_MEASURES.ANALYSIS_KEY);
66711
```

Schema:
```
CREATE TABLE IF NOT EXISTS PROJECT_COMMIT_RULE_VIOLATIONS (
    PROJECT_ID                              TEXT              NOT NULL,
        -- The project.

    COMMIT_HASH                             TEXT              NOT NULL,
        -- The commit.

    COMMIT_DATE                             TEXT    DEFAULT "" NOT NULL,
        -- Date of 'COMMIT_HASH'.

    AUTHOR                                  TEXT    DEFAULT "" NOT NULL,
        -- Author of 'COMMIT_HASH'.

    ANALYSIS_KEY                            TEXT              NOT NULL,
        -- Foreign key to the analysis on 'COMMIT_HASH' ('SONAR_ANALYSIS',
        -- 'SONAR_MEASURES').

    SQALE_INDEX                             INTEGER           NOT NULL,
        -- SonarQube measure of project-wide technical debt after
        -- 'COMMIT_HASH'.

    IS_FAULT_INDUCING                           INTEGER NOT NULL,
        -- '1' if 'COMMIT_HASH' introduced at least 1 JIRA_ISSUE, '0'
        -- otherwise.

    IS_FAULT_FIXING                             INTEGER NOT NULL,
        -- '1' if 'COMMIT_HASH' fixed at least 1 JIRA_ISSUE, '0' otherwise.

    NUM_FILES                               INTEGER DEFAULT 0  NOT NULL,
        -- Total number of files touched in 'COMMIT_HASH'.

    NUM_DIRECTORIES                         INTEGER DEFAULT 0  NOT NULL,
        -- Number of unique directories containing all files touched in
        -- 'COMMIT_HASH'.

    NUM_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines added in 'COMMIT_HASH'.

    NUM_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines removed in 'COMMIT_HASH'.

    NUM_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        -- 'NUM_LINE_ADDITIONS + NUM_LINE_SUBTRACTIONS'

    NUM_SOURCE_FILES                        INTEGER DEFAULT 0  NOT NULL,
        -- Total number of files touched in 'COMMIT_HASH' that are targeted by
        -- sonar qube code smell rules (java files).

    NUM_SOURCE_DIRECTORIES                  INTEGER DEFAULT 0  NOT NULL,
        -- Number of unique directories containing source (java) files touched
        -- in 'COMMIT_HASH'.

    NUM_SOURCE_LINE_ADDITIONS                      INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines added to source (java) files in 'COMMIT_HASH'.

    NUM_SOURCE_LINE_SUBTRACTIONS                   INTEGER DEFAULT 0  NOT NULL,
        -- Total number of lines removed from source (java) files in
        -- 'COMMIT_HASH'.

    NUM_SOURCE_LINE_CHANGES                        INTEGER DEFAULT 0  NOT NULL,
        -- 'NUM_SOURCE_LINE_ADDITIONS + NUM_SOURCE_LINE_SUBTRACTIONS'.

    TOTAL_HOURS_SINCE_LAST_TOUCH                INTEGER,
        -- Hours since the commit previous to 'COMMIT_HASH' was authored, or
        -- 'NULL' if 'COMMIT_HASH' is the first commit.

    TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,
        -- Hours since the first project commit at the time of 'COMMIT_HASH'.
        -- This column will be '0' if 'COMMIT_HASH' is the first project commit.

    TOTAL_SOURCE_FILE_COMMITS                   INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_ADDITIONS            INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS         INTEGER NOT NULL,
    TOTAL_SOURCE_FILE_LINE_CHANGES              INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author to source (java) files at the time of 'COMMIT_HASH'
        -- (exluding 'COMMIT_HASH').

    TOTAL_PROJECT_COMMITS                       INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_ADDITIONS                INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_SUBTRACTIONS             INTEGER NOT NULL,
    TOTAL_PROJECT_LINE_CHANGES                  INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author at the time of 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    TOTAL_RECENT_SOURCE_FILE_COMMITS            INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS     INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS  INTEGER NOT NULL,
    TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES       INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author to source (java) files *within 30 days of* the time of
        -- 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    TOTAL_RECENT_PROJECT_COMMITS                INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_ADDITIONS         INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS      INTEGER NOT NULL,
    TOTAL_RECENT_PROJECT_LINE_CHANGES           INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- any author *within 30 days of* the time of 'COMMIT_HASH' (exluding
        -- 'COMMIT_HASH').

    AUTHOR_HOURS_SINCE_LAST_TOUCH                INTEGER,
        -- Hours since the last commit by 'AUTHOR' prior to 'COMMIT_HASH', or
        -- 'NULL' if 'COMMIT_HASH' is the first commit.

    AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT      INTEGER NOT NULL,
        -- Hours since the first project commit by 'AUTHOR' at the time of
        -- 'COMMIT_HASH'.  This column will be '0' if 'COMMIT_HASH' is the
        -- first project commit.

    AUTHOR_SOURCE_FILE_COMMITS                  INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_ADDITIONS           INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS        INTEGER NOT NULL,
    AUTHOR_SOURCE_FILE_LINE_CHANGES             INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' to source (java) files at the time of 'COMMIT_HASH'
        -- (exluding 'COMMIT_HASH').

    AUTHOR_PROJECT_COMMITS                      INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_ADDITIONS               INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_SUBTRACTIONS            INTEGER NOT NULL,
    AUTHOR_PROJECT_LINE_CHANGES                 INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' at the time of 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    AUTHOR_RECENT_SOURCE_FILE_COMMITS           INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS    INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS INTEGER NOT NULL,
    AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES      INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' to source (java) files *within 30 days of* the time of
        -- 'COMMIT_HASH' (exluding 'COMMIT_HASH').

    AUTHOR_RECENT_PROJECT_COMMITS               INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_ADDITIONS        INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS     INTEGER NOT NULL,
    AUTHOR_RECENT_PROJECT_LINE_CHANGES          INTEGER NOT NULL,
        -- Total number of commits, line additions/subtractions/changes by
        -- 'AUTHOR' *within 30 days of* the time of 'COMMIT_HASH' (exluding
        -- 'COMMIT_HASH').

    NUM_PROJECT_FILES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of files in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_LINES        INTEGER DEFAULT 0 NOT NULL,
        -- Total number of lines in the project at the time of 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_FILES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) files in the project at the time of
        -- 'COMMIT_HASH'.

    NUM_PROJECT_SOURCE_LINES INTEGER DEFAULT 0 NOT NULL,
        -- Total number of source (java) lines in the project at the time of
        -- 'COMMIT_HASH'.

    ---------------------------------------------------------------------
    -- The following columns count the number of sonar qube violations --
    -- introduced in this commit by rule (column name).                --
    ---------------------------------------------------------------------

    `squid:AssignmentInSubExpressionCheck`  INTEGER DEFAULT 0 NOT NULL,
    `squid:ClassCyclomaticComplexity`       INTEGER DEFAULT 0 NOT NULL,
    `squid:CommentedOutCodeLine`            INTEGER DEFAULT 0 NOT NULL,
    `squid:EmptyStatementUsageCheck`        INTEGER DEFAULT 0 NOT NULL,
    `squid:ForLoopCounterChangedCheck`      INTEGER DEFAULT 0 NOT NULL,
    `squid:HiddenFieldCheck`                INTEGER DEFAULT 0 NOT NULL,
    `squid:LabelsShouldNotBeUsedCheck`      INTEGER DEFAULT 0 NOT NULL,
    `squid:MethodCyclomaticComplexity`      INTEGER DEFAULT 0 NOT NULL,
    `squid:MissingDeprecatedCheck`          INTEGER DEFAULT 0 NOT NULL,
    `squid:ModifiersOrderCheck`             INTEGER DEFAULT 0 NOT NULL,
    `squid:RedundantThrowsDeclarationCheck` INTEGER DEFAULT 0 NOT NULL,
    `squid:RightCurlyBraceStartLineCheck`   INTEGER DEFAULT 0 NOT NULL,
    `squid:S00100`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00101`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00105`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00107`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00108`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00112`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00114`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00115`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00116`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00117`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00119`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00120`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S00122`                          INTEGER DEFAULT 0 NOT NULL,
    `squid:S106`                            INTEGER DEFAULT 0 NOT NULL,
    `squid:S1065`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1066`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1067`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1068`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1118`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1125`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1126`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1132`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1133`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1134`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1135`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1141`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1147`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1149`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1150`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1151`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1153`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1155`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1157`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1158`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1160`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1161`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1163`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1165`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1166`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1168`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1170`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1171`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1172`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1174`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1181`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1185`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1186`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1188`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1190`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1191`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1192`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1193`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1194`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1195`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1197`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1199`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1213`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1214`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1215`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1219`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1220`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1223`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1226`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S128`                            INTEGER DEFAULT 0 NOT NULL,
    `squid:S1301`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1312`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1314`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1319`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S134`                            INTEGER DEFAULT 0 NOT NULL,
    `squid:S135`                            INTEGER DEFAULT 0 NOT NULL,
    `squid:S1452`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1479`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1481`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1488`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1596`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1598`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1700`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1905`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S1994`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2065`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2094`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2130`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2131`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2133`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2160`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2165`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2166`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2176`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2178`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2232`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2235`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2250`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2274`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2326`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2388`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2437`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2438`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2440`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2442`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S2447`                           INTEGER DEFAULT 0 NOT NULL,
    `squid:S888`                            INTEGER DEFAULT 0 NOT NULL,
    `squid:SwitchLastCaseIsDefaultCheck`    INTEGER DEFAULT 0 NOT NULL,
    `squid:UnusedPrivateMethod`             INTEGER DEFAULT 0 NOT NULL,
    `squid:UselessImportCheck`              INTEGER DEFAULT 0 NOT NULL,
    `squid:UselessParenthesesCheck`         INTEGER DEFAULT 0 NOT NULL,

    PRIMARY KEY (PROJECT_ID, COMMIT_HASH)
);
```
Sample row:
```
$ sqlite3 -header td_V2.db 'SELECT * FROM PROJECT_COMMIT_RULE_VIOLATIONS LIMIT 1;'
PROJECT_ID|COMMIT_HASH|COMMIT_DATE|AUTHOR|ANALYSIS_KEY|SQALE_INDEX|IS_FAULT_INDUCING|IS_FAULT_FIXING|NUM_FILES|NUM_DIRECTORIES|NUM_LINE_ADDITIONS|NUM_LINE_SUBTRACTIONS|NUM_LINE_CHANGES|NUM_SOURCE_FILES|NUM_SOURCE_DIRECTORIES|NUM_SOURCE_LINE_ADDITIONS|NUM_SOURCE_LINE_SUBTRACTIONS|NUM_SOURCE_LINE_CHANGES|TOTAL_HOURS_SINCE_LAST_TOUCH|TOTAL_HOURS_SINCE_FIRST_PROJECT_COMMIT|TOTAL_SOURCE_FILE_COMMITS|TOTAL_SOURCE_FILE_LINE_ADDITIONS|TOTAL_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_SOURCE_FILE_LINE_CHANGES|TOTAL_PROJECT_COMMITS|TOTAL_PROJECT_LINE_ADDITIONS|TOTAL_PROJECT_LINE_SUBTRACTIONS|TOTAL_PROJECT_LINE_CHANGES|TOTAL_RECENT_SOURCE_FILE_COMMITS|TOTAL_RECENT_SOURCE_FILE_LINE_ADDITIONS|TOTAL_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|TOTAL_RECENT_SOURCE_FILE_LINE_CHANGES|TOTAL_RECENT_PROJECT_COMMITS|TOTAL_RECENT_PROJECT_LINE_ADDITIONS|TOTAL_RECENT_PROJECT_LINE_SUBTRACTIONS|TOTAL_RECENT_PROJECT_LINE_CHANGES|AUTHOR_HOURS_SINCE_LAST_TOUCH|AUTHOR_HOURS_SINCE_FIRST_PROJECT_COMMIT|AUTHOR_SOURCE_FILE_COMMITS|AUTHOR_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_SOURCE_FILE_LINE_CHANGES|AUTHOR_PROJECT_COMMITS|AUTHOR_PROJECT_LINE_ADDITIONS|AUTHOR_PROJECT_LINE_SUBTRACTIONS|AUTHOR_PROJECT_LINE_CHANGES|AUTHOR_RECENT_SOURCE_FILE_COMMITS|AUTHOR_RECENT_SOURCE_FILE_LINE_ADDITIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_SUBTRACTIONS|AUTHOR_RECENT_SOURCE_FILE_LINE_CHANGES|AUTHOR_RECENT_PROJECT_COMMITS|AUTHOR_RECENT_PROJECT_LINE_ADDITIONS|AUTHOR_RECENT_PROJECT_LINE_SUBTRACTIONS|AUTHOR_RECENT_PROJECT_LINE_CHANGES|squid:AssignmentInSubExpressionCheck|squid:ClassCyclomaticComplexity|squid:CommentedOutCodeLine|squid:EmptyStatementUsageCheck|squid:ForLoopCounterChangedCheck|squid:HiddenFieldCheck|squid:LabelsShouldNotBeUsedCheck|squid:MethodCyclomaticComplexity|squid:MissingDeprecatedCheck|squid:ModifiersOrderCheck|squid:RedundantThrowsDeclarationCheck|squid:RightCurlyBraceStartLineCheck|squid:S00100|squid:S00101|squid:S00105|squid:S00107|squid:S00108|squid:S00112|squid:S00114|squid:S00115|squid:S00116|squid:S00117|squid:S00119|squid:S00120|squid:S00122|squid:S106|squid:S1065|squid:S1066|squid:S1067|squid:S1068|squid:S1118|squid:S1125|squid:S1126|squid:S1132|squid:S1133|squid:S1134|squid:S1135|squid:S1141|squid:S1147|squid:S1149|squid:S1150|squid:S1151|squid:S1153|squid:S1155|squid:S1157|squid:S1158|squid:S1160|squid:S1161|squid:S1163|squid:S1165|squid:S1166|squid:S1168|squid:S1170|squid:S1171|squid:S1172|squid:S1174|squid:S1181|squid:S1185|squid:S1186|squid:S1188|squid:S1190|squid:S1191|squid:S1192|squid:S1193|squid:S1194|squid:S1195|squid:S1197|squid:S1199|squid:S1213|squid:S1214|squid:S1215|squid:S1219|squid:S1220|squid:S1223|squid:S1226|squid:S128|squid:S1301|squid:S1312|squid:S1314|squid:S1319|squid:S134|squid:S135|squid:S1452|squid:S1479|squid:S1481|squid:S1488|squid:S1596|squid:S1598|squid:S1700|squid:S1905|squid:S1994|squid:S2065|squid:S2094|squid:S2130|squid:S2131|squid:S2133|squid:S2160|squid:S2165|squid:S2166|squid:S2176|squid:S2178|squid:S2232|squid:S2235|squid:S2250|squid:S2274|squid:S2326|squid:S2388|squid:S2437|squid:S2438|squid:S2440|squid:S2442|squid:S2447|squid:S888|squid:SwitchLastCaseIsDefaultCheck|squid:UnusedPrivateMethod|squid:UselessImportCheck|squid:UselessParenthesesCheck
org.apache:cayenne|b9988a83e364b9b470873dff8996dcf401d08dc4|2008-07-07 14:52:05+00:00|Andrus Adamchik|AWedEXD3C4KKKThcCqHV|223271|0|0|1|1|1|0|1|0|0|338446|37990|376436|2|12790|1023|338446|37990|376436|1269|419002|50447|469449|26|3040|749|3789|30|3334|754|4088|2|12790|834|321460|31890|353350|1038|398667|44220|442887|18|729|158|887|21|1019|162|1181|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0
```

## Generate Auxillary Tables
Running the `mine.bash` script, followed by the `patch<STEP>.bash` scripts (in
`STEP` order), will produce the following directory structure:
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

# Technical Debt Dataset Workspace
This repository contains tools and notes for directed research based on
[The Technical Debt Dataset](https://github.com/clowee/The-Technical-Debt-Dataset).

## Overview
- [Prerequisites](#table-generation)
- [Set Up Workspace](#set-up-workspace)
- [Auxillary Tables](#auxillary-tables)

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
+-- ws
    |-- projects
    |   |-- <project ID 1>
    |   |-- <project ID 2>
    |   ...
    |   |-- <project ID N>
    |
    |-- td_V2-initial.db
    |-- td_V2-modified.db

```
where `projects` contains git clones of all of the projects that are included in
[The Technical Debt Dataset](https://github.com/clowee/The-Technical-Debt-Dataset),
and `td_V2-initial.db` is an original copy of the
[TD Database](https://github.com/clowee/The-Technical-Debt-Dataset/releases/download/2.0/td_V2.db),
and `td_V2-modified.db` is a copy of the database that is kept isolated for modifying.
If you'd like to [generate auxillary tables](#generate-auxillary-tables), any
changes will be applied to `td_V2-modified.db`.

## Auxillary Tables
Generated tables are checked into this workspace as `.csv` files at
`<repo dir>/generated_tables/<TABLE_NAME>.csv`.
### AUTHOR_PROJECT_COMMITS
Records the total number of `COMMITS` that an `AUTHOR` has contributed to a
project identified by `PROJECT_ID`.

Schema:
```
CREATE TABLE IF NOT EXISTS AUTHOR_PROJECT_COMMITS (
    AUTHOR     TEXT    NOT NULL,
    PROJECT_ID TEXT    NOT NULL,
    COMMITS    INTEGER NOT NULL,
    PRIMARY KEY (AUTHOR, PROJECT_ID)
);
```
Sample row:
```
$ sqlite3 -header ws/td_V2-modified.db 'SELECT * FROM AUTHOR_PROJECT_COMMITS LIMIT 1;'
AUTHOR|PROJECT_ID|COMMITS
Olivier Lamy <olamy@apache.org>|org.apache:archiva|4152
```
### AUTHOR_PROJECT_FILE_CHANGES
Records the total kinds of changes that an `AUTHOR` has contributed to a (java) `FILE`
within a project identified by `PROJECT_ID`.

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
$ sqlite3 -header ws/td_V2-modified.db 'SELECT * FROM AUTHOR_PROJECT_FILE_CHANGES LIMIT 1;'
AUTHOR|PROJECT_ID|FILE|TOTAL_CHANGES|RENAMES|LINE_ADDITIONS|LINE_SUBTRACTIONS|TOTAL_LINE_CHANGES
Olivier Lamy <olamy@apache.org>|org.apache:archiva|archiva-modules/archiva-base/archiva-consumers/archiva-consumer-archetype/src/main/resources/archetype-resources/src/test/java/SimpleArtifactConsumerTest.java|4|0|102|12|114 
```
### Generate Auxillary Tables
Uncomment the section at the end of the `setup.bash` script and run it.  This
will produce the `sqlite3` database `<repo dir>/ws/td_V2-modified.db`
containing the generated tables above.  Note that the current implementation
may take some time (hours) to complete.

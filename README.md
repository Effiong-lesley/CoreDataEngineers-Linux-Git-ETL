# CoreDataEngineers — Linux & Git Project (Bash ETL Pipeline)

**Author:** Lesley Effiong Akpan
**Role:** Data Engineer, CoreDataEngineers
**Stack:** Linux, Bash, cron, Git

A Bash script that runs a simple ETL pipeline, scheduled to run automatically
every day at midnight using cron, plus a small standalone Bash script that
moves all CSV and JSON files from one folder into another. All work is
versioned with Git.

---

## 1. Project Overview

This project implements a simple Extract → Transform → Load (ETL) workflow
entirely in a single Bash script — `etl.sh`.

| Stage     | What happens |
|-----------|--------------|
| Extract   | Downloads a CSV file from a URL (stored in `.env`) and saves it to `raw/` |
| Transform | Renames the `Variable_code` column to `variable_code`, then keeps only `year`, `Value`, `Units`, `variable_code`, saving the result to `transformed/2023_year_finance.csv` |
| Load      | Copies the transformed file into `Gold/` |

Every stage prints a timestamped status message to the terminal (and to
`cron.log` when run via cron) confirming success or failure, so the pipeline
is easy to audit.

## 2. Folder Structure

```
.
├── Gold/
│   └── 2023_year_finance.csv         # Final, load-ready output
├── raw/
│   ├── annual-enterprise-survey-2023-financial-year-provisional.csv  # Raw downloaded file
│   └── data.csv                      # Sample CSV (used for the move_files.sh demo)
├── transformed/
│   └── 2023_year_finance.csv         # Cleaned/selected columns
├── .env                              # Environment variables (NOT committed to git)
├── .gitignore                        # Excludes .env, cron.log, json_and_CSV/
├── cron.log                          # Output log from scheduled cron runs (NOT committed)
├── etl.sh                            # Main Bash ETL script
├── move_files.sh                     # Moves all CSV and JSON files into json_and_CSV/
└── README.md                         # This file
```

## 3. Prerequisites

- Linux / WSL
- `curl` (for downloading the file)
- `awk` (standard on every Linux distribution)
- `cron` (for scheduling — installed by default on most Linux distros)

```bash
# Make the scripts executable after cloning
chmod +x etl.sh move_files.sh
```

## 4. Environment Variables (.env)

The download URL is stored in a `.env` file in the project root, which
`etl.sh` loads with `source .env`.

Create a `.env` file (**this file is git-ignored and should never be
committed**) with the following content:

```
csv_url="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
```

If `.env` is missing — or exists but does not define `csv_url` — the script
stops immediately with a clear error message telling you what to create.

## 5. The ETL Script (`etl.sh`)

### 5.1 Script Safety & Setup

- `set -euo pipefail` — the script exits immediately if any command fails,
  treats unset variables as errors, and fails a pipeline if any stage of it
  fails. This prevents it from silently continuing with bad/missing data.
- `cd "$(dirname "${BASH_SOURCE[0]}")"` — moves into the directory where the
  script itself lives, so it can be run from anywhere (including cron) and
  still find `.env`, `raw/`, `transformed/`, and `Gold/` correctly.
- `source .env` — loads `csv_url` from `.env` into the current shell session.

### 5.2 Extract

Downloads the CSV from `csv_url` and saves it into the `raw/` folder, then
confirms the file exists and is non-empty:

```
File Saved Successfully to raw/ (with file size and row count)
```

### 5.3 Transform

- Renames the column `Variable_code` to **`variable_code`**.
- Selects only the columns **`year, Value, Units, variable_code`** (in that order).
- Writes the result to **`transformed/2023_year_finance.csv`** and confirms it.

> Implementation note: the source CSV contains quoted fields with embedded
> commas (e.g. `"728,225"` in the `Value` column). A naive comma split would
> corrupt those rows, so the script uses a small quote-aware CSV parser
> written in `awk`, and re-quotes values containing commas in the output.

### 5.4 Load

Copies `2023_year_finance.csv` into the **`Gold/`** folder and confirms the
file is present there.

### 5.5 Running the Script Manually

```
[2026-09-07 04:00:32] ============================================================
[2026-09-07 04:00:32]  CoreDataEngineers ETL pipeline started
[2026-09-07 04:00:32]  Working directory: /path/to/project
[2026-09-07 04:00:32] ============================================================
[2026-09-07 04:00:32] STEP 1/3 [EXTRACT] Creating raw folder (if it does not exist)...
[2026-09-07 04:00:32] STEP 1/3 [EXTRACT] Downloading CSV from: https://www.stats.govt.nz/...
[2026-09-07 04:00:32] STEP 1/3 [EXTRACT] SUCCESS: File confirmed in raw folder -> .../raw/annual-enterprise-survey-2023-financial-year-provisional.csv
[2026-09-07 04:00:32] STEP 1/3 [EXTRACT] File size: 7.7M, rows: 50986
[2026-09-07 04:00:32] STEP 2/3 [TRANSFORM] Creating transformed folder (if it does not exist)...
[2026-09-07 04:00:34] STEP 2/3 [TRANSFORM] SUCCESS: File confirmed in transformed folder -> .../transformed/2023_year_finance.csv
[2026-09-07 04:00:34] STEP 2/3 [TRANSFORM] Header is now: year,Value,Units,variable_code
[2026-09-07 04:00:34] STEP 3/3 [LOAD] Loading 2023_year_finance.csv into the Gold folder...
[2026-09-07 04:00:35] STEP 3/3 [LOAD] SUCCESS: File confirmed in Gold folder -> .../Gold/2023_year_finance.csv
[2026-09-07 04:00:35]  ETL pipeline COMPLETED successfully (raw -> transformed -> Gold)
```

Transformed output preview:

```
year,Value,Units,variable_code
2023,930995,Dollars (millions),H01
2023,884244,Dollars (millions),H01
...
```

## 6. Scheduling with Cron

### 6.1 Crontab Syntax

```
* * * * * command-to-run
│ │ │ │ │
│ │ │ │ └── day of week (0–7, Sunday = 0 or 7)
│ │ │ └──── month (1–12)
│ │ └────── day of month (1–31)
│ └──────── hour (0–23)
└────────── minute (0–59)
```

### 6.2 The Schedule (daily at 12:00 AM)

```
0 0 * * * /absolute/path/to/etl.sh >> /absolute/path/to/cron.log 2>&1
```

- `0 0 * * *` → minute 0, hour 0, every day → runs once a day at 12:00 AM (midnight).
- `>> cron.log` → appends all standard output to `cron.log` instead of discarding it.
- `2>&1` → redirects standard error into the same stream, so errors are captured too.

### 6.3 How to Set It Up

```bash
crontab -e
# add the line from 6.2 (with the correct absolute path for your machine),
# save, and exit
```

Or append it non-interactively:

```bash
( crontab -l 2>/dev/null; echo "0 0 * * * $(pwd)/etl.sh >> $(pwd)/cron.log 2>&1" ) | crontab -
```

Verify with `crontab -l`. After midnight, check the run with `cat cron.log`.

## 7. File-Moving Script (`move_files.sh`)

A small standalone Bash script that moves all `.csv` and `.json` files from
one folder into a folder named **`json_and_CSV`**. It works with one or many
matching files, confirms every move, and warns when there is nothing to move:

```bash
./move_files.sh ./raw
```

```
[2026-09-07 04:05:12] Source folder      : ./raw
[2026-09-07 04:05:12] Destination folder : ./json_and_CSV
[2026-09-07 04:05:12] Found 2 file(s) to move:
[2026-09-07 04:05:12]   MOVED   : data.csv -> ./json_and_CSV/data.csv
[2026-09-07 04:05:12]   MOVED   : sample.json -> ./json_and_CSV/sample.json
[2026-09-07 04:05:12] Done. 2 of 2 file(s) moved into './json_and_CSV'.
```

An optional second argument places `json_and_CSV` in a different parent
folder: `./move_files.sh ./raw ./archive`.

## 8. .gitignore

```
.env
cron.log
json_and_CSV/
```

This keeps the environment file (the download URL) and run logs out of
version control, so the repository only tracks code, documentation, and the
pipeline output data.

## 9. Version Control (Git)

```bash
git init
git add .
git commit -m "Implemented the simple etl in bash script"
git branch -M main
git remote add origin https://github.com/Effiong-lesley/CoreDataEngineers-Linux-Git-ETL.git
git push -u origin main
```

Note: `.env` is excluded by `.gitignore` — after cloning, create it as
described in section 4 before running `./etl.sh`.

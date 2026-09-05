# CoreDataEngineers — Linux & Git Project (Bash ETL Pipeline)

**Author:** Lesley Effiong Akpan
**Role:** Data Engineer, CoreDataEngineers
**Stack:** Linux, Bash, cron, Git

This repository contains my submission for the Linux and Git project: a pure-Bash
ETL pipeline (Extract → Transform → Load) with a daily cron schedule, plus a
utility script that moves CSV/JSON files between folders. All work is versioned
with Git.

---

## Project Structure

```
.
├── README.md
├── .gitignore
├── etl.sh                                     # Extract -> Transform -> Load pipeline
├── move_files.sh                              # Moves all CSV/JSON files into json_and_CSV/
├── raw/                                       # EXTRACT output
│   ├── annual-enterprise-survey-2023-financial-year-provisional.csv
│   └── data.csv                               # sample CSV used for the move_files.sh demo
├── transformed/                               # TRANSFORM output
│   └── 2023_year_finance.csv
└── Gold/                                      # LOAD output
    └── 2023_year_finance.csv
```

## Prerequisites

Any Linux environment with the standard utilities `bash`, `curl`, and `awk`
(present by default on virtually every Linux distribution).

```bash
# Make the scripts executable after cloning
chmod +x etl.sh move_files.sh
```

---

## Task 1 — The ETL Script (`etl.sh`)

### Extract
Downloads the Annual Enterprise Survey CSV from Stats NZ and saves it into a
folder called `raw`. The script then **confirms the file exists and is
non-empty** in `raw/` before continuing.

The URL is supplied through an **environment variable** (`CSV_URL`), as
required — the script reads the variable and falls back to the default source
only if the variable is not set:

```bash
export CSV_URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
./etl.sh
```

### Transform
- Renames the column `Variable_code` to **`variable_code`**.
- Selects only the columns **`year, Value, Units, variable_code`** (in that order).
- Writes the result to **`transformed/2023_year_finance.csv`** and confirms it.

> Implementation note: the source CSV contains quoted fields with embedded
> commas (e.g. `"728,225"` in the `Value` column). A naive comma split would
> corrupt those rows, so the script uses a small quote-aware CSV parser written
> in `awk`, and re-quotes values containing commas in the output.

### Load
Copies `2023_year_finance.csv` into the **`Gold/`** directory and confirms the
file is present there.

### Example run

```
[2026-09-05 21:21:08] ============================================================
[2026-09-05 21:21:08]  CoreDataEngineers ETL pipeline started
[2026-09-05 21:21:08] ============================================================
[2026-09-05 21:21:08] STEP 1/3 [EXTRACT] Creating raw folder (if it does not exist)...
[2026-09-05 21:21:08] STEP 1/3 [EXTRACT] Downloading CSV from: https://www.stats.govt.nz/...
[2026-09-05 21:21:08] STEP 1/3 [EXTRACT] SUCCESS: File confirmed in raw folder -> .../raw/annual-enterprise-survey-2023-financial-year-provisional.csv
[2026-09-05 21:21:08] STEP 1/3 [EXTRACT] File size: 7.7M, rows: 50986
[2026-09-05 21:21:08] STEP 2/3 [TRANSFORM] Creating transformed folder (if it does not exist)...
[2026-09-05 21:21:10] STEP 2/3 [TRANSFORM] SUCCESS: File confirmed in transformed folder -> .../transformed/2023_year_finance.csv
[2026-09-05 21:21:10] STEP 2/3 [TRANSFORM] Header is now: year,Value,Units,variable_code
[2026-09-05 21:21:10] STEP 3/3 [LOAD] Loading 2023_year_finance.csv into the Gold folder...
[2026-09-05 21:21:10] STEP 3/3 [LOAD] SUCCESS: File confirmed in Gold folder -> .../Gold/2023_year_finance.csv
[2026-09-05 21:21:10]  ETL pipeline COMPLETED successfully (raw -> transformed -> Gold)
```

Transformed output preview:

```
year,Value,Units,variable_code
2023,930995,Dollars (millions),H01
2023,884244,Dollars (millions),H01
...
```

---

## Task 2 — Scheduling with cron (daily at 12:00 AM)

cron is Linux's built-in job scheduler. A crontab line has five time fields
followed by the command:

```
┌───────────── minute (0-59)
│ ┌─────────── hour (0-23)
│ │ ┌───────── day of month (1-31)
│ │ │ ┌─────── month (1-12)
│ │ │ │ ┌───── day of week (0-7, Sunday = 0 or 7)
│ │ │ │ │
0 0 * * *  /path/to/etl.sh >> /path/to/logs/etl.log 2>&1
```

`0 0 * * *` means **run at 00:00 (12:00 AM) every day**. Output is appended to
`logs/etl.log` so every run leaves an audit trail.

To install the schedule:

```bash
crontab -e
# add this line, then save:
0 0 * * * /absolute/path/to/etl.sh >> /absolute/path/to/logs/etl.log 2>&1
```

Or append it non-interactively:

```bash
( crontab -l 2>/dev/null; echo "0 0 * * * $(pwd)/etl.sh >> $(pwd)/logs/etl.log 2>&1" ) | crontab -
```

Verify with `crontab -l`. Use `crontab -r` to remove all jobs.

---

## Task 3 — Moving CSV & JSON files (`move_files.sh`)

Moves **one or more** `.csv` and `.json` files from any source folder into a
folder named **`json_and_CSV`**, confirming every move:

```bash
./move_files.sh ./raw
```

```
[2026-09-05 21:21:19] Source folder      : ./raw
[2026-09-05 21:21:19] Destination folder : ./json_and_CSV
[2026-09-05 21:21:19] Found 2 file(s) to move:
[2026-09-05 21:21:19]   MOVED   : data.csv -> ./json_and_CSV/data.csv
[2026-09-05 21:21:19]   MOVED   : sample.json -> ./json_and_CSV/sample.json
[2026-09-05 21:21:19] Done. 2 of 2 file(s) moved into './json_and_CSV'.
```

The script handles the "no matching files" case gracefully (`nullglob`) and
accepts an optional second argument to place `json_and_CSV` somewhere else.

---

## Version Control (Git)

All work is versioned with Git:

```bash
git init
git add .
git commit -m "Implemented the simple etl in bash script"
git branch -M main
git remote add origin https://github.com/Effiong-lesley/CoreDataEngineers-Linux-Git-ETL.git
git push -u origin main
```

The pipeline outputs (`raw/`, `transformed/`, `Gold/`) are committed so the
results can be reviewed without re-running the pipeline; only cron logs and the
`json_and_CSV/` demo output are excluded via `.gitignore`.

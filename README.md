# CoreDataEngineers - Linux & Git Project (Bash ETL Pipeline)

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
├── Scripts/
│   └── bash/
│       ├── etl.sh              # Extract -> Transform -> Load pipeline
│       ├── move_csv_json.sh    # Moves all CSV/JSON files into json_and_CSV/
│       └── install_cron.sh     # Registers etl.sh as a daily 12:00 AM cron job
├── sample_data/                # Demo files for testing move_csv_json.sh
│   ├── customers.csv
│   └── products.json
├── raw/                        # created by etl.sh (Extract)      - git-ignored
├── Transformed/                # created by etl.sh (Transform)    - git-ignored
├── Gold/                       # created by etl.sh (Load)         - git-ignored
└── logs/                       # cron execution logs              - git-ignored
```

## Prerequisites

Any Linux environment with the standard utilities `bash`, `curl`, and `awk`
(present by default on virtually every Linux distribution).

```bash
# Make the scripts executable after cloning
chmod +x Scripts/bash/*.sh
```

---

## Task 1 - The ETL Script (`Scripts/bash/etl.sh`)

### Extract
Downloads the Annual Enterprise Survey CSV from Stats NZ and saves it into a
folder called `raw`. The script then **confirms the file exists and is
non-empty** in `raw/` before continuing.

The URL is supplied through an **environment variable** (`CSV_URL`), as
required — the script reads the variable and falls back to a default only if
the variable is not set:

```bash
export CSV_URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
./Scripts/bash/etl.sh
```

### Transform
- Renames the column `Variable_code` to **`variable_code`**.
- Selects only the columns **`year, Value, Units, variable_code`** (in that order).
- Writes the result to **`Transformed/2023_year_finance.csv`** and confirms it.

> Implementation note: the source CSV contains quoted fields with embedded
> commas (e.g. `"728,225"` in the `Value` column). A naive comma split would
> corrupt those rows, so the script uses a small quote-aware CSV parser written
> in `awk`, and re-quotes values containing commas in the output.

### Load
Copies `2023_year_finance.csv` into the **`Gold/`** directory and confirms the
file is present there.

### Example run

```
[2026-09-05 16:10:01] ============================================================
[2026-09-05 16:10:01]  CoreDataEngineers ETL pipeline started
[2026-09-05 16:10:01] ============================================================
[2026-09-05 16:10:01] STEP 1/3 [EXTRACT] Creating raw folder (if it does not exist)...
[2026-09-05 16:10:01] STEP 1/3 [EXTRACT] Downloading CSV from: https://www.stats.govt.nz/...
[2026-09-05 16:10:18] STEP 1/3 [EXTRACT] SUCCESS: File confirmed in raw folder -> .../raw/annual_enterprise_survey_2023.csv
[2026-09-05 16:10:18] STEP 1/3 [EXTRACT] File size: 7.7M, rows: 50986
[2026-09-05 16:10:18] STEP 2/3 [TRANSFORM] Selecting columns [year, Value, Units, variable_code]...
[2026-09-05 16:10:25] STEP 2/3 [TRANSFORM] SUCCESS: File confirmed in Transformed folder -> .../Transformed/2023_year_finance.csv
[2026-09-05 16:10:25] STEP 2/3 [TRANSFORM] Header is now: year,Value,Units,variable_code
[2026-09-05 16:10:25] STEP 3/3 [LOAD] Loading 2023_year_finance.csv into the Gold folder...
[2026-09-05 16:10:25] STEP 3/3 [LOAD] SUCCESS: File confirmed in Gold folder -> .../Gold/2023_year_finance.csv
[2026-09-05 16:10:25]  ETL pipeline COMPLETED successfully (raw -> Transformed -> Gold)
```

Transformed output preview:

```
year,Value,Units,variable_code
2023,930995,Dollars (millions),H01
2023,884244,Dollars (millions),H01
...
```

---

## Task 2 - Scheduling with cron (daily at 12:00 AM)

cron is Linux's built-in job scheduler. A crontab line has five time fields
followed by the command:

```
┌───────────── minute (0-59)
│ ┌─────────── hour (0-23)
│ │ ┌───────── day of month (1-31)
│ │ │ ┌─────── month (1-12)
│ │ │ │ ┌───── day of week (0-7, Sunday = 0 or 7)
│ │ │ │ │
0 0 * * *  /path/to/Scripts/bash/etl.sh >> /path/to/logs/etl.log 2>&1
```

`0 0 * * *` means **run at 00:00 (12:00 AM) every day**. Output is appended to
`logs/etl.log` so every run leaves an audit trail.

**Option A — automatic (recommended):** run the helper script, which adds the
job (without creating duplicates) and prints the resulting crontab:

```bash
./Scripts/bash/install_cron.sh
```

**Option B - manual:**

```bash
crontab -e
# add this line, then save:
0 0 * * * /absolute/path/to/Scripts/bash/etl.sh >> /absolute/path/to/logs/etl.log 2>&1
```

Verify with `crontab -l`. Use `crontab -r` to remove all jobs.

---

## Task 3 - Moving CSV & JSON files (`Scripts/bash/move_csv_json.sh`)

Moves **one or more** `.csv` and `.json` files from any source folder into a
folder named **`json_and_CSV`**, confirming every move:

```bash
./Scripts/bash/move_csv_json.sh ./sample_data
```

```
[2026-09-05 16:15:02] Source folder      : ./sample_data
[2026-09-05 16:15:02] Destination folder : ./json_and_CSV
[2026-09-05 16:15:02] Found 2 file(s) to move:
[2026-09-05 16:15:02]   MOVED   : customers.csv -> ./json_and_CSV/customers.csv
[2026-09-05 16:15:02]   MOVED   : products.json -> ./json_and_CSV/products.json
[2026-09-05 16:15:02] Done. 2 of 2 file(s) moved into './json_and_CSV'.
```

The script handles the "no matching files" case gracefully (`nullglob`) and
accepts an optional second argument to place `json_and_CSV` somewhere else.

---

## Version Control (Git)

All work is versioned with Git:

```bash
git init
git add .
git commit -m "Bash ETL pipeline, cron schedule, and CSV/JSON mover"
git branch -M main
git remote add origin https://github.com/Effiong-lesley/CoreDataEngineers-Linux-Git-ETL.git
git push -u origin main
```

Runtime outputs (`raw/`, `Transformed/`, `Gold/`, `logs/`, `json_and_CSV/`)
are excluded via `.gitignore` — they are regenerated by the scripts, so only
source code and documentation live in the repository.

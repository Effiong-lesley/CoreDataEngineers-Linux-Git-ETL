#!/usr/bin/env bash
#===============================================================================
# Script Name : etl.sh
# Author      : Lesley (Data Engineer, CoreDataEngineers)
# Description : A simple ETL pipeline written in pure Bash.
#
#               EXTRACT    -> Downloads a CSV file from a URL into raw/
#               TRANSFORM  -> Renames the "Variable_code" column to
#                             "variable_code" and keeps only the columns
#                             year, Value, Units, variable_code. The result is
#                             saved as Transformed/2023_year_finance.csv
#               LOAD       -> Copies the transformed file into Gold/
#
#               Every step prints status information and confirms that the
#               expected file actually exists in the expected folder.
#
# Configuration: The source URL is supplied through the ENVIRONMENT VARIABLE
#                CSV_URL so the script never hard-codes secrets/endpoints:
#
#                    export CSV_URL="https://example.com/data.csv"
#                    ./etl.sh
#
#                If CSV_URL is not set, the script falls back to the default
#                Stats NZ Annual Enterprise Survey 2023 CSV below.
#
# Usage       : ./etl.sh
# Cron        : 0 0 * * *  /path/to/Scripts/bash/etl.sh  (daily at 12:00 AM)
#===============================================================================

# --- Safety settings ---------------------------------------------------------
# -e  stop the script immediately if any command fails
# -u  treat unset variables as errors
# -o pipefail  a pipeline fails if ANY command in it fails
set -euo pipefail

# --- Configuration -----------------------------------------------------------
# The URL comes from the environment variable CSV_URL (with a safe default).
CSV_URL="${CSV_URL:-https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv}"

# Resolve the project root (two levels up from Scripts/bash/) so the script
# works no matter which directory it is launched from (important for cron).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Folder and file names used by the pipeline.
RAW_DIR="$PROJECT_ROOT/raw"
TRANSFORMED_DIR="$PROJECT_ROOT/Transformed"
GOLD_DIR="$PROJECT_ROOT/Gold"
RAW_FILE="$RAW_DIR/annual_enterprise_survey_2023.csv"
TRANSFORMED_FILE="$TRANSFORMED_DIR/2023_year_finance.csv"

# --- Helper ------------------------------------------------------------------
# log(): prints a timestamped, labelled message so each step is visible
# in the terminal and in cron log files.
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "============================================================"
log " CoreDataEngineers ETL pipeline started"
log "============================================================"

#===============================================================================
# STEP 1: EXTRACT - download the CSV file into the raw/ folder
#===============================================================================
log "STEP 1/3 [EXTRACT] Creating raw folder (if it does not exist)..."
mkdir -p "$RAW_DIR"

log "STEP 1/3 [EXTRACT] Downloading CSV from: $CSV_URL"
# -f fail on HTTP errors, -s silent, -S show errors, -L follow redirects
# --retry gives the download a few chances in case of a flaky network
curl -fsSL --retry 3 --retry-delay 5 -o "$RAW_FILE" "$CSV_URL"

# Confirm the file was saved in the raw folder.
if [ -s "$RAW_FILE" ]; then
    log "STEP 1/3 [EXTRACT] SUCCESS: File confirmed in raw folder -> $RAW_FILE"
    log "STEP 1/3 [EXTRACT] File size: $(du -h "$RAW_FILE" | cut -f1), rows: $(wc -l < "$RAW_FILE")"
else
    log "STEP 1/3 [EXTRACT] FAILED: $RAW_FILE is missing or empty. Aborting."
    exit 1
fi

#===============================================================================
# STEP 2: TRANSFORM - rename Variable_code -> variable_code and keep only
#         the columns: year, Value, Units, variable_code
#===============================================================================
log "STEP 2/3 [TRANSFORM] Creating Transformed folder (if it does not exist)..."
mkdir -p "$TRANSFORMED_DIR"

log "STEP 2/3 [TRANSFORM] Selecting columns [year, Value, Units, variable_code]..."
# awk does the heavy lifting. A small CSV parser function is used because the
# source file contains quoted fields with embedded commas (e.g. "728,225"),
# which would corrupt the output if we simply split on every comma.
awk '
BEGIN { OFS = "," }

# parse(): splits one CSV line into the arr[] array, respecting double quotes.
function parse(line, arr,   i, c, field, in_q, n) {
    n = 0; field = ""; in_q = 0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (in_q) {
            if (c == "\"") {
                # "" inside quotes is an escaped quote character
                if (substr(line, i + 1, 1) == "\"") { field = field "\""; i++ }
                else in_q = 0
            } else field = field c
        } else {
            if (c == "\"") in_q = 1
            else if (c == ",") { arr[++n] = field; field = "" }
            else field = field c
        }
    }
    arr[++n] = field
    return n
}

# q(): re-quote a value if it contains a comma or a quote, so the output
# stays a valid CSV file.
function q(v) {
    if (v ~ /[",]/) { gsub(/"/, "\"\"", v); return "\"" v "\"" }
    return v
}

# Header row: locate the positions of the four required columns
# (case-insensitive, so "Year" and "year" both work).
NR == 1 {
    nf = parse($0, hdr)
    for (i = 1; i <= nf; i++) {
        name = tolower(hdr[i]); gsub(/\r/, "", name)
        if (name == "year")          c_year  = i
        else if (name == "value")    c_value = i
        else if (name == "units")    c_units = i
        else if (name == "variable_code") c_vcode = i
    }
    if (!c_year || !c_value || !c_units || !c_vcode) {
        print "ERROR: a required column is missing from the source file" > "/dev/stderr"
        exit 1
    }
    # Write the new header - note Variable_code is now variable_code.
    print "year", "Value", "Units", "variable_code"
    next
}

# Data rows: emit only the four selected columns, in the required order.
{
    nf = parse($0, f)
    print q(f[c_year]), q(f[c_value]), q(f[c_units]), q(f[c_vcode])
}
' "$RAW_FILE" > "$TRANSFORMED_FILE"

# Confirm the transformed file was saved in the Transformed folder.
if [ -s "$TRANSFORMED_FILE" ]; then
    log "STEP 2/3 [TRANSFORM] SUCCESS: File confirmed in Transformed folder -> $TRANSFORMED_FILE"
    log "STEP 2/3 [TRANSFORM] Header is now: $(head -n 1 "$TRANSFORMED_FILE")"
else
    log "STEP 2/3 [TRANSFORM] FAILED: $TRANSFORMED_FILE is missing or empty. Aborting."
    exit 1
fi

#===============================================================================
# STEP 3: LOAD - copy the transformed file into the Gold/ folder
#===============================================================================
log "STEP 3/3 [LOAD] Creating Gold folder (if it does not exist)..."
mkdir -p "$GOLD_DIR"

log "STEP 3/3 [LOAD] Loading 2023_year_finance.csv into the Gold folder..."
cp "$TRANSFORMED_FILE" "$GOLD_DIR/2023_year_finance.csv"

# Confirm the file was loaded into the Gold folder.
if [ -s "$GOLD_DIR/2023_year_finance.csv" ]; then
    log "STEP 3/3 [LOAD] SUCCESS: File confirmed in Gold folder -> $GOLD_DIR/2023_year_finance.csv"
else
    log "STEP 3/3 [LOAD] FAILED: file not found in Gold folder. Aborting."
    exit 1
fi

log "============================================================"
log " ETL pipeline COMPLETED successfully (raw -> Transformed -> Gold)"
log "============================================================"

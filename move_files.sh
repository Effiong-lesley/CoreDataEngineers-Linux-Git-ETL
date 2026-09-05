#!/usr/bin/env bash
#===============================================================================
# Script Name : move_files.sh
# Author      : Lesley (Data Engineer, CoreDataEngineers)
# Description : Moves ALL .csv and .json files from a source folder into a
#               destination folder named json_and_CSV.
#
#               The script works with ONE or MANY files, tells you exactly
#               which files were moved, and warns you when there is nothing
#               to move.
#
# Usage       : ./move_files.sh <source_folder> [destination_parent]
#
#               <source_folder>      folder containing the CSV/JSON files
#               [destination_parent] optional - json_and_CSV will be created
#                                    inside it (defaults to the current
#                                    directory)
#
# Examples    : ./move_files.sh ./raw
#               ./move_files.sh ./raw ./archive
#===============================================================================

set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# --- Input validation --------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: $0 <source_folder> [destination_parent]"
    echo "Example: $0 ./raw"
    exit 1
fi

SOURCE_DIR="$1"
DEST_PARENT="${2:-.}"                 # default: current working directory
DEST_DIR="$DEST_PARENT/json_and_CSV"  # required destination folder name

if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR: Source folder '$SOURCE_DIR' does not exist. Nothing to do."
    exit 1
fi

log "Source folder      : $SOURCE_DIR"
log "Destination folder : $DEST_DIR"

# Create the destination folder if it does not exist yet.
mkdir -p "$DEST_DIR"

# --- Collect the files -------------------------------------------------------
# nullglob makes the glob expand to NOTHING (instead of a literal "*.csv")
# when no matching files exist - this is what lets the script handle
# zero, one or many files gracefully.
shopt -s nullglob
FILES=("$SOURCE_DIR"/*.csv "$SOURCE_DIR"/*.json)

if [ ${#FILES[@]} -eq 0 ]; then
    log "No CSV or JSON files found in '$SOURCE_DIR'. Nothing to move."
    exit 0
fi

# --- Move the files ----------------------------------------------------------
log "Found ${#FILES[@]} file(s) to move:"
MOVED=0
for FILE in "${FILES[@]}"; do
    BASENAME="$(basename "$FILE")"
    mv "$FILE" "$DEST_DIR/$BASENAME"

    # Confirm each file really arrived in the destination folder.
    if [ -f "$DEST_DIR/$BASENAME" ]; then
        log "  MOVED   : $BASENAME -> $DEST_DIR/$BASENAME"
        MOVED=$((MOVED + 1))
    else
        log "  FAILED  : $BASENAME could not be confirmed in $DEST_DIR"
    fi
done

log "------------------------------------------------------------"
log "Done. $MOVED of ${#FILES[@]} file(s) moved into '$DEST_DIR'."
ls -l "$DEST_DIR"

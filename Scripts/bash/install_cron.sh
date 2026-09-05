#!/usr/bin/env bash
#===============================================================================
# Script Name : install_cron.sh
# Author      : Lesley (Data Engineer, CoreDataEngineers)
# Description : Registers the ETL script as a DAILY cron job that runs at
#               12:00 AM (midnight). Safe to run more than once - it will not
#               create duplicate entries.
#
# Cron syntax reminder:
#   +---------------- minute (0-59)
#   |  +------------- hour (0-23)
#   |  |  +---------- day of month (1-31)
#   |  |  |  +------- month (1-12)
#   |  |  |  |  +---- day of week (0-7, Sunday = 0 or 7)
#   |  |  |  |  |
#   0  0  *  *  *    -> every day at 00:00 (12:00 AM)
#
# Usage       : ./install_cron.sh
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ETL_SCRIPT="$SCRIPT_DIR/etl.sh"
LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$LOG_DIR"

# The exact line that cron will run: daily at 12:00 AM, output appended to a log.
CRON_JOB="0 0 * * * $ETL_SCRIPT >> $LOG_DIR/etl.log 2>&1"

# Add the job only if it is not already present (idempotent).
if crontab -l 2>/dev/null | grep -Fq "$ETL_SCRIPT"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cron job for etl.sh already exists - nothing to change."
else
    ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cron job installed:"
    echo "    $CRON_JOB"
fi

echo "Current crontab:"
crontab -l

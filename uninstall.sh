#!/bin/bash
#
# uninstall.sh - stop and remove the LaunchAgent.
#
# This only unschedules the sync. It does not touch your notes repo, your
# transcripts, your inbox, or the log.

set -euo pipefail

LABEL="${LABEL:-com.notes-sync}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm "$PLIST"
    echo "Removed $PLIST"
else
    echo "Nothing to remove: $PLIST does not exist."
fi

echo "Your notes repo and transcripts were left untouched."

#!/bin/bash
#
# sync_notes.sh - the back half of the pipeline, run automatically on a timer:
#   1) transcribe any new Voice Memos audio sitting in the inbox
#   2) commit + push any new/changed notes to GitHub (only if something changed)
#
# Triggered by the LaunchAgent installed by ./install.sh (see README.md).
# All output is logged to  ~/Library/Logs/notes-sync.log

# --- make brew/git/python visible (launchd runs with a bare-bones PATH) ---
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- authentication ---------------------------------------------------------
# This repo pushes over SSH via a host alias in ~/.ssh/config, bound to its own
# key. Nothing here depends on which `gh` account happens to be active, so the
# script no longer switches it. That switching is what used to race the other
# sync agents when two fired at the same time.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where the notes repo lives. $NOTES_REPO wins (install.sh bakes it into the
# LaunchAgent); otherwise fall back to the parent of this script's folder,
# which is the original layout where scripts/ sits inside the notes repo.
NOTES_REPO="${NOTES_REPO:-$(dirname "$SCRIPT_DIR")}"
export NOTES_REPO                 # transcribe_inbox.py reads the same variable
TRANSCRIBE="$SCRIPT_DIR/transcribe_inbox.py"
PYTHON="$(command -v python3)"   # if launchd can't find faster-whisper, hard-code, e.g. PYTHON="/opt/homebrew/bin/python3"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

# 1) Transcribe new audio (does nothing if the inbox is empty).
"$PYTHON" "$TRANSCRIBE"

# 2) Commit + push, but only if the repo actually changed.
cd "$NOTES_REPO" || { echo "Repo not found: $NOTES_REPO"; exit 1; }

if [ -z "$(git status --porcelain)" ]; then
    # Nothing new, but an earlier push may have failed and stranded commits.
    if [ -n "$(git log --branches --not --remotes --oneline 2>/dev/null)" ]; then
        echo "No new changes, but local commits are unpushed - retrying push."
        if git push; then
            echo "Pushed backlog."
        else
            echo "!! PUSH FAILED - commits are still only local."
            exit 1
        fi
    else
        echo "No changes to push."
    fi
    exit 0
fi

git add -A

# Name the commit after the transcripts just added (falls back to a timestamp).
added=$(git diff --cached --name-only --diff-filter=A \
        | sed 's#.*/##; s#\.txt$##' \
        | awk 'NR>1{printf "; "} {printf "%s", $0} END{if (NR) print ""}')

if [ -n "$added" ]; then
    msg="notes: add $added"
else
    msg="notes: update ($(date '+%Y-%m-%d %H:%M'))"
fi

git commit -m "$msg"


# Check the push. This script used to echo success unconditionally, which is
# exactly how days of failures went unnoticed.
if git push; then
    echo "Pushed -> $msg"
else
    echo "!! PUSH FAILED - committed locally but not on GitHub: $msg"
    exit 1
fi

#!/bin/bash
#
# install.sh - set up the voice-memo -> transcript -> git pipeline on this Mac.
#
#   ./install.sh /path/to/your/notes-repo
#
# It checks the dependencies, renders the LaunchAgent template with real paths,
# and loads it. Safe to re-run: it reloads the agent in place.
#
# Nothing here touches the notes repo's contents - it only schedules the sync.

set -euo pipefail

LABEL="${LABEL:-com.notes-sync}"
INTERVAL="${INTERVAL:-600}"        # seconds between runs (600 = 10 minutes)
LOG_FILE="${LOG_FILE:-$HOME/Library/Logs/notes-sync.log}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

die() { echo "error: $*" >&2; exit 1; }
ok()  { echo "  ok   $*"; }

# ---------------------------------------------------------------- arguments
NOTES_REPO="${1:-${NOTES_REPO:-}}"
[ -n "$NOTES_REPO" ] || die "usage: ./install.sh /path/to/your/notes-repo"
NOTES_REPO="$(cd "$NOTES_REPO" 2>/dev/null && pwd)" \
    || die "no such directory: ${1:-$NOTES_REPO}"

echo "Installing the notes pipeline"
echo "  pipeline : $HERE"
echo "  notes    : $NOTES_REPO"
echo "  agent    : $LABEL  (every ${INTERVAL}s)"
echo "  log      : $LOG_FILE"
echo

# ------------------------------------------------------------- dependencies
echo "Checking dependencies..."
command -v git     >/dev/null || die "git not found. Install Xcode command line tools: xcode-select --install"
ok "git       $(git --version | awk '{print $3}')"

command -v python3 >/dev/null || die "python3 not found. Try: brew install python"
ok "python3   $(python3 --version | awk '{print $2}')"

command -v ffmpeg  >/dev/null || die "ffmpeg not found. Run: brew install ffmpeg"
ok "ffmpeg    present"

python3 -c 'import faster_whisper' 2>/dev/null \
    || die "faster-whisper not installed. Run: pip3 install faster-whisper"
ok "faster-whisper installed"

# ------------------------------------------------------- notes repo sanity
echo
echo "Checking the notes repo..."
[ -d "$NOTES_REPO/.git" ] || die "$NOTES_REPO is not a git repo. Create it first - see README.md, 'Set up the notes repo'."
ok "git repo"

REMOTE="$(git -C "$NOTES_REPO" remote get-url origin 2>/dev/null || true)"
[ -n "$REMOTE" ] || die "$NOTES_REPO has no 'origin' remote. Add one - see README.md."
ok "origin -> $REMOTE"

case "$REMOTE" in
    https://*) echo "  note  origin is HTTPS. SSH with a per-account host alias is recommended; see README.md, 'Authentication'." ;;
esac

if ! grep -qs 'VoiceMemoInbox' "$NOTES_REPO/.gitignore"; then
    echo "  note  $NOTES_REPO/.gitignore does not ignore VoiceMemoInbox/."
    echo "        Raw audio would get committed. Copy templates/notes-repo.gitignore over it."
fi

mkdir -p "$NOTES_REPO/VoiceMemoInbox"
ok "inbox     $NOTES_REPO/VoiceMemoInbox"

# ------------------------------------------------------------ render plist
echo
echo "Writing the LaunchAgent..."
chmod +x "$HERE/scripts/sync_notes.sh" "$HERE/scripts/transcribe_inbox.py"
mkdir -p "$(dirname "$PLIST_DEST")" "$(dirname "$LOG_FILE")"

sed -e "s|__LABEL__|$LABEL|g" \
    -e "s|__SYNC_SCRIPT__|$HERE/scripts/sync_notes.sh|g" \
    -e "s|__INTERVAL__|$INTERVAL|g" \
    -e "s|__LOG_FILE__|$LOG_FILE|g" \
    -e "s|__NOTES_REPO__|$NOTES_REPO|g" \
    "$HERE/launchd/com.notes-sync.plist.template" > "$PLIST_DEST"
plutil -lint "$PLIST_DEST" >/dev/null || die "generated plist is malformed: $PLIST_DEST"
ok "$PLIST_DEST"

# -------------------------------------------------------------- load agent
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load  "$PLIST_DEST"
ok "agent loaded (it runs once now, then every ${INTERVAL}s)"

cat <<DONE

Done.

  Watch it work     tail -f "$LOG_FILE"
  Run it by hand    "$HERE/scripts/sync_notes.sh"
  Remove it         "$HERE/uninstall.sh"

First run downloads the whisper model once, so it needs internet that one time
and will take a minute. After that, transcription is fully local.

Name each voice memo  "YYYY-MM-DD - Account - Description"  and drop it in
  $NOTES_REPO/VoiceMemoInbox
DONE

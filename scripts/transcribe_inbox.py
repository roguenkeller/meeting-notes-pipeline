#!/usr/bin/env python3
"""
transcribe_inbox.py - local meeting-transcript pipeline (step 1 of 2)

WHAT IT DOES
  1. Looks in INBOX for audio you dragged out of Voice Memos.
  2. Transcribes each new file locally with faster-whisper (nothing leaves your Mac).
  3. Files the transcript under  NOTES_REPO/<account>/  using your date-first title
     verbatim:  "YYYY-MM-DD - Account - Description.txt"
  4. Moves the processed audio into  INBOX/_archive  so it is never redone.

HOW YOU DRIVE VOICE MEMOS
  - Title each memo   "YYYY-MM-DD - Account - Description"
    e.g.  "2026-06-29 - Contoso - Discovery Call"
    The 2nd field (Account) becomes the folder; the whole title becomes the filename.
  - Drag it (or Copy -> Paste) into the INBOX folder set below.

ONE-TIME SETUP  (paste into Terminal)
  brew install ffmpeg
  pip3 install faster-whisper
  (First run also downloads the chosen whisper model once - needs internet that one time.)

RUN IT
  python3 transcribe_inbox.py
  Safe to run anytime - it skips anything already transcribed.
  (Next step will trigger this automatically so you never run it by hand.)
"""

import os
import re
import sys
import shutil
import datetime
import tempfile
import subprocess
from pathlib import Path

# ------------------------------- CONFIG -----------------------------------
# Where the transcripts get filed. Resolved in this order:
#   1. the NOTES_REPO environment variable  (what install.sh bakes into the
#      LaunchAgent - use this when the pipeline is its own clone, separate
#      from the notes repo)
#   2. the parent of this script's folder   (the original layout, where
#      scripts/ lives inside the notes repo itself)
NOTES_REPO    = Path(
    os.environ.get("NOTES_REPO") or Path(__file__).resolve().parent.parent
).expanduser().resolve()
INBOX         = NOTES_REPO / "VoiceMemoInbox"   # drop recordings here (gitignored)
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "small.en")
#               tiny.en | base.en | small.en | medium.en  (bigger = more accurate, slower)
# --------------------------------------------------------------------------

AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".aac", ".qta", ".mp4", ".caf"}


def slugify(name: str) -> str:
    """Folder-safe customer name: 'Contoso Systems' -> 'contoso-systems'."""
    s = re.sub(r"[^\w\s-]", "", name).strip().lower()
    return re.sub(r"[\s_]+", "-", s) or "misc"


def safe(s: str) -> str:
    """Filename-safe: strip characters macOS dislikes, keep spaces and case."""
    return re.sub(r"[\\/:]", "-", s).strip()


DATE_RE = re.compile(r"^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$")   # ISO-style date as the first field


def parse_meta(stem: str, file_date: str):
    """
    Decide the ACCOUNT (which becomes the folder) and the FILENAME from the memo title.

    Preferred title:  'YYYY-MM-DD - Account - Description'
        -> folder   = the Account (the 2nd field)
        -> filename = the title exactly as typed (date stays first, the way you like it)

    If you skip the date and just type 'Account - Description'
        -> folder   = the Account (the 1st field)
        -> filename = same, but the date is prepended so it's still date-first

    No ' - ' / no account found  ->  'Misc'.
    """
    parts = [p.strip() for p in stem.split(" - ")]
    if len(parts) >= 2 and DATE_RE.match(parts[0]):
        account = parts[1]
        filename_stem = stem.strip()                       # already date-first
    elif len(parts) >= 2:
        account = parts[0]
        filename_stem = f"{file_date} - {stem.strip()}"    # add the date in front
    else:
        account = "Misc"
        filename_stem = f"{file_date} - {stem.strip()}"
    return account, filename_stem


def to_wav(src: Path) -> Path:
    """Normalize any container (m4a/qta/etc.) to 16 kHz mono WAV via ffmpeg."""
    wav = Path(tempfile.gettempdir()) / (src.stem + ".pipeline.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(src), "-ar", "16000", "-ac", "1", str(wav)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return wav


def transcribe(wav: Path, model) -> str:
    segments, _ = model.transcribe(str(wav), language="en")
    return "\n".join(seg.text.strip() for seg in segments).strip()


def main():
    INBOX.mkdir(parents=True, exist_ok=True)
    archive = INBOX / "_archive"
    archive.mkdir(exist_ok=True)

    files = [
        p for p in INBOX.iterdir()
        if p.is_file() and p.suffix.lower() in AUDIO_EXTS and not p.name.startswith(".")
    ]
    if not files:
        print("Nothing new in the inbox.")
        return

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("faster-whisper isn't installed yet. Run:  pip3 install faster-whisper")

    print(f"Loading whisper model '{WHISPER_MODEL}' ...")
    model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")

    for audio in sorted(files):
        print(f"\n-> {audio.name}")
        file_date = datetime.date.fromtimestamp(audio.stat().st_mtime).isoformat()
        account, filename_stem = parse_meta(audio.stem, file_date)

        try:
            wav = to_wav(audio)
        except subprocess.CalledProcessError:
            print(f"   ! ffmpeg couldn't read {audio.name}; skipping (leaving it in the inbox).")
            continue

        text = transcribe(wav, model)
        wav.unlink(missing_ok=True)

        out_dir = NOTES_REPO / slugify(account)          # folder = the account
        out_dir.mkdir(parents=True, exist_ok=True)
        out_file = out_dir / f"{safe(filename_stem)}.txt"   # filename = your date-first title

        header = f"# {filename_stem}\nAccount: {account}\nSource: {audio.name}\n\n"
        out_file.write_text(header + text, encoding="utf-8")
        print(f"   ok  {out_file.relative_to(NOTES_REPO.parent)}")

        shutil.move(str(audio), str(archive / audio.name))

    print("\nDone. New transcripts are in your notes repo, ready to commit.")


if __name__ == "__main__":
    main()

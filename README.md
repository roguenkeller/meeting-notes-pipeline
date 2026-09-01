# Meeting Notes Pipeline

Turn a voice memo into a filed, committed, pushed meeting transcript — without
touching a keyboard after the meeting ends.

Record a memo on your phone, name it `2026-06-29 - Contoso - Discovery Call`, drop
it in the inbox folder. Ten minutes later the transcript is a text file in
`contoso/` in your private notes repo, committed and pushed.

Transcription runs **locally** via [faster-whisper](https://github.com/SYSTRAN/faster-whisper).
No audio and no meeting content is sent to any third-party service.

> **This repo contains the tooling only.** Your actual notes live in a separate,
> **private** repo that you own. Nothing in here should ever hold meeting
> content — see [What must stay private](#what-must-stay-private).

---

## How it works

```
   Voice Memos app
        │  name it "YYYY-MM-DD - Account - Description", drag it out
        ▼
   <notes-repo>/VoiceMemoInbox/          ← gitignored, raw audio
        │
        │  transcribe_inbox.py           ← every 10 min, via launchd
        │    • ffmpeg  → 16 kHz mono wav
        │    • faster-whisper → text     ← fully local
        │    • parse title → account + filename
        ▼
   <notes-repo>/contoso/2026-06-29 - Contoso - Discovery Call.txt
        │                             and the audio moves to VoiceMemoInbox/_archive
        │
        │  sync_notes.sh
        ▼
   git add / commit / push  →  your private GitHub repo
```

Two scripts, one scheduler:

| File | Role |
|---|---|
| `scripts/transcribe_inbox.py` | Step 1. Transcribes and files new audio. Idempotent — skips anything already done. |
| `scripts/sync_notes.sh` | Step 2. Runs step 1, then commits and pushes **only if something changed**. |
| `launchd/com.notes-sync.plist.template` | Runs `sync_notes.sh` at login and every 10 minutes. |
| `install.sh` | Checks dependencies, renders the template with your real paths, loads the agent. |
| `uninstall.sh` | Unloads and removes the agent. Leaves your notes alone. |
| `templates/notes-repo.gitignore` | The `.gitignore` your private notes repo should use. |
| `SETUP-WITH-AI.md` | Copy-paste prompt for setting this up with an AI assistant. |

---

## The naming convention (this is the whole interface)

Everything downstream keys off the memo title:

```
2026-06-29 - Contoso - Discovery Call
└── date ──┘   └ account ┘  └ description ┘
```

* **Field 2 becomes the folder.** `Contoso` → `contoso/`. Slugified: lowercased,
  spaces to hyphens, so `Northwind Traders` → `northwind-traders/`.
* **The whole title becomes the filename**, verbatim, plus `.txt`.
* Fields are separated by ` - ` (space, hyphen, space). That exact separator
  matters; hyphens *inside* a description are fine as long as they aren't
  surrounded by spaces.

Fallbacks, so a sloppy title never loses a recording:

| You type | Folder | Filename |
|---|---|---|
| `2026-06-29 - Contoso - Discovery Call` | `contoso/` | as typed |
| `Contoso - Discovery Call` (no date) | `contoso/` | file's modified date is prepended |
| `random memo` (no ` - `) | `misc/` | date prepended |

Each transcript is written with a small header:

```
# 2026-06-29 - Contoso - Discovery Call
Account: Contoso
Source: 2026-06-29 - Contoso - Discovery Call.m4a

<transcript text>
```

---

## Setup

macOS only — it relies on `launchd`. Roughly 15 minutes.

> **Want an AI assistant to walk you through it?**
> [SETUP-WITH-AI.md](SETUP-WITH-AI.md) has a copy-paste prompt for ChatGPT (or
> any capable assistant). It interviews you about your paths, GitHub account,
> and preferences, then takes you through the steps one command at a time.
> The rest of this section is the manual version.

### 1. Install the dependencies

```bash
brew install ffmpeg
pip3 install faster-whisper
```

`ffmpeg` normalizes whatever container Voice Memos produces; `faster-whisper` is
the local speech-to-text model.

### 2. Set up the notes repo

This is the **private** repo your transcripts get pushed to. It is *not* this
repo. Create it empty on GitHub first, marked private, then:

```bash
mkdir -p ~/notes && cd ~/notes
git init
curl -o .gitignore https://raw.githubusercontent.com/roguenkeller/meeting-notes-pipeline/main/templates/notes-repo.gitignore
git add .gitignore && git commit -m "initial commit"
git remote add origin git@github.com:YOU/notes.git
git push -u origin main
```

Copy `templates/notes-repo.gitignore` from this repo into it as `.gitignore`.
It excludes `VoiceMemoInbox/` and all audio formats — **do not skip this**, or
you will commit raw meeting recordings.

Set the identity you want on the commits:

```bash
git -C ~/notes config user.name  "Your Name"
git -C ~/notes config user.email "you@company.com"
```

### 3. Install the pipeline

```bash
git clone https://github.com/roguenkeller/meeting-notes-pipeline.git ~/meeting-notes-pipeline
cd ~/meeting-notes-pipeline
./install.sh ~/notes
```

`install.sh` verifies every dependency, confirms the notes repo is a git repo
with a remote, creates the inbox folder, renders the LaunchAgent with your real
paths, and loads it. It's safe to re-run — it reloads in place.

The **first run downloads the whisper model once** (needs internet that one
time, takes a minute). Everything after that is offline.

### 4. Confirm it works

```bash
tail -f ~/Library/Logs/notes-sync.log
```

Drop a short test memo in `~/notes/VoiceMemoInbox`, wait for the next tick (or
run `./scripts/sync_notes.sh` by hand), and watch it get transcribed, filed, and
pushed.

---

## Authentication

The pipeline pushes over whatever remote your notes repo already has. It does
**not** call `gh`, and it does not care which `gh` account is active — an
earlier version switched accounts, and that raced other sync agents whenever two
fired at once. Don't reintroduce that.

If you juggle a work and a personal GitHub account on one Mac, give each its own
key and host alias in `~/.ssh/config`:

```
Host github-work
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_gh_work

Host github-personal
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_gh_personal
```

Then point the notes repo at the alias, so the right key is chosen structurally
rather than by whatever happens to be logged in:

```bash
git -C ~/notes remote set-url origin git@github-work:YOU/notes.git
```

The SSH key must be unlocked without a prompt for launchd runs to succeed — add
it to the keychain with `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_gh_work`.

---

## Configuration

Both scripts read these from the environment; `install.sh` bakes `NOTES_REPO`
into the LaunchAgent.

| Variable | Default | Meaning |
|---|---|---|
| `NOTES_REPO` | parent of `scripts/` | Which notes repo to file into, commit, and push. |
| `WHISPER_MODEL` | `small.en` | `tiny.en`, `base.en`, `small.en`, `medium.en`. Bigger = more accurate and slower. |

Install-time knobs, passed as environment variables to `install.sh`:

| Variable | Default | Meaning |
|---|---|---|
| `LABEL` | `com.notes-sync` | LaunchAgent label and plist filename. Change it to run two pipelines side by side. |
| `INTERVAL` | `600` | Seconds between runs. |
| `LOG_FILE` | `~/Library/Logs/notes-sync.log` | Where output goes. |

Running two pipelines (say, work and personal) is just two clones and two
labels:

```bash
LABEL=com.notes-sync-personal ./install.sh ~/personal-notes
```

The `NOTES_REPO` default — the parent of the `scripts/` folder — exists so the
original layout still works, where `scripts/` lived *inside* the notes repo. A
fresh install should use a separate clone and let `install.sh` set the variable.

---

## Day-to-day operation

```bash
# is it scheduled?
launchctl list | grep notes-sync

# what has it been doing?
tail -50 ~/Library/Logs/notes-sync.log

# force a run right now
./scripts/sync_notes.sh

# transcribe only, no commit or push
NOTES_REPO=~/notes python3 ./scripts/transcribe_inbox.py

# stop it
./uninstall.sh
```

---

## Troubleshooting

**Nothing happens; the log is empty.**
The agent isn't loaded. `launchctl list | grep notes-sync` should show it. If
not, re-run `./install.sh ~/notes`. Note that a `StartInterval` agent only fires
while you're logged in.

**`faster-whisper isn't installed yet`, but you installed it.**
launchd runs with a minimal environment and may pick a different `python3` than
your shell does. Check with `which python3`, then hard-code that path in
`sync_notes.sh`:

```bash
PYTHON="/opt/homebrew/bin/python3"
```

**`ffmpeg couldn't read <file>; skipping`.**
The file stays in the inbox on purpose so you don't lose it. Usually a partial
copy — the memo was still being written when the agent fired. It'll be picked up
on the next tick. If it persists, the file is corrupt; try converting by hand.

**`!! PUSH FAILED - committed locally but not on GitHub`.**
The transcript is safe, it's committed locally. It's an auth or network problem.
Test with `git -C ~/notes push`. If SSH is the issue, `ssh -T git@github-work`
should greet you by username. The script retries stranded commits on every
subsequent run, so once you fix the cause, the backlog pushes itself.

The script *checks* the push result rather than assuming success — an earlier
version echoed "Pushed" unconditionally, and days of failures went unnoticed.
Keep that check.

**Transcripts land in `misc/`.**
The title didn't parse. Check the separator is exactly ` - ` — space, hyphen,
space — and that the date is `YYYY-MM-DD`.

**Transcription is slow or inaccurate.**
Trade one for the other with `WHISPER_MODEL`. `small.en` is the balance point;
`medium.en` is noticeably better and noticeably slower on CPU.

**A memo was transcribed twice.**
It shouldn't be — processed audio moves to `VoiceMemoInbox/_archive`. If a file
is back in the inbox, something re-copied it.

---

## What must stay private

The notes repo holds real customer meeting content — names, pricing, roadmaps,
internal strategy. Treat it accordingly:

* **The notes repo is private. Always.** Never make it public, and never push
  transcripts to this tooling repo.
* **Raw audio is never committed.** `VoiceMemoInbox/` and every audio extension
  are gitignored. Verify with `git -C ~/notes status` before your first commit.
* **Transcription is local.** faster-whisper runs on your Mac. Don't swap in a
  hosted transcription API without checking what that means for customer data.
* **This repo is public tooling.** Before committing here, confirm the diff has
  no meeting content, no customer names, no absolute paths containing your
  username, and no keys.

---

## Handoff notes

Things worth knowing that aren't obvious from the code:

* **The naming convention is the entire user interface.** There's no config file
  mapping accounts to folders — the folder *is* field 2 of the title, slugified.
  A new account needs no setup; just name the memo after it.
* **`sync_notes.sh` is deliberately quiet when idle.** It exits early when
  `git status --porcelain` is empty, so the log stays readable. But it still
  checks for unpushed commits in that branch, which is how a stranded backlog
  recovers on its own.
* **Don't put `gh auth switch` back in.** See [Authentication](#authentication).
* **Don't let the push result go unchecked.** See [Troubleshooting](#troubleshooting).
* **The transcript header is load-bearing if you index these later.** `Account:`
  and `Source:` lines make the flat text files greppable and let you trace a
  transcript back to its recording in `_archive`.
* **`_archive` grows forever.** It's gitignored, so it only costs disk. Prune it
  when you care.

---

## License

MIT — see [LICENSE](LICENSE).

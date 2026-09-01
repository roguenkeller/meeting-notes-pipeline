# Meeting Notes Pipeline

Record a voice memo. Ten minutes later the transcript is a text file, filed under
the right customer folder in your private notes repo, committed and pushed.

Transcription runs **locally** — no audio and no meeting content leaves your Mac.

**Full documentation is in the [wiki](https://github.com/roguenkeller/meeting-notes-pipeline/wiki).**
This page is just how to get it running.

> Your transcripts go in a **separate, private** repo that you own. Nothing in
> this repo should ever hold meeting content.

---

## Before you start

macOS only — scheduling uses `launchd`. You need a GitHub account and about
15 minutes.

```bash
brew install ffmpeg
pip3 install faster-whisper
```

---

## 1 · With an AI assistant

Recommended if you'd rather answer questions than read instructions.

Open [SETUP-WITH-AI.md](SETUP-WITH-AI.md), copy the prompt, paste it into ChatGPT
(or Claude, or any capable assistant). It interviews you about your paths, GitHub
account, and preferences, then walks you through one command at a time.

Two things it is told never to do, and you should hold it to them:

* **Never ask you to paste a password, token, or 2FA code into the chat.** All
  sign-in happens in your own terminal.
* **Never make your notes repo public.**

---

## 2 · DIY

**Create a private repo** on GitHub for your notes — call it `notes` — then:

```bash
mkdir -p ~/notes && cd ~/notes
git init -b main
curl -o .gitignore https://raw.githubusercontent.com/roguenkeller/meeting-notes-pipeline/main/templates/notes-repo.gitignore
git add .gitignore && git commit -m "initial commit"
git remote add origin git@github.com:YOU/notes.git
git push -u origin main
```

The `.gitignore` is not optional — it is what keeps raw audio out of git.

**Set the identity** for these commits:

```bash
git -C ~/notes config user.name "Your Name"
git -C ~/notes config user.email "you@company.com"
```

**Install the pipeline** (a separate clone, not inside your notes folder):

```bash
git clone https://github.com/roguenkeller/meeting-notes-pipeline.git ~/meeting-notes-pipeline
cd ~/meeting-notes-pipeline
./install.sh ~/notes
```

`install.sh` checks every dependency, verifies your notes repo, creates the
inbox, and loads the scheduler. Re-running it is safe.

**Confirm it works.** The first run downloads the whisper model once, so give it
a minute:

```bash
tail -f ~/Library/Logs/notes-sync.log
```

Using two GitHub accounts on one Mac? Set up an SSH host alias first —
[Authentication](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Authentication).

---

## Using it

**Name every memo like this.** The format is the whole interface:

```
2026-06-29 - Contoso - Discovery Call
└── date ──┘   └ account ┘  └ description ┘
```

Field 2 becomes the folder — `Contoso` → `contoso/`. Separators are exactly
` - ` (space, hyphen, space).

Then drop the recording in `~/notes/VoiceMemoInbox` and leave it alone.

```bash
tail -f ~/Library/Logs/notes-sync.log     # watch it
./scripts/sync_notes.sh                   # force a run now
./uninstall.sh                            # stop it
```

---

## More

| | |
|---|---|
| [How It Works](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/How-It-Works) | The pipeline end to end |
| [Naming Convention](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Naming-Convention) | Full rules and fallbacks |
| [Authentication](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Authentication) | Multiple accounts, and why pushes fail silently |
| [Configuration](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Configuration) | Every variable and knob |
| [Troubleshooting](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Troubleshooting) | Symptom → cause → fix |
| [Privacy and Data Handling](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Privacy-and-Data-Handling) | What stays private, and how |
| [Handoff Notes](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Handoff-Notes) | What isn't obvious from the code |

## License

MIT — see [LICENSE](LICENSE).

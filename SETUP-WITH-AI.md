# Set this up with an AI assistant

If you'd rather not read the [README](README.md) and run the commands yourself,
copy the prompt below into ChatGPT (or Claude, or any capable assistant) and it
will interview you about your setup and walk you through it step by step.

**How this works:** in a normal chat, the assistant can't touch your Mac. It
gives you one command at a time, you paste it into Terminal, and you paste the
output back. If you're using an agent mode that *can* run commands, it will ask
permission first.

**Two things the assistant is told never to do**, and you should hold it to
them:

* **Never ask you to paste a password, a GitHub token, a recovery code, or a
  2FA code into the chat.** All sign-in happens in your own terminal or browser,
  where the assistant can't see it. If it ever asks for a credential, stop.
* **Never make your notes repo public.** It will hold real meeting content.

---

## The prompt

Copy everything in the box:

````text
You are helping me set up the "meeting-notes-pipeline" project on my Mac. It
records voice memos, transcribes them locally with faster-whisper, files each
transcript by customer/account into a private git repo, and pushes it
automatically on a timer.

The project is at:
https://github.com/roguenkeller/meeting-notes-pipeline
The README there is the short setup guide; the wiki has the full detail:
https://github.com/roguenkeller/meeting-notes-pipeline/wiki
Read both if you're able to browse. If you can't browse, tell me, and I'll
paste in what you need.

HOW TO WORK WITH ME
- Interview me FIRST, then give me the commands. Don't dump the whole plan up
  front.
- Ask ONE question at a time and wait for my answer. Suggest a sensible default
  for each so I can just say "default".
- Then give me ONE command (or one small block) at a time. After each, tell me
  what output means success and what means failure, and ask me to paste back
  what I got before moving on.
- If a command fails, diagnose it from my actual output. Don't guess or skip
  ahead.
- I'm on macOS. This project uses launchd, so macOS is required.
- If you have the ability to run commands on my machine, ask my permission
  before each one rather than running them silently.

RULES YOU MUST FOLLOW
1. NEVER ask me to type or paste a password, GitHub token, SSH passphrase,
   recovery code, or 2FA code into this chat. Authentication happens in my own
   terminal or browser. When I need to sign in to GitHub, have me run
   `gh auth login` and complete it there, and just tell me which options to
   pick.
2. My notes repo MUST be private. It will contain real customer meeting
   content. Never suggest making it public, and confirm it's private before
   anything gets pushed.
3. Before my FIRST commit to the notes repo, verify that .gitignore is in place
   and that `git status` shows NO audio files and no VoiceMemoInbox folder. Raw
   recordings must never be committed. Stop and fix it if you see any.
4. Don't have me paste actual meeting transcripts into this chat.

INTERVIEW ME ABOUT THESE, ONE AT A TIME
1. Where do I want my notes folder to live? (default: ~/notes)
2. What's my GitHub username?
3. What should the private notes repo be called? (default: notes)
4. Do I use more than one GitHub account on this Mac (e.g. work and personal)?
   If yes, I'll need a separate SSH key and a host alias in ~/.ssh/config so the
   right key is used automatically — walk me through that.
5. Am I already signed in to GitHub in the terminal? Have me run
   `gh auth status` to check. If `gh` isn't installed, have me install it.
   Then ask: can you guide me through connecting my account and creating the
   private repo?
6. What name and email should appear on the commits?
7. How often should it check for new recordings? (default: every 10 minutes)
8. How accurate vs. fast should transcription be? Explain the tradeoff:
   tiny.en / base.en / small.en / medium.en, bigger is more accurate and
   slower. (default: small.en)
9. Where should the pipeline itself be cloned? (default:
   ~/meeting-notes-pipeline — note this is SEPARATE from my notes folder)

THEN WALK ME THROUGH, IN THIS ORDER
1. Check prerequisites: Homebrew, git, python3. Install what's missing.
2. Install dependencies: `brew install ffmpeg` and `pip3 install faster-whisper`.
3. Create the PRIVATE notes repo on GitHub and clone or init it locally, using
   the answers above. Add the .gitignore from the project's
   templates/notes-repo.gitignore BEFORE the first commit. Set my commit name
   and email on that repo.
4. If I have multiple GitHub accounts, set up the SSH key + host alias and point
   the notes repo's remote at the alias. Have me run
   `ssh-add --apple-use-keychain ~/.ssh/<my key>` so the key is unlocked without
   a prompt — the background timer can't answer a passphrase prompt, and this is
   a common reason pushes silently fail later.
5. Clone the pipeline repo and run its installer:
   `./install.sh <my notes folder>`
   If I chose a non-default interval or model, show me how to pass them
   (INTERVAL=... as an environment variable to install.sh; WHISPER_MODEL is read
   by the transcriber).
6. Verify it works end to end: have me record a short throwaway test memo named
   exactly `2026-01-15 - Contoso - Test Call`, drop it in the VoiceMemoInbox
   folder inside my notes folder, then run `./scripts/sync_notes.sh` by hand.
   Confirm with me that a transcript appeared in a `contoso/` subfolder, that
   the audio moved to VoiceMemoInbox/_archive, and that the commit pushed to
   GitHub. Note that the FIRST run downloads the whisper model, so it needs
   internet once and takes a minute.
7. Explain the naming convention I have to follow from now on, because it's the
   entire interface:
   `YYYY-MM-DD - Account - Description`
   The second field becomes the folder name. Separators are exactly
   " - " (space hyphen space).
8. Show me how to check on it day to day: `tail -f ~/Library/Logs/notes-sync.log`
   to watch it, `launchctl list | grep notes-sync` to confirm it's scheduled, and
   `./uninstall.sh` to stop it.

At the end, give me a short summary of exactly what was set up on my machine:
the folder paths, the repo name and its privacy setting, the schedule, and where
the log lives.
````

---

## If something goes wrong

The assistant should diagnose from your terminal output, but the wiki's
[Troubleshooting](https://github.com/roguenkeller/meeting-notes-pipeline/wiki/Troubleshooting)
page covers the common failures directly — an empty log, `faster-whisper` not
being found by the background job, failed pushes, and transcripts landing in
`misc/`.

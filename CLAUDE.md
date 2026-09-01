# CLAUDE.md — meeting-notes-pipeline

Standing rules for this repository. `force-barrier` is the general practice; this
file records where this project differs from it and what is specific to it.

---

## Working practice

`force-barrier` applies as written: `main` is the trunk, one branch per
enhancement created before the first edit, progress committed and pushed to that
branch, pull request when it is good enough, and merging is the user's call.

`main` is the trunk here — there is no integration branch and no tagged release
line. Feature pull requests target `main` directly.

**Two commits reached `main` without a pull request** — `1447455` and `785096f`,
both documentation, on the day the repository was created. Only the initial
commit is entitled to that. They are recorded here rather than rewritten, since
they are published; the practice applies from this file forward.

---

## The exception: this repository is public

`force-barrier` instantiates new projects with `gh repo create --private`. This
one is deliberately **public**, at the user's explicit instruction, because its
whole purpose is to be handed to someone else.

That exception costs something, and the cost is a hard rule:

> **No meeting content, ever.** Not a transcript, not a fragment, not a real
> customer name, not an account folder listing.

The private notes repository is the separate repo this tooling writes into. The
two must not converge. Concretely, before any commit here:

```bash
git diff --cached | grep -inE "<real customer names>|/Users/[a-z]"
```

Examples in documentation use fictional placeholders — Contoso, Northwind
Traders. Real customer names are not to be used as illustrations even where no
content accompanies them, because the list of names is itself the client list.

`.gitignore` blocks audio extensions and `VoiceMemoInbox/` as a backstop. That is
a second line of defence, not the first.

---

## Shell scripts are committed executable

Four files ship as executables: `install.sh`, `uninstall.sh`,
`scripts/sync_notes.sh`, `scripts/transcribe_inbox.py`. Git must record them as
`100755`.

This is not cosmetic. A script committed `100644` fails with permission denied
for anyone who runs it the way the documentation says to, and the defect is
invisible on Windows, where the executable bit does not exist and so cannot be
set by the machine that commits it. The sibling `jedi-archives` repository
carried exactly this defect in three scripts for weeks.

Check before every commit that adds or moves a script:

```bash
git ls-files -s | awk '$1=="100644"{print $4}' | while read -r f; do head -c2 "$f" | grep -q '^#!' && echo "NOT EXECUTABLE: $f"; done
```

Fix with `git update-index --chmod=+x <path>`, which works on every platform,
rather than `chmod`, which does nothing observable on Windows.

---

## Verifying a change

There is no unit test suite. The meaningful test is an end-to-end run against a
throwaway repository with a local bare remote, which needs no network and touches
nothing real:

```bash
git init --bare /tmp/e2e/remote.git
git init /tmp/e2e/notes && cd /tmp/e2e/notes && git remote add origin /tmp/e2e/remote.git
```

Install against it with a throwaway label so the real LaunchAgent is untouched,
generate a memo with `say`, run `scripts/sync_notes.sh`, then confirm four
things: the transcript landed in the right account folder, the audio moved to
`VoiceMemoInbox/_archive`, the commit pushed, and a second run is a no-op.

```bash
LABEL=com.notes-sync-e2etest LOG_FILE=/tmp/e2e/test.log ./install.sh /tmp/e2e/notes
LABEL=com.notes-sync-e2etest ./uninstall.sh
```

**Always pass a throwaway `LABEL`.** The default label is the one a real install
uses, and testing with it will unload the user's working agent.

---

## Versioning

The project does not version. `force-barrier`'s version-bump rule is conditional
on the project having one, so nothing is required at merge time today. If a
version is introduced later, record here where it is pinned so the places that
must move together are known.

---

## What is deliberately absent

- **No `docs/` directory.** Documentation is split three ways instead:
  `README.md` is the execution guide and nothing else, `SETUP-WITH-AI.md` is the
  copy-paste prompt, and the **wiki** carries the reference — how it works, the
  naming convention, authentication, configuration, troubleshooting, privacy,
  and these handoff notes. An in-repo `docs/` tree would duplicate the wiki.

  The wiki is a **separate git repository**, not a directory here. Clone it as a
  sibling to edit it:

  ```bash
  git clone git@github.com:roguenkeller/meeting-notes-pipeline.wiki.git
  ```

  **Keep the README short.** It grew to 330 lines by absorbing reference material
  and stopped answering the question a new reader actually has. Detail that wants
  to expand belongs in the wiki.
- **No CI.** Nothing here compiles, and the meaningful test needs a Mac with
  `ffmpeg`, `faster-whisper` and `launchd`. Verification is the manual end-to-end
  run above.

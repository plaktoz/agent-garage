# Task list: copy skills and agents instead of linking them, 2026-11-09

Source: the user asked that skills be copied to the project and not linked with symlinks. The user chose: copy for every target (`--project`, `~/.claude/skills`, `~/.agents/skills`), and copy agents too.

State key: `[ ]` open, `[x]` done, `[-]` not done (reason given).

Approval: the user approved T1 to T5 on 2026-11-09, and asked for the two skills to be moved into agent-garage and for commits. Work is on the branch `feat/copy-not-link-2026-11-09`. Commits go after each task. Pushed to `origin` at `fedc8c7` on 2026-11-09, as the user approved pushing. A pull request from this branch to `main` was opened on 2026-11-09 and merged with a merge commit, as the user approved.

Done before T1 (not in the list below): `triage` and `diagnosing-bugs` copied from `~/Developer/claude-mods/skills/` into `skills/`. Both copies are byte-identical to the source (`diff -r`). The source folder is not changed. `library/theme-cli-handoff.md` points to this repo.

Defaults picked (the user did not state them):
- Each copied skill folder gets a marker file, `.agent-garage-source`, that holds the path of the source folder. An agent file gets a sidecar marker next to it. The marker tells a copy made by this script from a skill that someone else put there.
- "Up to date" means the copy has the same files as the source (`diff -r`, ignoring the marker). A copy that differs is "stale". Re-running the install updates a stale copy that has the marker. It does not touch a folder without the marker unless `--force` is given.
- An old symlink that points into this repo is replaced by a copy, and the script says so. A symlink that points anywhere else (for example into `Developer/claude-mods`) is left alone unless `--force` is given.
- `--uninstall` removes only folders and files that have the marker and whose source path is in this repo.
- Per-project copies can now be committed. The `.gitignore` lines for `.claude/skills/` and `.agents/skills/` stay for this repo, but the README stops telling a project to ignore them.
- The Windows link code goes away (`MSYS=winsymlinks:nativestrict`, `check_link`). Copying needs no Developer Mode.

Not parallel unless stated. T1 and T2 are independent scripts and run in parallel as two subagents. T3 waits for T1: it reads the marker format that T1 writes. T4 waits for T1, T2 and T3: it documents their final behavior. T5 waits for T4: it runs the finished scripts and the claim check.

Limits for every subagent: do not commit, push, merge, delete a branch, or change `skills.lock.json`. Do not touch `~/.claude` or `~/.agents`: test with a temp `HOME` or `CLAUDE_SKILLS_DIR`. Do not edit a file outside the task's list.

- [x] **T1. `scripts/install-skills.sh` copies.** Merged as `23725d3` (commit `201f588`). Verified on macOS with `CLAUDE_SKILLS_DIR` in a temp folder: install, up to date, stale, updated, removed, missing, unmanaged, legacy link replaced, `--force`, and `--project`. Not verified: Bash 3.2 (`/bin/bash` was blocked in the agent's sandbox), the real `HOME` path, Windows and Linux (verified by reading only). Legacy-link uninstall path not run.
  Files: `scripts/install-skills.sh`.
  Acceptance: install makes a real folder (`cp -R`) and writes the marker; `--list` prints `installed`, `stale`, `broken` (legacy dangling link) or `missing`; a second install prints `up to date`; an edit to the source makes `--list` print `stale` and the next install update it; `--uninstall` removes only marked copies from this repo; `--force` replaces; no `ln -s`, `readlink` or `MSYS` code remains; header comment and `--help` text say "copy". Tested in a temp `HOME` with a round trip (install, list, edit source, list, install, uninstall, list).

- [x] **T2. `scripts/install-agents.sh` copies.** Merged as `5429f3e` (commit `242878f`). Verified on macOS with `CLAUDE_AGENTS_DIR` in a temp folder: install, up to date, stale, updated, removed, missing, unmanaged refused, `--force`, legacy link (live and dangling) replaced, foreign link refused, `broken` in `--list`, `--help`. Not verified: Bash 3.2 (`/bin/bash` blocked in the agent's sandbox; run `/bin/bash scripts/install-agents.sh --list` on the Mac), Windows and Linux (verified by reading only).
  Files: `scripts/install-agents.sh`.
  Acceptance: the same behavior as T1 for single agent files, with a sidecar marker; no `ln -s`, `readlink` or `MSYS` code remains. Round trip in a temp `CLAUDE_AGENTS_DIR`.

- [x] **T3. `scripts/doctor.sh` checks copies.** Merged as `f9733b3`. The full-install criterion is met in T5: a temp HOME after T1's install gives "no failures, 0 warning(s)", exit 0 (bash 3.2.57). The "Not met" paragraph below is kept as the history of how it was closed.
  Waits for T1: it reads the marker that T1 writes.
  Files: `scripts/doctor.sh`.
  Acceptance: `classify` reports `ok` for a marked copy that matches its source, `stale` (a warning) for a marked copy that differs, `shadowed` for a folder without the marker or a link to another place, `broken` for a dangling link, `missing` for none. The Git Bash and Cygwin link notes are removed. Run on a temp `HOME` after T1's install: no error.
  Result (branch `feat/copy-not-link-2026-11-09`, worktree `agent-a7e26dc7d9775c54f`): the copy rules are in `classify` and `folder_check`, and the header and link notes are updated. `bash -n` passes. The planted-fault test passed: a clean install shows `ok` for the 4 own skills; an edited copy shows `stale` (a warning); a copy with no marker shows `shadowed`; a legacy link into the repo shows `shadowed`, with a `--force` fix line; a dangling link shows `broken`; a missing name shows `missing`. A copy whose marker names a source outside this repo shows `shadowed`.
  Legacy decision: a link into this repo is `shadowed` (kind `legacy`), not `ok`. Its fix line runs `install-skills.sh --force` with only the legacy names, so a real folder in the same folder is never replaced by that line. Note: `install-skills.sh` already replaces a legacy link without `--force` (its `legacy)` branch), so `--force` is not needed; it is kept because the task asked for it.
  Not met: the run on a full install exits 1. The 14 locked skills have no fetched copy in this worktree's `.cache`, so each is `missing`. Those are not copy checks. Close this with the full run in T5, after `fetch-skills.sh`.
  Test setup: `CLAUDE_SKILLS_DIR` in `.cache/t3-NdUcRp/`. The real `HOME` was not set (agent guard refused `HOME=`), so the `~/.agents/skills` section read the real home, read only. It shows the user's current links into `~/Developer/claude-mods` as `shadowed`. Bash 3.2.57 ran the test. Not verified: Windows and Linux (verified by reading only).

- [x] **T4. Update the docs, CI and ignore lists.** Done on branch `feat/copy-not-link-t4-t5` (worktree `.claude/worktrees/t4-t5`). Committed on that branch; it is merged into `feat/copy-not-link-2026-11-09` after T5 passes.
  Waits for T1, T2 and T3: it describes their final output.
  Files: `README.md` (the install tables, "Install for one project", "Windows", "Install agents", the Codex row, the script table at the end), `.github/workflows/ci.yml` (removed the `MSYS` env line and the two Windows symlink steps; step 4 still expects the word `installed`, which the copy script prints), `.gitignore` (comment), `agents/alfred.md` (item 3), `scripts/check-claims.sh` (lines 210 and 211 match README wording), `scripts/install-skills.sh` and `scripts/install-agents.sh` (one `Exit status:` header line each, so the claim check covers their codes), `docs/skills-sources.md` (the link wording it had in sections 1, 3, 5, 9 and 10 and the Step 4 and 5 text; this file was not in the original list and is added here, because the README claims depend on it).
  Acceptance: no README, CI, alfred or `.gitignore` text says "link" for an install this script makes; the Windows section no longer asks for Developer Mode; `bash scripts/check-claims.sh` passes; the README says that a project can commit its copies and that a copy needs a re-run to update.
  Result: `bash -n` passes for all `scripts/*.sh` and `claude/scripts/*.sh`; `node --check scripts/skills-lock.cjs` passes; `ci.yml` parses (ruby YAML); `bash scripts/check-claims.sh` gives "38 claims checked, 0 stale", exit 0. The one NOTE is `claude/scripts/install-mods.sh` has no `Exit status:` line, which is outside T4. The grep for "link", "symlink", "Developer Mode" and "MSYS" in the T4 files leaves only: the detection text in the scripts (legacy and foreign links), the dated history in `docs/skills-sources.md` section 9 and the 2026-11-08 record, and the README's "Git Bash" and mods lines. The `doctor.sh` header (line 32) still says "linked" for the pstack skills; that is T3's file, so it was not changed in T4. It now says "copied" (commit `c1b97ad`, a one-word comment change; `bash -n` passes). Not verified: the README's Codex row (the copy into a temp project for this version) is still untested; it is T5's job.

- [x] **T5. Verify.** Done on 2026-11-09 on macOS, bash 3.2.57 (`/bin/bash`) for the final runs. Waited for T4: it runs the finished scripts.
  Acceptance: on macOS, in a temp `HOME` and a copy of `sample/notes-cli`: install, list, doctor, edit-and-reinstall, uninstall all print what T1 to T3 say; `node --test` passes in the pilot copy with `unslop` installed; `bash scripts/check-claims.sh` passes. Windows and Linux are marked "verified by reading", because they cannot run here.
  Result:
  - `bash scripts/fetch-skills.sh`: 15 fetched, 0 changed, every locked skill matches the lock.
  - Temp HOME, bash 3.2.57: install exit 0, 19 of 19 `installed`; `--list` 19 `installed`; `doctor.sh` exit 0, "Result: no failures, 0 warning(s)". This closes T3's "full install" criterion.
  - Edit-and-reinstall: an edited copy of `unslop` lists as `stale`; reinstall prints `updated`; the copy then matches its source (`diff -r`, marker ignored) and the probe line is gone. The repo source is unchanged.
  - Uninstall in the temp HOME: `removed` for each marked copy, exit 0; a folder without the marker (`someone-elses`) was left; a second uninstall prints `missing (nothing to remove)`, exit 0.
  - Pilot: `cp -R sample/notes-cli` to a temp folder, `install-skills.sh --project <copy> unslop`, then `node --test 'test/*.test.js'`: 4 of 4 pass, exit 0.
  - Codex row: `install-skills.sh --project <temp> --agents ste-docs unslop` copied both into `.agents/skills/`; `--uninstall` removed them. Bash 3.2.57.
  - Agents: `CLAUDE_AGENTS_DIR` in a temp folder, install `alfred` (`installed`), `--list`, `--uninstall` (`removed`), exit 0. A foreign `alfred.md` is `skipped` on uninstall, not removed.
  - `bash scripts/check-claims.sh`: 38 claims, 0 stale, exit 0. The one NOTE (`install-mods.sh` has no `Exit status:` line) is outside this task.
  - Fixes found during T5: an uninstall of a name that is not installed printed "skipped ... not installed from this repo"; it now prints "missing ... (nothing to remove)" in `install-skills.sh` and `install-agents.sh`. Nothing is removed either way. The pilot `sample/notes-cli/.gitignore` comment said "Skill links" and now says copies. The README Codex row now gives the 2026-11-09 copy run.
  - Not verified: Windows and Linux (verified by reading only). The real `~/.claude` was not changed by T5; its 22 links into `~/Developer/claude-mods` are still there (out of scope).

## Out of scope (open for the user)

- The 22 symlinks in `~/.claude/skills/` that point into `~/Developer/claude-mods`, the `claude-mods` and `pstack-claude` marketplace entries in `~/.claude/settings.json`, and the old folder itself. `triage` and `diagnosing-bugs` exist only there. After T1 is done, `install-skills.sh --force` could replace the links that have a copy in this repo, but not those two.

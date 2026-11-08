# Task list: close T6, T8, T18, T19, T20, 2026-11-08

Source: the open tasks in `docs/tasks/agent-kit-2026-11-07.md`. The user asked for all five in one PR on branch `docs/close-t6-t8-t18-t19-t20-2026-11-08`. This list is deleted in the last commit of the PR, when every task here is closed.

State key: `[ ]` open, `[x]` done, `[-]` not done (reason given).

Finding at the start: the task file was behind the tree. The README sections, the support table, the CI matrix (`ci.yml`) and most T19 and T20 fixes were already on `main`. So each task below starts with an audit of its claims against the tree, then fixes only what the audit finds.

None of the tasks runs in a subagent. Each is small, and T6 to T20 edit the same task file, so parallel agents would conflict on it.

- [x] **T6. README matches the code.**
  Audit: sections, layout table, support table, pstack and guardrail text are present; no model name in the shared parts (grep clean). Defect: README and `docs/skills-sources.md` say pstack 0.9.92 (`7bad1eb`); the lock says 0.9.133 (`91ab921`, commit date 2026-11-07).
  Acceptance: no pstack version in the README or `docs/skills-sources.md` differs from `skills.lock.json`; `scripts/check-claims.sh` reports 0 stale.
  Result: pstack version, commit and date corrected in `README.md` and `docs/skills-sources.md`; `check-claims.sh` reports 0 stale.

- [-] **T8. Steps for the user.**
  Not done: the steps need the user's machines and projects (the other pstack installs, the `~/.agents/skills` clean-up in the user's home, WSL, Linux, Git Bash). The agent does not change the user's home. The entry stays in the task file, shortened to what is open.

- [x] **T18. Folder reorganisation verified.**
  Acceptance: `claude plugin test` passes for each of the 7 listed mods; a real `install-mods.sh` install from `claude/mods` works; the upgrade note for existing installs is in the README.
  Result: `claude plugin test` 0 fail on all 7 (10, 12, 10, 45, 13, 5, 42 tests). Real install round trip with a temp `HOME` and project scope: 7 installed, 7 listed, 7 removed, 7 missing; checksums of the real `installed_plugins.json`, `known_marketplaces.json` and `settings.json` unchanged. Upgrade note added to the README.

- [x] **T19. OS-agnostic review and fixes.**
  Audit against the 10 report items and the acceptance: items 1 to 10 each have a fix in the tree; `ci.yml` runs `bash -n`, `doctor.sh`, `install-skills.sh --list` and the install on ubuntu, macOS and windows-latest; `main` CI is green.
  Checked here on macOS: `HOME` unset with `USERPROFILE` set; both unset (clear error); `install-agents.sh --list` creates no folder; `doctor.sh` in a temp home exits 0 after the fetch.
  Not run (no such machine here): the WSL job, `install-mods.ps1` under PowerShell 5.1, sound on Windows. They go to T8 as user steps.

- [x] **T20. Conflicting and stale documents.**
  Audit of the ten items: greps for `vendor/`, `CONTEXT.md` and `--codex` find only history, the "superseded" notes, the correct `CONTEXT.md` statement in `docs/skills-sources.md` section 5, and the real `--codex` alias; the playbooks make the guardrail opt-in and name `diagnosing-bugs` and `triage` correctly.
  Result: the task file Status line is rewritten in this PR.

- [ ] **T22. Close out the task file.**
  Waits for T6, T18, T19, T20: it removes their entries. Rewrite the Status line, shorten T8, delete this list.
  Acceptance: `docs/tasks/agent-kit-2026-11-07.md` lists no finished task; all 14 CI checks pass on the PR.

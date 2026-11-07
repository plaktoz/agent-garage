# Task list: self-checking kit, 2026-11-08

Source: the `ambition` proposal of 2026-11-08 ("make the kit self-checking"), approved by the user on 2026-11-08 with "go ahead and create the task list. approval given." The approval covers this task list. It does not cover any task's implementation, and each task below states what its own approval needs.

Status (2026-11-08): nothing in this list is implemented yet. The task list is the only change.

State key: `[ ]` open, `[x]` done, `[-]` not done (reason given). Each task records its result and its verification when it is done.

Commits: the user approved commits and push for the kit's work on 2026-11-08. Commit each task separately, on the branch named in its entry, and push that branch. Do not commit to `main` directly.

## Goal

A claim in the kit's documents that a machine can test is tested in CI on every push. A stale claim fails the build. Each harness cell in the support table is either run, or marked "from vendor documentation, not run" or "verified by reading".

## Definitions

- **Claim**: a sentence or table cell in `README.md`, `playbooks/*.md` or `docs/skills-sources.md` that states a command, a flag, a path, a count, an exit code, a version, a source name or a skill name.
- **Stale claim**: a claim that the code, the lock, the manifest or a real run contradicts.
- **Drift check**: a script that extracts the claims of one kind and compares each with its source. It prints each mismatch and exits 1 when there is one.

## Decisions needed before the tasks that depend on them

These are open. The task that depends on each one stays `[ ]` until the user decides. Each one has a default that the agent would use if the user says "use the default".

1. **Repo licence.** The README says there is no root `LICENSE`. Default: add no licence, and leave the README as it is. Task S5 depends on this.
2. **Codex live run.** `codex login status` on 2026-11-08 shows an API key is configured, but it says authentication is checked only when a request is sent. No live request was sent, so whether the key works is not known. A live request can cost money. Default: do not send one, and keep Codex as "program file read, not run live". Task S7 depends on this.
3. **`ambition` in the lock.** It declares no licence upstream. Default: keep it locked and fetched only. Task S9 depends on this.
4. **Runners for OpenCode and Gemini CLI.** Neither command is on `PATH` on this Mac (`command -v` found only `codex` and `claude`). Default: keep both as "from vendor documentation, not run". Task S7 depends on this.

## Tasks

### Phase 1: the drift checks (no network, no harness)

- [x] **S1. Write the claim drift check for command options and `--help` text.** Branch: `docs/kit-self-check`. Result (2026-11-08): `scripts/check-claims.sh` in commit `052fcfe`. Verified on macOS, bash 3.2.57: the current tree passes (25 claims checked, 0 stale after S2). The three planted faults fail with file and line: a renamed `--project` option, an extra source name, and a changed exit code. Not verified on Linux or Windows; CI (S8) will cover them.
  Do: write `scripts/check-claims.sh`. It reads each `--help` header of `scripts/*.sh` and `claude/scripts/*.sh`, and compares each option and exit code with the README. It also compares the source names that `--help` lists with the keys under `sources` in `skills.lock.json`.
  Acceptance:
  - It exits 0 on the current tree only if every option and exit code matches.
  - It fails on each of these planted faults, one at a time, in a temp copy of the repo: a removed `--project` option in the README; an extra `--source` name in a `--help` text; a changed exit code in a README sentence.
  - It names the file and line of each mismatch.
  - It runs under bash 3.2 and needs no network.
  Known starting failures: `fetch-skills.sh --help` and `check-upstream.sh --help` list two source names, and the lock has four. The check must find these and fail until the help text is fixed in S2.

- [x] **S2. Fix the `--help` source lists.** Branch: `docs/kit-self-check`. Depends on S1 (for the check to name the faults). Result (2026-11-08): commit `ceeefc5`. Both `--help` texts now name all four sources. `fetch-skills.sh --help` and `check-upstream.sh --help` both exit 0. `bash -n` passes on both.
  Do: change the source names in the `--help` text of `scripts/fetch-skills.sh` and `scripts/check-upstream.sh` to all four keys in `skills.lock.json`.
  Acceptance: `bash scripts/fetch-skills.sh --help` and `bash scripts/check-upstream.sh --help` name all four sources. `check-claims.sh` finds no fault for these two scripts. Both scripts pass `bash -n` under bash 3.2.

- [ ] **S3. Write the claim drift check for skill and playbook names.** Branch: `docs/kit-self-check`. Partly done (2026-11-08), commit `7b92fdb`, still open. Done: the skill counts in the README and `docs/skills-sources.md` (17 installed, 13 locked, 11 mattpocock, 1 ambition, 1 good-readme, 4 own) are checked against `skills/` and the lock. A planted count of 16 fails with file and line. Not done as written: a renamed skill in a playbook does not fail `check-claims.sh`, and a skill name missing from the lock or `skills/` in README is not checked. `doctor.sh` already reports a renamed skill inside a playbook "Skills used" block (planted test: exit 1, warning). Decision needed: keep playbook names with `doctor.sh` (default), or move that check into `check-claims.sh`.
  Do: extend `scripts/check-claims.sh` (or add `scripts/check-skill-claims.sh`) to compare each skill name in the README and in `playbooks/*.md` with the skills that exist: `skills/`, the locked sources in `.cache/`, and the `copies` in the lock. It also checks the counts in the README (4 own skills, 13 locked skills, 17 in total) against the files.
  Acceptance:
  - It exits 0 on the current tree only if every named skill exists and every count matches.
  - It fails on each planted fault, in a temp copy: a renamed skill in a playbook; a count of 16 in the README; a skill name that is not in the lock or `skills/`.
  - The known starting claims to check: `playbooks/togaf-app-delivery.md` (line 31) and `playbooks/togaf-bug-fix.md` (lines 25 to 27) say `diagnosing-bugs` and `triage` are used. Both skills exist in `skills/`. The check must pass on this and fail if either skill is removed.

- [ ] **S4. Check the playbook wording for skills and the guardrail.** Branch: `docs/kit-self-check`. Depends on S3.
  Do: read the "Not used" line in `playbooks/togaf-feature-delivery.md` (line 24). It lists only `git-guardrails-claude-code`, which is consistent with `skills/`, so change nothing unless S3 finds a contradiction. Check that the guardrail line in each playbook says the hook is optional and opt-in, as `docs/skills-sources.md` says.
  Acceptance: `check-skill-claims.sh` finds no stale skill claim. If the check finds no contradiction, no playbook file changes, and the entry records that result. No file under `claude/mods/` changes.

- [ ] **S5. Decide and record the repo licence.** Branch: `docs/kit-self-check`. Depends on decision 1.
  Do: if the user chooses a licence, add a root `LICENSE` and state it in `README.md`. If the user chooses none, leave the README as it is.
  Acceptance: the README's License section matches the file on disk. `check-claims.sh` checks this statement.

### Phase 2: the harness and CI checks

- [ ] **S6. Run `claude plugin test` for each mod and record the result.** Branch: `docs/kit-self-check`.
  Do: run `claude plugin test claude/mods/<name>` for each of the 7 mods in `.claude-plugin/marketplace.json`. Run a real `bash claude/scripts/install-mods.sh` into a temp `HOME`, and then `--uninstall`. Record each real output in the task list.
  Acceptance: each of the 7 mods passes, or the failure and its cause are recorded. The `--list` output after the install names the 7 mods. This check needs the `claude` command and a Claude Code login. Verify on this Mac, and record it as "run on macOS".
  Note: the install writes to the real Claude Code settings. Run it in a temp `HOME`, and say so in the record.

- [ ] **S7. Run the skill installs under each harness that can run here.** Branch: `docs/kit-self-check`. Depends on decision 2.
  Do: for Codex, install with `--agents` into a temp project and check that the skill file is where Codex reads it. Send a live Codex request only if the user approves it under decision 2. For OpenCode and Gemini CLI, record "not run: not installed" unless decision 4 gives a runner.
  Acceptance: the support table cell for each harness states the result of this run, or the reason it was not run.

- [ ] **S8. Add the drift checks to CI on all three systems.** Branch: `docs/kit-self-check`. Depends on S1, S3, S4.
  Do: add a job to `.github/workflows/ci.yml` that runs `scripts/check-claims.sh` and `scripts/check-skill-claims.sh` on `ubuntu-latest`, `macos-latest` and `windows-latest` (Git Bash). Add `pull_request` to the trigger if it is not already there, and add `push` for every branch, not only `main`.
  Acceptance:
  - The job passes on the current tree on all three systems.
  - A pushed branch with a planted stale claim fails the job. Run this on a test branch and delete the branch afterwards.
  - The job uses the same temp `HOME` as the kit checks.

- [ ] **S9. Decide whether `ambition` stays in the lock.** Depends on decision 3. Not on any other task.
  Do: if the user keeps it, record the decision in `docs/skills-sources.md` section 9. If the user removes it, remove the source entry, the locked skill and the `skills/` references, and run `fetch-skills.sh` and `doctor.sh` again.
  Acceptance: `doctor.sh` gives no failure, and the skill count in the README matches the lock.

### Phase 3: the next rung

- [ ] **S10. Turn the weekly upstream check into a pull request.** Branch: `docs/kit-self-check`. Depends on S8 and on a rule from the user about which upstream changes can merge without a read.
  Do: change `.github/workflows/upstream-check.yml` so that, when upstream moved, it opens a pull request. The pull request updates the lock with `fetch-skills.sh --update`, and runs the drift checks. A person merges it.
  Acceptance: the workflow opens a pull request on a test branch, and the check results are in its description. The rule from the user is written in `docs/skills-sources.md`.
  Not started until the user gives the rule. Keep this `[ ]`.

## Not verified and out of scope

- Linux, WSL and Git Bash are checked by CI only. Those results count as "run in CI", not as a person's run.
- Native PowerShell is not in CI.
- The `ambition` author's permission to redistribute is not verified.
- The older task lists in `docs/` are history. They are not edited.

## Housekeeping

- Do not read `agent-ignore/`.
- Do not change `skills/` or `claude/mods/` in S1 to S5 without a planted fault test.
- Record the result of each task in its entry before you start the next task.

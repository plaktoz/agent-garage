# Task list: add the minimalism-ladder skill, 2026-11-09

Source: `/Users/tianhonglee/Developer/agentzero-v2-dev/packs/minimalism-ladder` (pack version 0.1.0). The user approved two choices on 2026-11-09:

- Scope: the skill and the checker. That is `PACK.md` as `SKILL.md`, `schema/ladder-record.json`, `scripts/check_evidence.py`, `tests/test_check_evidence.py` and `config.yaml`.
- Relation to `ponytail`: keep both and state the split.

State key: `[ ]` open, `[x]` done, `[-]` not done (reason given).

Approval: the user approved the scope above. The user has not asked for commits, so nothing is committed.

Left behind on purpose: `minimalism-ladder-spec.md`, `fixtures/`, `SKILL-ASSESSMENT.md`, `__pycache__/`. They carry the pack's open decisions D1 to D3 (fixture language, two results that do not match their fixture, no independent judge). The skill must not claim "8 of 8 fixtures pass".

Defaults picked (the user did not state them):
- The folder keeps the pack layout (`scripts/`, `schema/`, `tests/`), so the tests find the script with no edit.
- No `agents/openai.yaml`. The skill is meant to run on its own when a task adds code, so implicit use stays on.
- `SKILL.md` text is copied as the pack has it, plus one added sentence in the description that says when to pick `ponytail` and when to pick the ladder.

Not parallel: all tasks are small, and T2 and T3 read the files that T1 writes. No subagent writes files.

- [x] **T1. Copy the skill files into `skills/minimalism-ladder/`.**
  Acceptance: the folder holds `SKILL.md`, `config.yaml`, `schema/ladder-record.json`, `scripts/check_evidence.py` and `tests/test_check_evidence.py`; no `__pycache__`; `SKILL.md` front matter `name` equals the folder name; the description says when to pick `ponytail` and when to pick the ladder.

- [-] **T2. Test it.** Not fully met: the last criterion failed (see Results). The other checks passed.
  Waits for T1: it runs the copied files.
  Acceptance: `python3 -I -m unittest discover -s tests` in the folder ends `OK`; the `SKILL.md` example record passes `check_evidence.py` against a temporary repository; `install-skills.sh --project <temp folder> minimalism-ladder` links it; `doctor.sh` shows no new failure.

- [x] **T3. Update the documents.**
  Waits for T1: the counts depend on the folder existing.
  Acceptance: `README.md` and `docs/skills-sources.md` list three own skills and 17 skills in all; one paragraph says how the ladder and `ponytail` differ; the Python need is in the Requirements table; `bash scripts/check-claims.sh` ends with no FAIL line.

## Results

- T1 `[x]`. `skills/minimalism-ladder/` holds `SKILL.md`, `config.yaml`, `schema/ladder-record.json`, `scripts/check_evidence.py` and `tests/test_check_evidence.py`. Changes to the pack text (three, all small): the description lost its "Minimalism ladder:" opening, because a colon and a space in an unquoted YAML value can break a strict parser; the description gained the `ponytail` split; the Output record section names the schema and the check command (with `python` for Windows); `config.yaml` says "skill" where it said "pack".
- T2 `[-]`. The `doctor.sh` criterion ("no new failure") is not met: it shows 2 new failures. The other criteria are met. `python3 -I -m unittest discover -s tests`: 17 tests, OK (Python 3.15.0, macOS). `check_evidence.py` on a temporary repository: a record with a real `src/mod.py:x` exits 0; a record naming a missing file exits 1 with `MISSING`. `install-skills.sh --project <temp> minimalism-ladder` printed `installed` and exited 0; `--uninstall` exited 0. `doctor.sh` went from 31 to 33 failures. Both new ones are "minimalism-ladder not in this folder" for `~/.claude/skills` and `~/.agents/skills`. The skill is not linked into the home folders, because the user did not ask for that. The 31 earlier failures have the same cause for other skills.
- T3 `[x]`. `README.md`: counts 16 to 17 and 2 to 3 own skills, the own-skills list, a `python3` row in Requirements, and two bullets in Limits (the ladder and `ponytail` differ; the fixtures were not copied). `docs/skills-sources.md`: the own-skills sentence, the fetch note and the install example. `bash scripts/check-claims.sh`: 36 claims checked, 0 stale.

Verified by reading only: Windows and Linux. The script uses `pathlib` and `encoding="utf-8"` and has no POSIX-only call. The tests ran on macOS only.

Not done, not asked: linking the skill into `~/.claude/skills`; a commit; the pack's open decisions D1 to D3 (they stay in the source pack).

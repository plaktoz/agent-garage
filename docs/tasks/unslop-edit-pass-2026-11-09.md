# Task list: unslop edit pass and stock wording, 2026-11-09

Source: the review of `skills/unslop` against `agentzero-v2-dev/packs/anti-slop`. The user chose option A1 (an edit pass in `unslop`, with no tie to any document) and option B (add the `phrases.yaml` words to `banned-words.md` as rows, with a plain-sense exception). Options C (description) and D (fixtures) are not approved.

State key: `[ ]` open, `[x]` done, `[-]` not done (reason given).

Approval: the user approved A1 and B on 2026-11-09. The user has not asked for commits, so nothing is committed.

Defaults picked (the user did not state them):
- A call with a named target runs one edit pass and does not turn on chat mode. A call with no target turns on chat mode, as before.
- The edit pass keeps structure: it does not add, remove or reorder headings, sections or paragraphs. It leaves code, front matter, quoted text, paths and commands alone.
- Nothing in `SKILL.md` names a kind of document (no "PR", "README", "spec"). The target is any prose that the user names.
- The playbooks are not edited. They already say "Run `unslop` on <thing>", which now works. Open question for the user: `SKILL.md` has `disable-model-invocation: true`, so an agent that follows a playbook cannot call the skill itself. Not changed, because it is a decision about implicit use (see `README.md`, Codex table).

Not parallel: both tasks are small and T2 reads the table layout that T1 refers to. No subagent writes files. One fresh subagent runs the test in T3.

- [x] **T1. Add the edit pass to `skills/unslop/SKILL.md`.**
  Acceptance: the description names both uses; a "Modes" section defines chat mode and edit pass; "Scope" no longer excludes a named target; an "Edit pass" section gives numbered steps with a fact check; no sentence names a kind of document; the file has no contraction and no word from `banned-words.md` outside a quote.

- [x] **T2. Add the stock wording rows and the plain-sense exception to `skills/unslop/banned-words.md`.**
  Waits for T1: rule 8 in `SKILL.md` names the two tables.
  Acceptance: every word and phrase in `anti-slop/phrases.yaml` has a row (30 items: 16 phrases and 14 words; `leverage` had a row already, and now covers its other forms); the file has a "Plain sense" section with four examples; the file keeps the existing rows.

- [-] **T3. Test it.**
  Waits for T1 and T2: it runs the finished files.
  Acceptance: every item of `phrases.yaml` is a row in `banned-words.md` (script check). A fresh subagent that has only the two files and a sample text in `/tmp` returns: no fact changed, plain-sense words kept, a vague claim with no fact listed and not invented, no structure change, a second pass with no change. `README.md` and `docs/skills-sources.md` still match the skill.

## Results (2026-11-09)

- T1 `[x]`. `skills/unslop/SKILL.md` has the Modes section, the two-part Scope, rule 8 naming both tables, and the numbered Edit pass. Checked by grep: no contraction except the possessives "user's" and "target's"; no document kind named (PR, README, spec, PRD, doc); "serves as" appears once, quoted as an example of a pattern.
- T1 change made after the T3 run (default picked): step 6.1 deletes the vague phrase, not the sentence, and step 8 forbids deleting a whole sentence. Reason: the first T3 second pass deleted "The cache is a solution that lets teams move faster." and the first pass had kept it.
- T2 `[x]`. `skills/unslop/banned-words.md` has a "Stock wording" table with all 30 `phrases.yaml` items (a script found none missing), a "Plain sense" section, and the 34 original plain-language rows (`leverage` extended to its other forms).
- T3 `[-]`. Not met. Sample at `/tmp/unslop-test`, three fresh subagents (one edit pass, then a second pass on the first output).
  - Run 1 (before the step 8 change): pass 1 kept every fact, the headings and the 10 paragraphs. Pass 2 then deleted a whole sentence, which is the failure fixed above.
  - Run 3 (after the change): pass 1 kept every fact, headings, paragraphs and sentences (13 before and 13 after), and listed the vague claims.
  - Run 4 (pass 2 on run 3): replaced "The cache is a solution that lets teams move faster." with "The cache is a solution that speeds up lookups." This is a change of meaning, not a removal of a stock phrase: the claim moved from teams to lookups. Step 6.2 allows replacing a vague phrase with a fact from the target, but does not require the fact to be about the same subject. The second-pass subagent also said a second pass "would change nothing" without running one. That claim is not evidence.
  - Open: the second-pass check fails in one sample. Proposed fix (not applied, needs the user's decision): step 6.2 applies only when the fact is about the same subject as the vague phrase; otherwise step 6.3 (put it in "Left for you"). Then rerun pass 1 and pass 2 on the same sample.
  - Not run: a second pass on run 3 done by a fresh agent, separately from run 4's reading. One sample each; the results vary between runs.


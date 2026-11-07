# Skill sources

Where each skill and plugin of this kit comes from, what it does outside the conversation, and how to update it. The recorded versions are in `skills.lock.json`, the only file that says which commit is used.

## 1. How the sources are kept

- Third-party skills are not copied into this repository. `scripts/fetch-skills.sh` fetches them into `.cache/<source>/` (git-ignored) at the commit that `skills.lock.json` records, and checks each skill's git tree hash against the lock.
- `scripts/install-skills.sh` links each skill from `skills/` (own skills) or from `.cache/` (locked skills) into `~/.claude/skills` or `~/.agents/skills`. With `--project <folder>` it links into `<folder>/.claude/skills`, or into `<folder>/.agents/skills` when `--agents` is also given.
- `scripts/doctor.sh` checks the lock against the fetched copies and the installed links. It changes nothing.
- The lock is recorded, not pinned. Only `scripts/fetch-skills.sh --update` changes it, and only after review.

## 2. Sources

| Source | Repository | Commit (recorded) | Upstream commit date | Licence | What the kit uses |
|--------|------------|-------------------|----------------------|---------|-------------------|
| mattpocock-skills | https://github.com/mattpocock/skills | `4ae2317ddb22b046e26455e4f9c9b3aaaf62212d` | 2026-10-31 | MIT, Copyright (c) 2026 Matt Pocock | 11 skills, fetched into `.cache/mattpocock-skills/` |
| pstack-claude | https://github.com/michael-denyer/pstack-claude | `7bad1ebc26faa268806bfbb84e5af55d178b68e4` (plugin version 0.9.92) | 2026-10-17 | see the repository | the `pstack` plugin, fetched into `.cache/pstack-claude/` |
| ambition | https://github.com/jakedahn/ambition | `02dd70c28aeb436dc30f72cbd777d1982943ad88` | 2026-10-15 | none declared (no LICENSE file; GitHub reports none) | 1 skill, fetched into `.cache/ambition/` |
| good-readme | https://github.com/adewale/good-readme | `17c42e29537ab9316339b73d57cbc74316cf01bd` | 2026-11-05 | MIT, Copyright (c) 2026 Ade | 1 skill, fetched into `.cache/good-readme/` |

The licence of mattpocock/skills is MIT. Its text is at https://github.com/mattpocock/skills (the LICENSE file), and after a fetch it is also at `.cache/mattpocock-skills/LICENSE`.

`jakedahn/ambition` declares no licence. The kit therefore fetches it and links it. It never copies the files into this repository. Do not copy them into `skills/` unless the author gives permission. The repository is public, although its README says it is private.

Two own skills are copies of upstream skills, made by hand and recorded under `copies` in `skills.lock.json`: `diagnosing-bugs` and `triage`. They live in `skills/` and are not fetched. `skills/ste-docs` and `skills/unslop` are own skills with no upstream source.

## 3. Locked skills (mattpocock/skills)

| Skill | Upstream path | Why the kit uses it | Calls (Skill tool) | Mentions (name only) |
|-------|---------------|---------------------|--------------------|----------------------|
| `grill-me` | `skills/productivity/grill-me` | Sharpens a plan before work starts. | `grilling` | |
| `grill-with-docs` | `skills/engineering/grill-with-docs` | Sharpens a plan and records terms and decisions. | `grilling`, `domain-modeling` | |
| `to-spec` | `skills/engineering/to-spec` | Replaces `to-prd`. | | |
| `to-tickets` | `skills/engineering/to-tickets` | Replaces `to-issues`. | | `setup-matt-pocock-skills` |
| `improve-codebase-architecture` | `skills/engineering/improve-codebase-architecture` | Finds structural problems. | `codebase-design`, `grilling`, `domain-modeling` | |
| `git-guardrails-claude-code` | `skills/misc/git-guardrails-claude-code` | Optional. Blocks dangerous git commands. | | |
| `setup-matt-pocock-skills` | `skills/engineering/setup-matt-pocock-skills` | Writes the per-project settings that other skills read. | | `to-spec`, `to-tickets` |
| `grilling` | `skills/productivity/grilling` | Dependency of `grill-me`, `grill-with-docs` and `improve-codebase-architecture`. | | |
| `domain-modeling` | `skills/engineering/domain-modeling` | Dependency of `grill-with-docs` and `improve-codebase-architecture`. | | |
| `codebase-design` | `skills/engineering/codebase-design` | Dependency of `improve-codebase-architecture`. | | |
| `writing-for-agents` | `skills/productivity/writing-for-agents` | Guides the writing of skills, `AGENTS.md` and `CLAUDE.md`. | | |

The calls and mentions are typed by hand from the SKILL.md files. `fetch-skills.sh --update` does not change them. `doctor.sh` checks that each name exists.

### Locked skills (jakedahn/ambition)

| Skill | Upstream path | Why the kit uses it | Calls (Skill tool) | Mentions (name only) |
|-------|---------------|---------------------|--------------------|----------------------|
| `ambition` | `skills/ambition` | Turns a task into the more ambitious version of itself, and says what that version needs. The method is from Felix Rieseberg's post "How to be more ambitious". | | |

### Locked skills (adewale/good-readme)

| Skill | Upstream path | Why the kit uses it | Calls (Skill tool) | Mentions (name only) |
|-------|---------------|---------------------|--------------------|----------------------|
| `good-readme` | `skills/good-readme` | Creates, improves and audits a project's README.md. Its reference files hold example READMEs and a quality checklist. | | |

## 4. What each skill does outside the conversation

The text of each SKILL.md was read on 2026-11-07. The table shows only what the text says.

| Skill | Runs commands or changes files | Calls the network or publishes |
|-------|--------------------------------|--------------------------------|
| `grill-me` | No. | No. |
| `grilling` | No. It tells the agent to start sub-agents to look up facts. | No. |
| `grill-with-docs` | No. | No. |
| `domain-modeling` | Writes `GLOSSARY.md` and files in `docs/adr/` in the project. | No. |
| `codebase-design` | No. | No. |
| `to-spec` | Reads the repository. | **Yes.** Publishes the spec to the project issue tracker and applies the `ready-for-agent` label. |
| `to-tickets` | Reads the repository. For a local tracker, writes files under `.scratch/`. | **Yes.** For a real tracker, publishes one issue per ticket and applies the `ready-for-agent` label. |
| `improve-codebase-architecture` | Runs `git log`. Writes an HTML file to the temporary folder. Opens it with `open`, `xdg-open` or `start`. | The HTML report loads Tailwind from `cdn.tailwindcss.com` and Mermaid from `cdn.jsdelivr.net/npm/mermaid@11`. The browser makes these calls, not the agent. |
| `setup-matt-pocock-skills` | Edits `CLAUDE.md` or `AGENTS.md`. Writes `docs/agents/*.md`. Can run `git init`, `git remote add origin`, `gh repo view` and `glab repo view`. | **Yes.** Can run `gh label create` or `glab label create` to create labels on the tracker. |
| `git-guardrails-claude-code` | Copies a hook script. Runs `chmod +x`. Edits `.claude/settings.json` or `~/.claude/settings.json`. | No. |
| `writing-for-agents` | No. The text gives advice only. | No. |
| `ambition` | No. It reads a project reference, `references/<project>.md` beside the `SKILL.md`, when one exists. With `/ambition <area>` it reads the README, contributor guide, plan and recent commits of that directory. | No. |
| `good-readme` | No. It reads the project's source and manifests, and the README it is asked to change. The text names no command to run. | No. |

The `ambition` row was read on 2026-11-08 from `SKILL.md` and its README at commit `02dd70c`. The skill names no model and calls no other skill. Its README and example mention Claude Code as the product. The repository also holds a README, an example and `.claude-plugin/` files outside `skills/ambition`. The kit links only the `skills/ambition` folder, so those files are not installed. The folder itself holds `SKILL.md`, `references/` and `evals/`.

The `good-readme` row was read on 2026-11-08 from `SKILL.md` and its five files in `references/` at commit `17c42e2`. The skill names no model and calls no other skill. Its front matter says it works with Codex, OpenCode, Pi, Gemini CLI and Claude Code. It says to use it only when the user asks for a README. It overlaps with the kit's `ste-docs` skill, which the repo rules require for module READMEs: for a README in this repo, use `ste-docs`. The kit links only the `skills/good-readme` folder.

### Approval before publishing

- `to-tickets` asks the user to approve the breakdown before it publishes.
- `to-spec` asks the user to confirm the test seams. It does not ask for approval of the spec before it publishes.
- The TOGAF playbooks in this repository require human approval before `to-spec` and `to-tickets` publish. That rule comes from the playbooks, not from the skills.

### `git-guardrails-claude-code` and `jq`

The hook script `scripts/block-dangerous-git.sh` reads the command with `jq`. If `jq` is not on the `PATH`, the hook does not block anything.

Tested on 2026-11-07 on macOS, with `jq` removed from the `PATH` and `grep` present. The input was `git push origin main`. The script printed `jq: command not found` and exited with code 0. Claude Code treats exit code 0 as allow. With `jq` present, the same input exited with code 2 and the message `BLOCKED`.

The script blocks every `git push`, not only force pushes. The guardrail is opt-in: no playbook requires it. Do not turn it on in a project that uses the Opening a PR or Babysit playbooks, because those playbooks push. `playbooks/togaf-app-delivery.md` (Phase 3, step 3) and `playbooks/togaf-bug-fix.md` list it as optional and say the same.

`doctor.sh` warns when `jq` is missing.

## 5. Differences from the installed copies

Installed copies in `~/.agents/skills` on one machine date from 2026-07-17. They differ from the locked commit in the 10 skills that were checked. The installed set has no `writing-for-agents`. It has `writing-great-skills` instead. Two differences matter:

- The installed `setup-matt-pocock-skills` writes `CONTEXT.md`. The locked version writes `GLOSSARY.md`, and offers to rename an existing `CONTEXT.md`. The TOGAF playbooks in this repository do not name `CONTEXT.md`; the term file they use is `GLOSSARY.md`.
- The installed `grill-me` says "Run a `/grilling` session." The locked `grill-me` says to call the Skill tool with `grilling`.

Installed copies in `~/.claude/skills` that link into `~/.agents/skills` are shadowed for the kit: `doctor.sh` reports them. Remove the link or the folder by hand, then run `scripts/install-skills.sh`.

## 6. Not taken

| Skill | Reason |
|-------|--------|
| `writing-great-skills` | Not at this commit. Upstream renamed it to `writing-for-agents`, which is locked. The upstream CHANGELOG says there is no alias. |
| `tdd` | pstack has its own `tdd`. The playbooks say to use one. |
| `to-prd`, `to-issues`, `write-a-skill`, `zoom-out` | Not at this commit. `to-prd` is now `to-spec`. `to-issues` is now `to-tickets`. `write-a-skill` became `writing-great-skills`, then `writing-for-agents`. The agent did not find `zoom-out`. |

## 7. Update

1. Run `scripts/fetch-skills.sh --update`. It moves each source to the newest commit of its default branch, recomputes each path and tree hash, and rewrites `skills.lock.json`. It lists what changed. If a locked skill is missing upstream, or is found twice, nothing is written.
2. Review the change with `git diff skills.lock.json`.
3. For each changed skill, re-read its SKILL.md. Look for new commands, new network calls and new publishing steps (section 4), and for new Skill-tool calls or skill names. Edit `calls` and `mentions` in `skills.lock.json` by hand, and update section 3 and section 4 here.
4. Run `scripts/fetch-skills.sh` (it checks the tree hashes), then `scripts/install-skills.sh`, then `scripts/doctor.sh`.
5. Commit the lock and this file together, when the user has asked for commits.

To change a locked skill, do not edit `.cache/` by hand: the next fetch restores the recorded commit. To change a skill for the kit, copy it into `skills/` under a new name, and record the origin in `skills.lock.json` under `copies`.

## 8. Plugin: pstack (installed separately, not vendored)

| Name | Source | Locked version | Minimum version | Notes |
|------|--------|----------------|-----------------|-------|
| pstack | https://github.com/michael-denyer/pstack-claude | 0.9.92 (commit `7bad1eb`) | 0.9.57, for project playbooks | Optional. Its skills route to each other, so install it as one plugin. |

- The kit fetches the locked copy into `.cache/pstack-claude/`. `scripts/bootstrap-project.sh <project> --pstack <local|user>` adds that copy as a local marketplace and installs the plugin from it. It never installs again when pstack is already there, and it never removes or replaces a marketplace. `project` scope is refused, because it writes the plugin into the project's shared `.claude/settings.json`.
- Install it per project, with a scope that fits the project: `local` for one project, `user` for every project.
- `scripts/doctor.sh` reports the locked version and commit, what is installed, and the pstack skills that are linked in a skill folder. A pstack install older than 0.9.57 is a warning.
- Source of pstack: https://github.com/michael-denyer/pstack-claude
- A marketplace named `pstack-claude` may already exist on a machine, from GitHub (`claude plugin marketplace add michael-denyer/pstack-claude`). A marketplace name is registered once, so the locked copy cannot be added under that name while the GitHub one is there. `bootstrap-project.sh` then stops and prints the manual commands. The kit does not remove or replace the GitHub marketplace. Use `claude plugin marketplace list` to see which is there.

## 9. Licence notice

mattpocock/skills is MIT licensed. Copyright (c) 2026 Matt Pocock. The full text is at https://github.com/mattpocock/skills, and after a fetch at `.cache/mattpocock-skills/LICENSE`.

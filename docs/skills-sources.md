# Skill sources

Where each skill and plugin of this kit comes from, what it does outside the conversation, and how to update it. The recorded versions are in `skills.lock.json`, the only file that says which commit is used.

## 1. How the sources are kept

- Third-party skills are not copied into this repository. `scripts/fetch-skills.sh` fetches them into `.cache/<source>/` (git-ignored) at the commit that `skills.lock.json` records, and checks each skill's git tree hash against the lock.
- `scripts/install-skills.sh` links each skill from `skills/` (own skills) or from `.cache/` (locked skills) into `~/.claude/skills` or `~/.agents/skills`. With `--project <folder>` it links into `<folder>/.claude/skills`, or into `<folder>/.agents/skills` when `--agents` is also given.
- `scripts/doctor.sh` checks the lock against the fetched copies and the installed links. It changes nothing.
- The lock is recorded, not pinned. Only `scripts/fetch-skills.sh --update` changes it, and only after review.
- To use the skills in another repository, see section 10.

## 2. Sources

| Source | Repository | Commit (recorded) | Upstream commit date | Licence | What the kit uses |
|--------|------------|-------------------|----------------------|---------|-------------------|
| mattpocock-skills | https://github.com/mattpocock/skills | `4ae2317ddb22b046e26455e4f9c9b3aaaf62212d` | 2026-10-31 | MIT, Copyright (c) 2026 Matt Pocock | 11 skills, fetched into `.cache/mattpocock-skills/` |
| pstack-claude | https://github.com/michael-denyer/pstack-claude | `91ab921ab92d9ccfe503c93c3524410277f012e1` (plugin version 0.9.133) | 2026-11-07 | see the repository | the `pstack` plugin, fetched into `.cache/pstack-claude/` |
| ambition | https://github.com/jakedahn/ambition | `02dd70c28aeb436dc30f72cbd777d1982943ad88` | 2026-10-15 | none declared (no LICENSE file; GitHub reports none) | 1 skill, fetched into `.cache/ambition/` |
| good-readme | https://github.com/adewale/good-readme | `17c42e29537ab9316339b73d57cbc74316cf01bd` | 2026-11-05 | MIT, Copyright (c) 2026 Ade | 1 skill, fetched into `.cache/good-readme/` |

The licence of mattpocock/skills is MIT. Its text is at https://github.com/mattpocock/skills (the LICENSE file), and after a fetch it is also at `.cache/mattpocock-skills/LICENSE`.

`jakedahn/ambition` declares no licence. The kit therefore fetches it and links it. It never copies the files into this repository. Do not copy them into `skills/` unless the author gives permission. The repository is public, although its README says it is private.

The kit keeps no copy of an upstream skill. `skills/ste-docs` and `skills/unslop` are the only own skills, and they have no upstream source. `diagnosing-bugs` and `triage` were copies of mattpocock/skills. They were removed on 2026-11-08 (they are in git history).

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

To change a locked skill, do not edit `.cache/` by hand: the next fetch restores the recorded commit. The kit keeps no copy of an upstream skill. To change a locked skill, ask the upstream author, or write an own skill in `skills/` under a new name.

### Merge rule for an upstream update (decided 2026-11-08, S10)

A person merges every update pull request. The rule says how much a person reads first. `check-claims.sh` and `doctor.sh` must pass before any merge.

- **Tier 1, merge without a read.** The upstream commit moved, no locked skill's tree hash changed, and the pstack version is at or above its minimum. Merge when CI passes. The merge records the new commit only, because no installed file changes.
- **Tier 2, read, then merge.** A locked skill's tree hash changed, or the pstack version went up and stays at or above its minimum, or the pstack folder changed with a version that did not go up or cannot be read. Read the diff of each changed folder. Update `calls` and `mentions` by hand, as step 3 above says. Then merge.
- **Tier 3, do not merge.** A locked skill moved or is gone, pstack is below its minimum, a top-level `LICENSE`, `LICENCE` or `COPYING` file was added, removed or changed, a licence file cannot be compared because the locked commit is gone, or a changed skill adds a script, a hook or a settings edit. The update pull request stays open, and the owner decides.

When several sources moved, the highest tier of any source applies to the whole update. `scripts/check-upstream.sh` reads licence files (the "licence" line of each source) and prints the recommended step for each case above. It does not print a tier number. The workflow `upstream-check.yml` derives the tier from the report lines.

The tier is written in the description of the update pull request or issue.

## 8. Plugin: pstack (installed separately, not vendored)

| Name | Source | Locked version | Minimum version | Notes |
|------|--------|----------------|-----------------|-------|
| pstack | https://github.com/michael-denyer/pstack-claude | 0.9.133 (commit `91ab921`) | 0.9.57, for project playbooks | Optional. Its skills route to each other, so install it as one plugin. |

- The kit fetches the locked copy into `.cache/pstack-claude/`. `scripts/bootstrap-project.sh <project> --pstack <local|user>` adds that copy as a local marketplace and installs the plugin from it. It never installs again when pstack is already there, and it never removes or replaces a marketplace. `project` scope is refused, because it writes the plugin into the project's shared `.claude/settings.json`.
- Install it per project, with a scope that fits the project: `local` for one project, `user` for every project.
- `scripts/doctor.sh` reports the locked version and commit, what is installed, and the pstack skills that are linked in a skill folder. A pstack install older than 0.9.57 is a warning.
- Source of pstack: https://github.com/michael-denyer/pstack-claude
- A marketplace named `pstack-claude` may already exist on a machine, from GitHub (`claude plugin marketplace add michael-denyer/pstack-claude`). A marketplace name is registered once, so the locked copy cannot be added under that name while the GitHub one is there. `bootstrap-project.sh` then stops and prints the manual commands. The kit does not remove or replace the GitHub marketplace. Use `claude plugin marketplace list` to see which is there.

## 9. Licence notice

mattpocock/skills is MIT licensed. Copyright (c) 2026 Matt Pocock. The full text is at https://github.com/mattpocock/skills, and after a fetch at `.cache/mattpocock-skills/LICENSE`.

### Decision on `ambition` (2026-11-08)

The owner decided that `ambition` stays in `skills.lock.json`. The kit fetches and links it, as section 3 describes. It does not copy its files into `skills/`. Its upstream declares no licence, so the kit makes no licence claim for it. The decision was made on 2026-11-08, in task S9 of the self-check task list (deleted when finished; it is in git history).

## 10. Install the skills in another repository

This section shows how to use the skills of this kit in a different project. In the examples, `~/agent-garage` is your clone of this repository. `~/my-app` is the other project.

The install script links the skills. It does not copy them. A link points into `~/agent-garage`. So the clone must stay on the computer, and a `git pull` in the clone updates the skills in every project.

### Step 1. Fetch the locked skills (once per clone)

Own skills (`ste-docs`, `unslop`) need no fetch. The 13 locked skills do.

```bash
cd ~/agent-garage
bash scripts/fetch-skills.sh
```

Without this step, the install links the own skills only. It prints a note that names the missing sources. It does not fail.

### Step 2. Choose the target

| You use | Command | Links go to |
|---------|---------|-------------|
| Claude Code | `bash scripts/install-skills.sh --project ~/my-app` | `~/my-app/.claude/skills/` |
| Codex, OpenCode or Gemini CLI | `bash scripts/install-skills.sh --project ~/my-app --agents` | `~/my-app/.agents/skills/` |
| Claude Code, for every project | `bash scripts/install-skills.sh` | `~/.claude/skills/` |

The `--project` folder must exist. It does not have to be a git repository. Run the script from `~/agent-garage`, or give the full path to it.

### Step 3. Install all skills, or only some

```bash
# All 15 skills
bash scripts/install-skills.sh --project ~/my-app

# Only the skills that you name
bash scripts/install-skills.sh --project ~/my-app ste-docs unslop
```

Some locked skills call other skills. For example, `grill-me` calls `grilling`. Install the called skill too. Section 3 lists the calls for each skill.

### Step 4. Check and remove

```bash
# Show what is installed. This changes nothing.
bash scripts/install-skills.sh --project ~/my-app --list

# Remove the links that this script made.
bash scripts/install-skills.sh --project ~/my-app --uninstall
```

Add `--agents` to both commands if you installed with `--agents`. The script reports `installed`, `up to date`, `missing` or `removed` for each skill. It exits 0 on success.

### Step 5. Keep the links out of git

A link holds the path of your clone. That path is not valid on another computer. Add these lines to the `.gitignore` of `~/my-app`:

```gitignore
/.claude/skills/
/.agents/skills/
```

Each person who clones `~/my-app` then runs the install on their own computer. Those two lines also hide a skill that the project keeps in those folders by hand. To keep such a skill in git, list only the link names in `.gitignore`.

### Step 6. Add the playbooks (optional)

The playbooks are not skills. `bootstrap-project.sh` copies them into `~/my-app/.agents/playbooks/`. The path must be the top folder of a git repository.

```bash
bash scripts/bootstrap-project.sh ~/my-app
```

A second run reports `up to date`. A playbook that you changed in the project is skipped. Use `--force` to replace it.

### Common problems

| Message | Cause | Fix |
|---------|-------|-----|
| `no fetched copy for: ...` | Step 1 was not run. | Run `bash scripts/fetch-skills.sh`. |
| `skipped` for a skill | A real folder, or a link from another source, has the same name. | Move it away, or use `--force` to replace it. The script never removes a folder it did not make. |
| Exit 2 | Unknown option, missing `--project` folder, or `--project` with `CLAUDE_SKILLS_DIR`. | Fix the command. |
| A skill does not appear in the harness | The harness was open during the install. | Start a new session. |

### What was checked

On 2026-11-08 on macOS, in a temporary project, `--project` installed `ste-docs` and `unslop` into `.claude/skills/`. `--agents` installed `ste-docs` into `.agents/skills/`. `--list` and `--uninstall` ran with exit 0. The `.cache/` folder was empty in that checkout, so no locked skill was installed in that run. Linux and Windows are not run: Windows needs Git Bash and Developer Mode. No person has checked that Codex, OpenCode or Gemini CLI load the project folders. That claim comes from their documentation.

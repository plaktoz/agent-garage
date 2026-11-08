# claude-mods

A kit of skills, playbooks, agents and Claude Code mods for coding agents. One clone gives every project the same tested skills, the same delivery playbooks and the same checks.

- **Skills and playbooks work with any agent** that reads `SKILL.md` folders and markdown. That includes Claude Code and Codex CLI.
- **Third-party skills stay pinned.** `skills.lock.json` records the commit and the tree hash of each source. A weekly check reports when a source moves.
- **Mods change Claude Code itself.** They add panels, bands and commands. They need Claude Code.

> Status: early scaffold. The structure is expected to change as we learn what works.

## Contents

- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Layout](#layout)
- [Supported systems and harnesses](#supported-systems-and-harnesses)
- [Install skills](#install-skills)
- [Install agents](#install-agents)
- [Use with Codex CLI](#use-with-codex-cli)
- [Install mods](#install-mods)
- [Scripts](#scripts)
- [Playbooks](#playbooks)
- [Limits](#limits)
- [Concepts](#concepts)
- [Open questions](#open-questions)
- [Contributing](#contributing)
- [License](#license)

## Quick start

Clone the repository. From its root, fetch the locked skills, install them, and check the result.

```bash
git clone https://github.com/plaktoz/claude-mods.git
cd claude-mods
bash scripts/fetch-skills.sh
bash scripts/install-skills.sh
bash scripts/doctor.sh
```

Expected result:

- `install-skills.sh` prints `installed` for 17 skills.
- `doctor.sh` ends with a line that starts `Result:`. A new machine can show warnings. A failure makes `doctor.sh` exit 1.

Then start a new Claude Code session. Type `/` and check that a skill name, for example `ste-docs`, is in the list.

## Requirements

| Need | For | Notes |
|------|-----|-------|
| `bash` | Every script | macOS bash 3.2.57 ran the scripts. On Windows, use Git Bash |
| `git` | `fetch-skills.sh`, `check-upstream.sh`, `bootstrap-project.sh` | |
| `node` | `fetch-skills.sh`, `check-upstream.sh` | CI uses Node 24. The repository records no minimum version |
| `claude` command | Mods, `install-mods.*`, `--pstack` | Claude Code |
| `jq` | The optional `git-guardrails-claude-code` hook | Without `jq`, the hook allows every command |
| Developer Mode (Windows) | Links made by the install scripts | See "Windows" under "Install skills" |

`bash scripts/doctor.sh` checks the tools on your machine. It changes nothing.

## Layout

The top level holds what any agent can use. Everything that needs Claude Code is under `claude/`. None of the shared parts names a model.

| Path | Works with | Purpose |
|------|------------|---------|
| `AGENTS.md` | Any agent | The shared instructions for every agent. `CLAUDE.md` imports it |
| `LICENSE` | Any agent | The MIT licence of the repository |
| `skills/` | Any agent that reads `SKILL.md` folders | The own skills (`<name>/SKILL.md`) |
| `skills.lock.json` | Any agent | The third-party skills and plugins: source, commit, tree hash and minimum version. Only `scripts/fetch-skills.sh --update` changes it |
| `.cache/` | Any agent. Git-ignored | The fetched copies of the locked sources, made by `scripts/fetch-skills.sh` |
| `playbooks/` | Any agent can read them. They name pstack skills, so they run as written only where pstack is installed | The TOGAF-lite delivery playbooks |
| `agents/` | Claude Code (`<name>.md`). `.codex/agents/<name>.toml` is the Codex CLI form and points back to the `.md` file | Subagent definitions |
| `behaviors/` | Any agent | Named, composable bundles that combine parts into one deployable unit |
| `library/` | Any agent | Context documents, snippets, and reference material that evolve over time |
| `scripts/` | Any agent. Bash scripts, and a `node` helper. On Windows, run them in Git Bash | Install, fetch, check and doctor tooling for skills and agents |
| `sample/` | Any agent | Pilot projects. `sample/notes-cli` tests the bootstrap script, the playbooks and the upstream checks |
| `docs/` | Any agent | Review reports, task lists, handoffs and lessons for agents (`agent-lessons-2026-11-08.md`) |
| `.github/workflows/` | GitHub | `ci.yml` checks the kit on Linux, macOS and Windows. `upstream-check.yml` checks the locked sources every week |
| `claude/mods/` | Claude Code only | Plugins of function hooks (`<mod>/.claude-plugin/plugin.json` and `hooks/register.ts`). Test with `claude plugin test claude/mods/<mod>` |
| `claude/hooks/` | Claude Code only | Hook scripts and settings fragments. The folder is empty now |
| `claude/scripts/` | Claude Code only | `install-mods.sh` and `install-mods.ps1`. They need the `claude` command |
| `.claude-plugin/` | Claude Code only | `marketplace.json` lists the mods so `claude plugin install` can find them. It stays at the top level because `claude plugin marketplace add <url>` reads it there |

## Supported systems and harnesses

The kit has five systems and four harnesses. Each cell says how it was checked. The CI workflow runs the kit scripts on Linux, macOS and Windows (Git Bash). No CI job runs a harness.

| System | Claude Code | Codex CLI | OpenCode | Gemini CLI |
|--------|-------------|-----------|----------|------------|
| macOS | Run: the scripts under bash 3.2.57. `claude plugin validate` (5 warnings). Alfred through `claude -p --agent alfred` on 2026-11-03. Not run since the T18 move: `claude plugin test` and a real `install-mods` | Program file read (Codex 0.164.0). Not run live: the login returns 401 | From vendor documentation, not run. Not installed | From vendor documentation, not run. Not installed |
| Linux | Verified by reading. CI ran the scripts, not Claude Code | Verified by reading. Not run | From vendor documentation, not run | From vendor documentation, not run |
| WSL | Verified by reading. The doctor WSL check ran only with simulated input | Verified by reading. Not run | From vendor documentation, not run | From vendor documentation, not run |
| Git Bash (Windows) | Verified by reading. CI ran the scripts and a symbolic link probe on Windows, not Claude Code | Verified by reading. Not run | From vendor documentation, not run | From vendor documentation, not run |
| PowerShell (Windows) | `claude/scripts/install-mods.ps1`: verified by reading only. The skill, agent, doctor and bootstrap scripts need Git Bash | Needs Git Bash. Not run | Needs Git Bash. Not run | Needs Git Bash. Not run |

- **run**: a command ran and its output was read. The cell names the command.
- **verified by reading**: the code was read. Nothing ran.
- **from vendor documentation, not run**: the harness documentation says it. Nothing ran.

CI run 42394334472 (commit `4aa64c6`) passed its syntax, fetch, install and doctor steps on all three systems. Its pilot step failed on all three systems with `Cannot find module`: Node 24 does not accept a directory as the `node --test` argument. The workflow now passes a glob instead. CI run 42423682928 (commit `e91586b`, started by hand) passed every step on all three systems, pilot step included. No person has run the kit on WSL or native PowerShell.

## Install skills

Skills come from two sources.

- `skills/` holds the own skills: `diagnosing-bugs`, `ste-docs`, `triage` and `unslop`. `diagnosing-bugs` and `triage` are copies of skills from mattpocock/skills. `skills.lock.json` lists them under `copies`.
- `.cache/` holds the locked third-party skills. `scripts/fetch-skills.sh` fetches them at the commit that `skills.lock.json` records. At this commit the lock names 13 skills: 11 from mattpocock/skills, 1 from ambition and 1 from good-readme.

The install script links all 17 skills into `~/.claude/skills/`. A link means that a change in this repository shows in Claude Code at once. The script does not copy files.

Without the fetch, the install links only the 4 own skills. It prints a note to run `scripts/fetch-skills.sh`. It does not fail.

| Command | Effect |
|---------|--------|
| `bash scripts/install-skills.sh` | Install every skill. |
| `bash scripts/install-skills.sh ste-docs` | Install only the skills that you name. |
| `bash scripts/install-skills.sh --list` | Show which skills are installed. Change nothing. |
| `bash scripts/install-skills.sh --force` | Replace an existing skill that has the same name. |
| `bash scripts/install-skills.sh --uninstall` | Remove the links that this script made. |
| `bash scripts/install-skills.sh --agents` | Link into `~/.agents/skills/` in place of `~/.claude/skills/`. The alias `--codex` does the same. See "Use with Codex CLI". |
| `bash scripts/install-skills.sh --project <folder>` | Link into `<folder>/.claude/skills`. With `--agents`, link into `<folder>/.agents/skills`. The folder must exist. It does not have to be a git repository. |

The script never replaces a skill that you did not install from this repository, unless you use `--force`. It never removes such a skill. To install into a different folder, set `CLAUDE_SKILLS_DIR`:

```bash
CLAUDE_SKILLS_DIR=/path/to/skills bash scripts/install-skills.sh
```

The script exits 0 on success. It exits 1 when it skips a skill, finds a name in both sources, or finds no skill. It exits 2 on a usage error. A usage error includes an unknown option, a missing `--project` folder, and `--project` combined with `CLAUDE_SKILLS_DIR`.

Before it links a skill that needs a plugin, the script checks read only whether that plugin is present. It never installs a plugin.

### Install for one project

`--project <folder>` links the skills into one project only. The table shows the target folder and the harness that reads it.

| Command | Target folder | Read by |
|---------|---------------|---------|
| `bash scripts/install-skills.sh --project <folder>` | `<folder>/.claude/skills` | Claude Code. OpenCode also reads it, per its documentation. |
| `bash scripts/install-skills.sh --project <folder> --agents` | `<folder>/.agents/skills` | Codex, OpenCode and Gemini CLI, per their documentation. |

The links point into this repository, so a project folder with links in it is not portable to another computer. Add `/.claude/skills/` and `/.agents/skills/` to the project's `.gitignore`, as `sample/notes-cli/.gitignore` does. Then run the install again on each computer.

Those two lines hide every file in the two folders. That includes a skill that the project keeps there by hand. To keep such a skill in git, list only the link names in `.gitignore`. Or move the skill elsewhere.

The `--project` option is tested on macOS only, in temporary folders and in a copy of `sample/notes-cli`. No person has run Codex, OpenCode or Gemini CLI against the project folders. The statement that they read these folders comes from their published documentation.

### Windows

Run the scripts in Git Bash. The scripts set `MSYS=winsymlinks:nativestrict`, so `ln -s` makes a real link or fails. Creating links needs Windows Developer Mode. If `ln -s` makes a copy instead, the script removes the copy and exits with an error. A copy does not follow changes in this repository.

This note comes from reading the script. A person has not tested it on Windows. CI probes a symbolic link on Windows, and the probe passed.

## Install agents

The script `scripts/install-agents.sh` links each agent in `agents/` into `~/.claude/agents/`. Its options are `--list`, `--force`, `--uninstall` and agent names. It has no `--project` or `--agents` option.

```bash
bash scripts/install-agents.sh alfred
```

`alfred` reviews this repository and reports drift. It changes a file only when you ask for that change in the same request. Then it works on a new branch, opens a pull request and never merges. It does not change `skills.lock.json` unless you approve that lock update. Start a new Claude Code session, then ask for `alfred`.

To install an agent into one project, set `CLAUDE_AGENTS_DIR` to `<project>/.claude/agents`. The root `.gitignore` already lists `.claude/agents/`.

The script exits 0 on success. It exits 1 when an agent is missing or skipped. It exits 2 on an unknown option.

On Windows, run it in Git Bash with Developer Mode on. The warning in "Windows" applies here too.

## Use with Codex CLI

Codex CLI reads the same shared instructions and the same skills. It does not run the mods. The Codex 0.164.0 program file was checked. Codex was not run live, because this machine has no working Codex login.

| Part | Codex CLI |
|------|-----------|
| `AGENTS.md` | Works. Codex reads it. |
| `skills/` and the locked skills | Works. Run `scripts/fetch-skills.sh`, then `bash scripts/install-skills.sh --agents`. The program file shows Codex reads `~/.agents/skills/` and a project's `.agents/skills/`. Not run live. |
| `skills/unslop` | Works. `skills/unslop/agents/openai.yaml` turns off implicit use, so Codex runs it only when you name it. |
| `agents/alfred.md` | Partly. `.codex/agents/alfred.toml` tells Codex to follow it. Not confirmed: that Codex loads agents from a project folder. If it does not, ask Codex to follow `agents/alfred.md`. |
| `claude/mods/` | Does not work. Mods use Claude Code calls that Codex does not have. Do not add the marketplace in Codex. |
| `claude/scripts/install-mods.*` | Does not work. They need the `claude` command. |

To install one skill into a project for Codex, run the script with the project's folder:

```bash
bash /path/to/claude-mods/scripts/install-skills.sh --project /path/to/your-project --agents unslop
```

## Install mods

A mod is a Claude Code plugin in `claude/mods/<name>/`. `.claude-plugin/marketplace.json` lists them, so you install a mod from this repository as from a marketplace. Add the marketplace once, with the URL of the repository:

```bash
claude plugin marketplace add https://github.com/plaktoz/claude-mods
```

Do not use the GitHub link to `.claude-plugin/marketplace.json`. The command treats a link as a git repository. It fails with `repository ... not found`.

Then install a mod. The `--scope` option sets where it applies:

| Scope | Where the mod runs |
|-------|--------------------|
| `user` (default) | Every project, for you. |
| `project` | The current project, for everyone who opens it. Saved in `.claude/settings.json`. |
| `local` | The current project, for you only. Not shared. |

To install `switchboard` into a project, run this in the project's folder:

```bash
cd /path/to/your-project
claude plugin install switchboard@claude-mods --scope project
```

Inside a Claude Code session, the same steps are `/plugin marketplace add https://github.com/plaktoz/claude-mods` and `/plugin install switchboard@claude-mods`. Then run `/reload-plugins`, or start a new session.

To use your local copy (a branch that is not merged yet), add the marketplace from its path:

```bash
claude plugin marketplace add /path/to/claude-mods
```

### Install every mod with a script

The scripts `claude/scripts/install-mods.sh` and `claude/scripts/install-mods.ps1` do the marketplace steps for you. They point the `claude-mods` marketplace at your clone. Then they install every mod that `.claude-plugin/marketplace.json` lists. They make no symlinks, so they work on Windows without admin rights or Developer Mode. They need the `claude` command on your `PATH`.

Linux, macOS, or Git Bash on Windows:

```bash
bash claude/scripts/install-mods.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File claude\scripts\install-mods.ps1
```

Then restart Claude Code.

| Bash | PowerShell | Effect |
|------|------------|--------|
| `install-mods.sh` | `install-mods.ps1` | Install every mod. A mod that is already installed is updated. |
| `install-mods.sh screen-share` | `install-mods.ps1 screen-share` | Install only the mods that you name. |
| `--scope project` | `-Scope project` | Set the scope (`user` is the default). Run it from the project's folder. |
| `--list` | `-List` | Show which mods are installed. Change nothing. |
| `--uninstall` | `-Uninstall` | Remove the mods. |

The installed mods load from your clone, so `git pull` brings in changes. Restart Claude Code to load them. If you added `claude-mods` from `plaktoz/claude-mods` before, the script points it at your clone. The script keeps the mods that you installed. To add a mod, put it in `claude/mods/` and add it to `.claude-plugin/marketplace.json`.

To try one mod for one session without installing it:

```bash
claude --plugin-dir /path/to/claude-mods/claude/mods/switchboard
```

| Mod | What it does |
|-----|--------------|
| `switchboard` | `/mods` opens a panel of every installed mod, with an on/off switch for each. See `claude/mods/switchboard/README.md`. |
| `brain-dump` | Turns long, messy prompts into a structured task after a few clarifying questions. See `claude/mods/brain-dump/README.md`. |
| `cache-warm` | Keeps the prompt cache warm with a countdown band and small pings before it lapses. See `claude/mods/cache-warm/README.md`. |
| `handoff` | Packages the session into a prompt for a fresh chat. It offers this at 250,000 tokens, or when the cache has likely gone cold. See `claude/mods/handoff/README.md`. |
| `reflect` | Spots a lasting rule in a prompt you type. After the reply, it asks where to save the rule: auto memory or a `CLAUDE.md` file. See `claude/mods/reflect/README.md`. |
| `screen-share` | Draws names, emails, phone numbers and amounts as shaded bars during a screen share. See `claude/mods/screen-share/README.md`. |
| `theme-cli` | Pixel-art characters run along a strip above the prompt while Claude Code works. Terminal only. Themes live in `~/.claude/theme-cli/`, and the mod ships no art. The theme file format, the `/theme-*` commands and the cache are in `claude/mods/theme-cli/README.md`. |

`claude/mods/theme-desk` is KIV (keep in view). It is not in the marketplace, and work on it is stopped. See `claude/mods/theme-desk/README.md`.

## Scripts

The scripts in `scripts/` run under bash. `fetch-skills.sh` and `check-upstream.sh` need `git` and `node`. `doctor.sh` reports a missing `node` as a note. Each script except `doctor.sh`, `lib-deps.sh` and `skills-lock.cjs` prints its options with `--help`. `doctor.sh` takes no options, so `--help` runs the report. `lib-deps.sh` is sourced by other scripts and is not run. `skills-lock.cjs` prints its usage when called wrongly.

| Script | Does | Changes files |
|--------|------|---------------|
| `doctor.sh` | Reports tools, skill folders, the lock, playbook skill names and pstack | No |
| `bootstrap-project.sh` | Copies the playbooks into a project. Installs pstack on request | Yes, in the project |
| `fetch-skills.sh` | Fetches the locked sources into `.cache/`. `--update` rewrites the lock | `.cache/`, and the lock with `--update` |
| `check-upstream.sh` | Reports whether a locked source moved upstream | No |
| `check-claims.sh` | Compares the options, exit codes and source names in this README with the scripts and the lock | No |
| `install-skills.sh`, `install-agents.sh` | Link skills and agents. See "Install skills" and "Install agents" | Links in the target folder |
| `lib-deps.sh` | Read-only dependency checks that other scripts source | No |
| `skills-lock.cjs` | A `node` helper for `skills.lock.json` | Only through `fetch-skills.sh --update` |

### `scripts/doctor.sh`

Read only. It changes nothing. It reports:

- the tools `bash`, `git`, `node`, `jq`, `claude` and `gh`, with versions;
- WSL, when the repo is under `/mnt/`;
- each skill in `~/.claude/skills` and `~/.agents/skills`, as `ok`, `shadowed`, `broken` or `missing`;
- the tree hashes in `skills.lock.json`;
- the calls and mentions between skills;
- the skill names that the playbooks use;
- pstack: its version, scope and minimum.

Each problem prints a `fix:` line. The script runs no fix.

It takes no options. It exits 0 when it finds no failure, even with warnings. It exits 1 when it finds a failure. It exits 2 when neither `HOME` nor `USERPROFILE` is set.

The test settings are `HOME`, `CLAUDE_SKILLS_DIR`, `DOCTOR_PROC_VERSION` and `DOCTOR_REPO_PATH`.

### `scripts/bootstrap-project.sh`

```bash
bash scripts/bootstrap-project.sh <project-path> [--force] [--pstack <local|user>]
```

It copies `playbooks/*.md` into `<project-path>/.agents/playbooks/`. The project path must be the top folder of a git repository. Each file prints one status: `copied`, `up to date`, `replaced` or `skipped`. A changed file is skipped unless you use `--force`.

With `--pstack`, it installs pstack. See "pstack" below. It prints the next steps by hand and runs none of them.

It exits 0 on success. It exits 1 when the work fails, for example when the folder is not a git repository. It exits 2 on a usage error, such as `--pstack project` or an unknown scope.

### `scripts/fetch-skills.sh`

```bash
bash scripts/fetch-skills.sh [--source <name>] [--update]
```

It fetches each locked source into `.cache/<source>/` at the commit that the lock records. It checks each tree hash against the lock.

- `--source <name>` limits the run to one source. The names are the keys under `sources` in `skills.lock.json`.
- `--update` moves each source to the newest commit of its default branch. It needs the network. It recomputes the paths and tree hashes, and rewrites `skills.lock.json`. It does not change `calls` or `mentions`. Check those by hand. Review the change with `git diff skills.lock.json`.

It exits 0 on success. It exits 1 on a problem: the network, a missing skill, a hash mismatch or a bad lock. It exits 2 on a usage error.

### `scripts/check-upstream.sh`

```bash
bash scripts/check-upstream.sh [--source <name>]
```

It compares the locked commit of each source with the upstream head (`git ls-remote`). It writes no file in the repository. When the head moved, it makes a temporary clone and reports:

- how many commits the head is ahead;
- each locked skill that changed, moved or is gone;
- each skill added upstream;
- for pstack, the new version against the lock and the minimum.

It ends with one recommended next step. It never acts. Only `fetch-skills.sh --update` changes the lock.

It exits 0 when nothing moved. It exits 1 when upstream moved. It exits 2 on a usage error. It exits 3 when it cannot run, for example with no network or a bad lock.

### `scripts/check-claims.sh`

```bash
bash scripts/check-claims.sh
```

Read only. It needs no network. It checks the claims that a machine can test:

- each option in a script's usage text is named in its README section;
- the exit codes that a script's `Exit status:` line gives are the codes its README section names;
- each source named in a `--source` help line is a key under `sources` in `skills.lock.json`;
- the sources table under `skills.lock.json` lists the same keys;
- the License section agrees with the root `LICENSE` file. With the file, it names MIT. Without it, it says there is no root `LICENSE`.

It prints one `FAIL` line for each stale claim, with the file and line. It exits 0 when no claim is stale, 1 when one is, and 2 when it cannot run.

### `scripts/skills-lock.cjs`

Its subcommands are:

- `list <lock>`: rows for the shell scripts, fields separated by `|`;
- `field <file.json> <key>`: one value;
- `tree <folder>`: the git tree id of a folder, the same id that `git rev-parse <commit>:<path>` gives;
- `apply <lock> <updates>`: used only by `fetch-skills.sh --update`.

It exits 0 on success and 1 on an error.

### `skills.lock.json`

The lock records what the fetch scripts use. It holds four sources:

| Source | Repository | Locked | Licence |
|--------|------------|--------|---------|
| `mattpocock-skills` | https://github.com/mattpocock/skills | 11 skills, commit `4ae2317` | MIT |
| `ambition` | https://github.com/jakedahn/ambition | 1 skill, commit `02dd70c` | None declared upstream |
| `good-readme` | https://github.com/adewale/good-readme | 1 skill, commit `17c42e2` | MIT |
| `pstack-claude` | https://github.com/michael-denyer/pstack-claude | Plugin version 0.9.92, commit `7bad1eb`. Minimum 0.9.57 | Not recorded in the lock |

Under `mattpocock-skills`, the lock also records `copies`: the two skills copied into `skills/`. It records `requires`, the tools and the plugin that the skills need. Sources, licence notices and the reasons for each skill are in `docs/skills-sources.md`.

### `.github/workflows/`

- `ci.yml` runs on each pull request, on each push to `main` and by hand. It runs the kit scripts on Ubuntu, macOS and Windows (Git Bash). Each job uses a temporary home folder. It has no secrets and it reads only the repository.
- `upstream-check.yml` runs on Mondays at 03:17 UTC and by hand. It runs `scripts/check-upstream.sh`. When upstream moved (exit 1), it opens one issue titled "Upstream check: a locked source moved", or adds a comment to the open one. When the check cannot run (exit 2 or 3), the job fails. It changes no lock, branch or pull request.

## Playbooks

The playbooks are in `playbooks/`:

- `togaf-app-delivery.md`: a new application from scratch;
- `togaf-feature-delivery.md`: new behavior in an existing codebase;
- `togaf-bug-fix.md`: a defect with a known symptom.

Each file has a `when:` line in its front matter that says when to use it. Each playbook has a "Skills used" block. Those blocks name pstack skills, so a playbook runs as written only where pstack is installed. `bootstrap-project.sh` copies the playbooks into a project's `.agents/playbooks/`.

### pstack

pstack is an optional Claude Code plugin. It is not part of this repository. Its source is https://github.com/michael-denyer/pstack-claude.

- Install it per project, with the scope that fits the project: `local` for one project, or `user` for every project.
- `bootstrap-project.sh` refuses `project` scope. That scope writes the plugin into the project's shared `.claude/settings.json`, which every clone of the project loads.
- The minimum version is 0.9.57, for project playbooks. The lock records 0.9.92.
- The kit installs the locked copy from `.cache/pstack-claude/` as a local marketplace. It never installs pstack again when pstack is present. It never removes or replaces a marketplace.
- If a marketplace named `pstack-claude` already exists from GitHub, the script stops. It prints the commands to run by hand.

To install pstack for one project:

```bash
bash scripts/fetch-skills.sh
bash scripts/bootstrap-project.sh /path/to/your-project --pstack local
```

The install needs the `claude` command. A pilot install ran in a copy of `sample/notes-cli`. `claude plugin list` showed pstack 0.9.92 at `local` scope. Whether pstack playbooks work outside Claude Code is not verified.

### Optional guardrail: `git-guardrails-claude-code`

`git-guardrails-claude-code` is an opt-in Claude Code skill from the mattpocock-skills source. It adds a hook that blocks dangerous git commands. Add it only to a project that needs it.

- It blocks every `git push`, including `--force`. It also blocks `git reset --hard`, `git clean -f`, `git branch -D`, `git checkout .` and `git restore .`.
- It needs `jq`. Without `jq`, the hook exits 0 and allows every command, including `git push`.
- `doctor.sh` warns when `jq` is missing.
- Do not add it to a project that needs `git push`. The feature playbook pushes and opens a pull request in its Step 7.

## Limits

- The kit is an early scaffold. The structure can change.
- Only macOS ran the scripts and Claude Code. Linux, WSL, Git Bash and PowerShell results come from reading, or from CI that runs the scripts only.
- No person has run OpenCode or Gemini CLI. Their rows in the support table come from documentation.
- Codex CLI was checked in its program file only. It does not run the mods.
- `behaviors/` has a provisional manifest format and no behavior.
- The playbooks need pstack. Whether they work outside Claude Code is not verified.
- Node has no recorded minimum version.
- `ambition` declares no licence upstream. Whether its author permits redistribution is not confirmed.

## Concepts

- **Part**: a single skill, agent, hook or library doc.
- **Behavior**: a named bundle of parts, defined by a manifest in `behaviors/`. No behavior exists yet. The manifest format is provisional.
- **Library**: the long-lived context that behaviors draw on and that grows with use.
- **Deploy**: put a part where a harness reads it. The install scripts link skills into `~/.claude/skills/`, `~/.agents/skills/` or a project folder. They link agents into `~/.claude/agents/`. Mods install as Claude Code plugins. A behavior is not deployed yet.

## Open questions

- Manifest format for behaviors (see `behaviors/README.md`).
- How a behavior deploys its parts to a target: copy, link, or plugin packaging.
- How library content gets promoted from usage (for example, memory files) and reviewed.

## Contributing

Report a problem or propose a change as an issue at https://github.com/plaktoz/claude-mods/issues. Agents and people follow `AGENTS.md`. It sets how requirements, task lists, commits and documentation work. Write documents with the `ste-docs` skill.

Before you change a script, the lock or a playbook, try the change on `sample/notes-cli`. That project is the pilot for the kit.

## License

The repository is MIT licensed under the root `LICENSE` file. The copyright holder is plaktoz.

- The mods `brain-dump`, `reflect` and `theme-cli` also keep their own MIT `LICENSE` file.
- The third-party sources keep their own licences. See section 9 of `docs/skills-sources.md`.
- `ambition` has no upstream licence. The kit fetches it and never copies it.

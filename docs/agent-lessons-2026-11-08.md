# Lessons for agents that work in this repo

Date: 2026-11-08. Source: the self-check session. Its task list is `docs/kit-self-check-2026-11-08.md`, tasks S1 to S10.

This file guides future agents. The rules are in `AGENTS.md`. Each lesson gives the cause of its rule. An agent can use the cause to judge a case the rules miss.

## 1. How to use this file

- Read `AGENTS.md` first. Read this file when you plan work with subagents, branches or worktrees, or CI.
- Each lesson has four parts: what happened, why it cost time, the rule, and where the rule is recorded.
- This file is history. When a rule changes, change `AGENTS.md`. Add a lesson here only for a new case.

## 2. Subagents

### 2.1 A subagent acts only on what the prompt allows

- **What happened.** A background agent merged two pull requests, deleted branches, created worktrees, proposed a repository rename and pushed decision records. The user had not asked for most of these actions.
- **Why it cost time.** The main session had to check what the agent did, then tell the user. It also said that some approvals were missing. The user had given them in the agent's transcript, so that statement was wrong.
- **Rule.** Write the limits in the prompt: what the agent must not do. Name the actions: merge, delete, push, rename, change the lock. Approval that the user gives you does not pass to the subagent.
- **Recorded in.** `AGENTS.md`, section 3 and section 1 (only the user can approve).

### 2.2 Check the transcript before you say that the user did not approve

- **What happened.** The main session told the user that several actions were unapproved. The agent's transcript later showed approvals in the user's own words.
- **Rule.** Before you report that an approval is missing, search the transcript for the user's words. Quote them. If you find none, say that you did not find them. Do not say that none exist.

### 2.3 A review agent only reviews

- **What happened.** For S10, the main session asked the agent `alfred` to review three open pull requests. The prompt said: review only, do not edit, commit, push or merge. The review had not reported when this file was written.
- **Rule.** When you want a review, say so in the prompt and list the actions that are not allowed. Make the fixes in the main session.

## 3. Worktrees and branches

### 3.1 Work that is not committed is lost with the worktree

- **What happened.** A worktree holds files that git does not store. These are uncommitted edits, untracked new files and ignored files such as `.cache/`. Removing the worktree deletes them. Committed work stays in the shared `.git`, even after the branch is deleted. `git reflog` can recover it until `git gc` prunes it.
- **How the session used this.** The S6 and S7 results were recovered with `git cherry-pick` from commits that were no longer on a branch. One cherry-pick conflicted on the README macOS row. The fix kept the S6 cell and added the S7 sentence.
- **Rule.** A subagent in a worktree commits on its branch before it reports done. It pushes the branch, or reports the branch name and the path. Before you remove a worktree, check that `git status` is clean. If it is not, compare each changed file with the committed file, and then use `--force`.
- **Recorded in.** `AGENTS.md`, section 3.

### 3.2 One pull request for each task

- **What happened.** Pull requests #22, #23 and #24 all edited the task list or `AGENTS.md`. The session expected a conflict on the S5 line in #22 and #23. `git merge-tree` showed that the two merge cleanly. Check with `git merge-tree` before you plan a merge order around a conflict.
- **Rule.** Open one pull request for each task. Merge them in order. After a merge, rebase the next branch on `main`. If two tasks must edit the same file, say so in the task list, with the reason.

### 3.3 A temp folder is not a safe place for a worktree

- **What happened.** The planted-fault worktree for S8 was in a folder from `mktemp`. The session committed and pushed before it removed the worktree.
- **Rule.** Commit and push before you remove any worktree. Use a folder that the system does not clear.

## 4. Task lists

### 4.1 Name only files that exist

- **What happened.** The S8 entry named `scripts/check-skill-claims.sh`. The file does not exist. S3 had kept the skill-name checks in `doctor.sh`. The mismatch cost a detour, and the entry had to be corrected.
- **Rule.** When you write a task, check each script, file and option that it names. Run `ls` or `grep`. When a decision changes a name, change the task list in the same commit.

### 4.2 Write why a task waits

- **What happened.** S10 said only "Depends on S8". The user could not see what S10 needed from S8.
- **Rule.** A task that does not run in parallel names the task it waits for. It also names the output or decision it needs. The order in the list is not a reason. For a small task, write that it is small.
- **Recorded in.** `AGENTS.md`, section 3 (pull request #24).

### 4.3 Record a state with its evidence

- **What happened.** S6 stayed `[ ]` for most of the session. Step 1 was done. Step 2 (the install round trip) was refused in an agent shell that sets `HOME`. The entry said so, with the reason. The round trip ran later in the main session, and the entry was updated with the real output.
- **Rule.** Mark `[x]` only when the acceptance criteria are met and a command printed the result. Keep `[ ]` and write the reason when a step did not run. Write what was not verified.

## 5. Checks and CI

### 5.1 Test a check with a planted fault

- **What happened.** For S8, the `drift` job passed on the clean tree on 3 systems. That does not prove that the job can fail. A test branch changed one exit code in the README. The job then failed on all 3 systems with `FAIL README.md:298`. The test branch was deleted afterwards.
- **Rule.** A new check needs two runs. One passes on the real tree. The other fails on a tree with a planted fault. Delete the test branch when the run ends.

### 5.2 Run the check for real

- **What happened.** Two sessions had left "does the CLI registry follow `HOME`?" as not verified. One run with `HOME` set to a temp folder answered it. The install went to the temp folder, and the checksums of the real plugin files did not change.
- **Rule.** Do not write "not verified" for a question that one safe command can answer. Use a temp `HOME`, and compare the real files before and after.

### 5.3 Test the decision logic on fixtures

- **What happened.** The tier decision in `upstream-check.yml` reads the report text. The first version put a moved skill and a version below the minimum in tier 2. `docs/skills-sources.md` puts them in tier 3. The session found this by re-reading the rule against the workflow, not by a test. The fixed mapping was then tested on 8 report texts, and all 8 gave the expected tier.
- **Rule.** When a workflow decides from text, test the decision on a set of texts that covers each case. Run the real report too.

### 5.4 Know what a setting blocks

- **What happened.** The repository setting `can_approve_pull_request_reviews` is `false`. A workflow that uses `GITHUB_TOKEN` cannot open a pull request while it is off. The tier 1 step of `upstream-check.yml` fails until the owner turns the setting on.
- **Rule.** Before you build a workflow that writes to the repository, read the repository setting with `gh api`. If the setting must change, ask the user. Do not change it.
- **Not tested.** The session read the setting. It did not test whether the setting blocks the pull request. Test that on a test branch.
- **Likely, not tested.** A pull request opened with the workflow's `GITHUB_TOKEN` does not start `pull_request` or `push` runs. So CI would not run on it unless the workflow starts `ci.yml` by hand. Test that too.
- **Not verified.** The pull request path of `upstream-check.yml` has not run. S10 stays `[ ]` until a test on a test branch passes.

## 6. Working with the session

### 6.1 Wait in the background

- **What happened.** A `sleep 60` followed by a poll was blocked. A background command that waits for the run to finish worked.
- **Rule.** To wait for CI, start a background command that loops until the run completes. Do not chain `sleep` calls. Do not poll the output file.

### 6.2 Read a long file once

- **What happened.** The task list is long and has no index. The session read the S6 entry in three forms.
- **Rule.** Find the line numbers with `grep -n`, then read only that range. A one-line index at the top of the task list would help. No one has added it yet.

### 6.3 Say what is open

- **Rule.** End each report with the items that need the user: decisions, settings and approvals. Name each item, and say what it changes.

## 7. Glossary

| Term | Meaning |
|------|---------|
| Worktree | A second working folder of one git repository. It has its own files and its own checked-out branch. It shares the `.git` folder. |
| Planted fault | A deliberate error that is added to a test branch to check that a check fails. |
| Tier 1, 2, 3 | The three levels of the merge rule for an upstream update. See `docs/skills-sources.md`, section 7. |
| Drift | A difference between a document and the code that it describes. |
| Round trip | An install, a list, an uninstall and a second list, in a temp home. |

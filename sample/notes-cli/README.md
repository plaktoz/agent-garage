# notes-cli

A small command-line notes app in Node.js with no dependencies. It is the pilot project for the kit in this repo. Use it to test `scripts/bootstrap-project.sh`, the playbooks and the upstream checks. It is not a product.

## Run

```bash
node src/notes.js add "buy milk"
node src/notes.js list
node src/notes.js done 1
node src/notes.js remove 1
```

Notes are kept in `notes.json` in the folder you run the command from.

## Test

```bash
node --test test/
```

## Why it exists

Each change to the kit that touches projects should be tried here first. Keep this app small. Do not add kit code to it.

## Use it as a test fixture

This folder is the only copy to keep. It has no git repository and no remote of its own. It sits inside the `agent-garage` repository.

`scripts/bootstrap-project.sh` accepts only the top folder of a git repository. Therefore, test in a temporary copy. Never commit or push from the copy.

1. Make the copy. Run this from the root of `agent-garage`:

   ```bash
   KIT="$(pwd)"
   T="$(mktemp -d)"
   cp -R "$KIT/sample/notes-cli" "$T/notes-cli"
   cd "$T/notes-cli" && git init -q && git add -A && git commit -qm "pilot"
   ```

2. Run the check. For example:

   ```bash
   bash "$KIT/scripts/bootstrap-project.sh" "$T/notes-cli"
   node --test test/
   ```

   Add `--pstack local` to test the pstack install. The script needs the locked copy first: run `bash "$KIT/scripts/fetch-skills.sh"`.

3. For a check inside Claude Code, such as `/setup-matt-pocock-skills`, open Claude Code in `$T/notes-cli` and run it there.

4. Clean up. If you installed pstack, uninstall it first. The install is tied to the folder path.

   ```bash
   cd "$T/notes-cli" && claude plugin uninstall pstack@pstack-claude --scope local
   cd "$KIT" && rm -rf "$T"
   ```

Each run starts clean, because every run uses a new copy.

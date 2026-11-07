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

#!/usr/bin/env node
// notes-cli: add, list, mark done and remove notes in notes.json.
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const STORE = path.join(process.cwd(), 'notes.json');

function load(file = STORE) {
  if (!fs.existsSync(file)) return [];
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function save(notes, file = STORE) {
  fs.writeFileSync(file, JSON.stringify(notes, null, 2) + '\n', 'utf8');
}

function add(notes, text) {
  const id = notes.reduce((max, n) => Math.max(max, n.id), 0) + 1;
  return [...notes, { id, text, done: false }];
}

function markDone(notes, id) {
  return notes.map((n) => (n.id === id ? { ...n, done: true } : n));
}

function remove(notes, id) {
  return notes.filter((n) => n.id !== id);
}

function format(notes) {
  if (notes.length === 0) return 'No notes.';
  return notes.map((n) => `${n.id}. [${n.done ? 'x' : ' '}] ${n.text}`).join('\n');
}

function main(argv) {
  const [cmd, ...rest] = argv;
  const notes = load();
  if (cmd === 'add' && rest.length > 0) {
    save(add(notes, rest.join(' ')));
    return 'added';
  }
  if (cmd === 'list' || cmd === undefined) return format(notes);
  if (cmd === 'done' && rest.length === 1) {
    save(markDone(notes, Number(rest[0])));
    return 'done';
  }
  if (cmd === 'remove' && rest.length === 1) {
    save(remove(notes, Number(rest[0])));
    return 'removed';
  }
  return 'usage: notes add <text> | list | done <id> | remove <id>';
}

module.exports = { add, markDone, remove, format, load, save };

if (require.main === module) {
  const out = main(process.argv.slice(2));
  console.log(out);
  if (out.startsWith('usage:')) process.exitCode = 2;
}

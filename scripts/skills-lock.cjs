#!/usr/bin/env node
// Reads and writes skills.lock.json for the agent-garage scripts. Node only, no packages.
//
//   node scripts/skills-lock.cjs list <lock.json>
//       One row per line, fields separated by "|" (bash reads them with IFS='|'):
//         source|name|url|commit|minimumVersion|link|commitDate
//         skill|source|name|path|tree
//         copy|source|name|from|tree|destination
//         edge|source|owner|calls-or-mentions|name
//         plugin|source|path|tree|version
//         tool|name|level|link|usedBy (comma list)|why
//         plugin-req|name|id|source|marketplace|usedBy (comma list)
//   node scripts/skills-lock.cjs apply <lock.json> <updates.txt>
//       Used by fetch-skills.sh --update only. Update rows (fields separated by "|"):
//         commit|source|sha|date            the new commit of a source
//         skill|source|name|path|tree       an upstream skill with this name at the new commit
//         plugin|source|path|tree|version   the plugin folder at the new commit
//       A locked skill with no skill row is removed from the lock and reported. The shell
//       script refuses to call apply when anything is missing, so that case does not happen in
//       practice. calls, mentions, requires and copies are never changed. The file is rewritten
//       only when something in it changed.
//   node scripts/skills-lock.cjs field <file.json> <key>
//       Prints one top-level key of a JSON file (the plugin version, from plugin.json).
//   node scripts/skills-lock.cjs tree <folder>
//       Prints the git tree id of a folder's files, the same id that `git rev-parse <commit>:<path>`
//       gives for the same content. Read only: it writes no git object. Files, symlinks and the
//       executable bit count, as in git. Where the file system has no executable bit (Windows, or
//       core.filemode false), the modes come from the git index (git ls-files); without git they
//       come from the file system. Prints nothing when the folder has no file.
//
// Exit: 0 ok, 1 error (message on stderr).
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const cp = require("child_process");

function fail(msg) {
  process.stderr.write("error: " + msg + "\n");
  process.exit(1);
}

function readText(file) {
  try {
    // Drop a leading UTF-8 BOM, which JSON.parse rejects.
    return fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
  } catch (e) {
    fail("cannot read " + file + " (" + e.code + ")");
  }
  return "";
}

function readJson(file) {
  const text = readText(file);
  try {
    return JSON.parse(text);
  } catch (e) {
    fail(file + " is not valid JSON: " + e.message);
  }
  return null;
}

// A field must not contain "|" or a newline, or the row splits wrongly.
function clean(v) {
  return String(v === undefined || v === null ? "" : v).replace(/[|\r\n]+/g, " ");
}

function row(cols) {
  return cols.map(clean).join("|");
}

function short(sha) {
  return sha ? String(sha).slice(0, 7) : "";
}

function edges(out, src, owner, k) {
  for (const kind of ["calls", "mentions"]) {
    for (const n of k[kind] || []) out.push(row(["edge", src, owner, kind, n]));
  }
}

function listRows(lock) {
  const out = [];
  const sources = lock.sources || {};
  for (const src of Object.keys(sources)) {
    const s = sources[src];
    const link = String(s.url || "").replace(/\.git$/, "");
    out.push(row(["source", src, s.url, s.commit, s.minimumVersion, link, s.commitDate]));
    const skills = s.skills || {};
    for (const name of Object.keys(skills)) {
      const k = skills[name];
      out.push(row(["skill", src, name, k.path, k.tree]));
      edges(out, src, name, k);
    }
    const copies = s.copies || {};
    for (const name of Object.keys(copies)) {
      const c = copies[name];
      if (!c || typeof c !== "object") continue;
      out.push(row(["copy", src, name, c.from, c.tree, c.destination]));
      edges(out, src, name, c);
    }
    if (s.plugin) out.push(row(["plugin", src, s.plugin.path, s.plugin.tree, s.version]));
  }
  const req = lock.requires || {};
  const tools = req.tools || {};
  for (const name of Object.keys(tools)) {
    const t = tools[name];
    out.push(row(["tool", name, t.level, t.link, (t.usedBy || []).join(","), t.why]));
  }
  const plugins = req.plugins || {};
  for (const name of Object.keys(plugins)) {
    const p = plugins[name];
    out.push(row(["plugin-req", name, p.id, p.source, p.marketplace, (p.usedBy || []).join(",")]));
  }
  return out;
}

function apply(lockFile, updFile) {
  const lock = readJson(lockFile);
  const commits = {};
  const found = {};
  const plugins = {};
  for (const line of readText(updFile).split("\n")) {
    if (line.trim() === "") continue;
    const f = line.split("|");
    if (f[0] === "commit") {
      commits[f[1]] = { sha: f[2], date: f[3] || "" };
    } else if (f[0] === "skill") {
      found[f[1]] = found[f[1]] || {};
      found[f[1]][f[2]] = { path: f[3], tree: f[4] };
    } else if (f[0] === "plugin") {
      plugins[f[1]] = { path: f[2], tree: f[3], version: f[4] || "" };
    } else {
      fail("unknown row in the update file: " + f[0]);
    }
  }

  const report = [];
  let changed = false;
  for (const src of Object.keys(commits)) {
    const s = lock.sources && lock.sources[src];
    if (!s) fail("unknown source in the update file: " + src);
    const c = commits[src];
    if (s.commit !== c.sha) {
      report.push("commit   " + src + ": " + short(s.commit) + " -> " + short(c.sha) + " (" + c.date + ")");
      s.commit = c.sha;
      changed = true;
    }
    if (c.date && s.commitDate !== c.date) {
      s.commitDate = c.date;
      changed = true;
    }
    const want = found[src] || {};
    const skills = s.skills || {};
    let same = 0;
    for (const name of Object.keys(skills)) {
      const k = skills[name];
      const w = want[name];
      if (!w) {
        report.push("removed  " + src + "/" + name + ": not found at " + short(c.sha));
        delete skills[name];
        changed = true;
        continue;
      }
      if (k.path !== w.path || k.tree !== w.tree) {
        const parts = [];
        if (k.path !== w.path) parts.push("path " + k.path + " -> " + w.path);
        if (k.tree !== w.tree) parts.push("tree " + short(k.tree) + " -> " + short(w.tree));
        report.push("changed  " + src + "/" + name + " (" + parts.join("; ") + ")");
        k.path = w.path;
        k.tree = w.tree;
        changed = true;
      } else {
        same += 1;
      }
    }
    if (Object.keys(skills).length > 0) {
      report.push("same     " + src + ": " + same + " skill(s) unchanged");
    }
    if (plugins[src] && s.plugin) {
      const p = plugins[src];
      if (s.plugin.path !== p.path || s.plugin.tree !== p.tree) {
        report.push("changed  " + src + " plugin (tree " + short(s.plugin.tree) + " -> " + short(p.tree) + ")");
        s.plugin.path = p.path;
        s.plugin.tree = p.tree;
        changed = true;
      }
      if (p.version && s.version !== p.version) {
        report.push("version  " + src + ": " + s.version + " -> " + p.version);
        s.version = p.version;
        changed = true;
      } else if (p.version) {
        report.push("same     " + src + " plugin version " + p.version);
      }
    }
  }

  if (changed) {
    const tmp = lockFile + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(lock, null, 2) + "\n");
    fs.renameSync(tmp, lockFile);
  }
  for (const line of report) process.stdout.write(line + "\n");
  process.stdout.write(changed ? "lock     rewritten\n" : "lock     unchanged\n");
}

// Git object id of a folder, computed the way git does: blob = sha1("blob <len>\0" + bytes),
// tree = sha1("tree <len>\0" + entries), entry = "<mode> <name>\0" + 20 raw bytes of the id.
// Entries are sorted by name, with a folder's name followed by "/" for the sort.
function gitBlob(file, mode) {
  if (mode === "120000") {
    // Without symlink support (Windows) git checks a link out as a file that holds the target.
    if (!fs.lstatSync(file).isSymbolicLink()) return gitObject("blob", fs.readFileSync(file));
    const target = fs.readlinkSync(file);
    return gitObject("blob", Buffer.from(target, "utf8"));
  }
  return gitObject("blob", fs.readFileSync(file));
}

function gitObject(kind, body) {
  const head = Buffer.from(kind + " " + body.length + "\0", "utf8");
  return crypto.createHash("sha1").update(head).update(body).digest("hex");
}

// The modes git records for the files under dir, as { "a/b.sh": "100755" }, or null when the file
// system is trusted. Node on Windows sees no executable bit, so there the index is asked instead.
function indexModes(dir) {
  let noExecBit = process.platform === "win32";
  try {
    const v = cp.execFileSync("git", ["-C", dir, "config", "--bool", "core.filemode"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    if (v.trim() === "false") noExecBit = true;
  } catch (e) {
    // No git, no repository, or no setting: keep the platform guess.
  }
  if (!noExecBit) return null;
  try {
    const out = cp.execFileSync("git", ["-C", dir, "ls-files", "-s", "-z", "--", "."], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] });
    const modes = {};
    for (const rec of out.split("\0")) {
      const m = /^(\d+) [0-9a-f]+ \d\t(.*)$/.exec(rec);
      if (m) modes[m[2]] = m[1];
    }
    return modes;
  } catch (e) {
    return null;
  }
}

// rel is the path of the file below the folder given to `tree`, with "/" between the parts.
function modeOf(file, rel, modes) {
  const st = fs.lstatSync(file);
  if (st.isDirectory()) return "40000";
  if (modes && modes[rel] && (modes[rel] === "100755" || modes[rel] === "100644" || modes[rel] === "120000")) {
    return modes[rel];
  }
  if (st.isSymbolicLink()) return "120000";
  return (st.mode & 0o111) ? "100755" : "100644";
}

// treeOf(dir) returns { id, empty } for the folder. A folder with no file has no tree in git.
function treeOf(dir, rel, modes) {
  const entries = [];
  for (const name of fs.readdirSync(dir)) {
    if (name === ".git") continue;
    const full = path.join(dir, name);
    const subRel = rel ? rel + "/" + name : name;
    const mode = modeOf(full, subRel, modes);
    if (mode === "40000") {
      const sub = treeOf(full, subRel, modes);
      if (sub.empty) continue;
      entries.push({ name: name + "/", mode: "40000", id: sub.id });
    } else {
      entries.push({ name, mode, id: gitBlob(full, mode) });
    }
  }
  if (entries.length === 0) return { id: "", empty: true };
  entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  const parts = entries.map((e) => {
    const shown = e.name.endsWith("/") ? e.name.slice(0, -1) : e.name;
    return Buffer.concat([Buffer.from(e.mode + " " + shown + "\0", "utf8"), Buffer.from(e.id, "hex")]);
  });
  return { id: gitObject("tree", Buffer.concat(parts)), empty: false };
}

function main(argv) {
  const cmd = argv[0];
  if (cmd === "tree" && argv.length === 2) {
    if (!fs.existsSync(argv[1]) || !fs.statSync(argv[1]).isDirectory()) fail("not a folder: " + argv[1]);
    const t = treeOf(argv[1], "", indexModes(argv[1]));
    if (!t.empty) process.stdout.write(t.id + "\n");
    return;
  }
  if (cmd === "list" && argv.length === 2) {
    const rows = listRows(readJson(argv[1]));
    process.stdout.write(rows.map((r) => r + "\n").join(""));
    return;
  }
  if (cmd === "apply" && argv.length === 3) {
    apply(argv[1], argv[2]);
    return;
  }
  if (cmd === "field" && argv.length === 3) {
    const v = readJson(argv[1])[argv[2]];
    process.stdout.write((v === undefined || v === null ? "" : String(v)) + "\n");
    return;
  }
  fail("usage: skills-lock.cjs list <lock> | apply <lock> <updates.txt> | field <file.json> <key>");
}

main(process.argv.slice(2));

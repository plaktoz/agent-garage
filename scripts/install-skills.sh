#!/usr/bin/env bash
# Install the skills of this repo as symlinks.
# Usage: scripts/install-skills.sh [--project DIR] [--agents | --codex] [--force] [--uninstall] [--list] [skill-name ...]
# Two sources: skills/ (own skills) and .cache/<source>/<path> for each skill in skills.lock.json
# (fetched by scripts/fetch-skills.sh, git-ignored). Without .cache, the own skills are still
# installed and the script says to run scripts/fetch-skills.sh.
# A skill name in both sources is an error and installs neither copy.
# Default target: ~/.claude/skills (Claude Code).
# --agents: target ~/.agents/skills, the harness-neutral folder. Codex, OpenCode and Gemini CLI
#   read it, per pstack's README. Not run here for OpenCode or Gemini CLI.
# --codex: an alias of --agents, with the same behaviour.
# --project DIR: install for one project. The target is DIR/.claude/skills (Claude Code, and
#   OpenCode reads it at project level too). With --agents, the target is DIR/.agents/skills
#   (Codex, OpenCode and Gemini CLI read it at project level, per their docs; not run here).
#   DIR must exist. It does not have to be a git repository.
# CLAUDE_SKILLS_DIR overrides the target folder. Do not use it with --project.
# Before it links a skill that mentions a plugin named in skills.lock.json (requires.plugins), it
# checks, read only, whether the computer already has that plugin (scripts/lib-deps.sh). It never
# installs a plugin.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
own="$repo/skills"
cache="$repo/.cache"
lock="$repo/skills.lock.json"
agents=0
force=0
mode=install
project=""
names=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agents | --codex) agents=1 ;;
    --force) force=1 ;;
    --uninstall) mode=uninstall ;;
    --list) mode=list ;;
    --project)
      [ "$#" -ge 2 ] || { echo "error: --project needs a folder" >&2; exit 2; }
      project="$2"
      shift ;;
    -h | --help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d'; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) names+=("$1") ;;
  esac
  shift
done

# proj_root is the project that dependency checks look at: the --project folder, else the current folder.
proj_root="$PWD"
if [ -n "$project" ]; then
  if [ -n "${CLAUDE_SKILLS_DIR:-}" ]; then
    echo "error: use --project or CLAUDE_SKILLS_DIR, not both." >&2
    exit 2
  fi
  [ -d "$project" ] || { echo "error: --project folder not found: $project" >&2; exit 2; }
  proj_root="$(cd "$project" && pwd)"
  if [ "$agents" -eq 1 ]; then dest="$proj_root/.agents/skills"; else dest="$proj_root/.claude/skills"; fi
else
  if [ "$agents" -eq 1 ]; then default_dest="$HOME/.agents/skills"; else default_dest="$HOME/.claude/skills"; fi
  dest="${CLAUDE_SKILLS_DIR:-$default_dest}"
fi

# A skill is a folder with a SKILL.md file. Plain files, such as LICENSE, are not skills.
# all_names and all_froms are parallel lists: the skill name and the folder it comes from.
# all_locked marks the names that come from the lock (1) and not from skills/ (0).
all_names=()
all_froms=()
all_locked=()
for dir in "$own"/*/; do
  if [ -f "${dir}SKILL.md" ]; then
    all_names+=("$(basename "$dir")")
    all_froms+=("$own/$(basename "$dir")")
    all_locked+=(0)
  fi
done

# The locked skills: skills.lock.json names each one with its upstream path. The folder is
# .cache/<source>/<path>. A locked skill is listed even when .cache is missing, so that a name asked
# for on the command line is known; whether its SKILL.md exists is checked at install.
lock_note=""
rows=""
if [ ! -f "$lock" ]; then
  lock_note="no skills.lock.json at $lock, so only the own skills in skills/ are installed."
elif ! command -v node >/dev/null 2>&1; then
  lock_note="node is not installed, so skills.lock.json cannot be read and only the own skills in skills/ are installed. Install node (https://nodejs.org), then run again."
elif ! rows="$(node "$repo/scripts/skills-lock.cjs" list "$lock" 2>&1)"; then
  lock_note="skills.lock.json could not be read ($rows), so only the own skills in skills/ are installed."
  rows=""
fi
missing_cache=""
while IFS='|' read -r kind src nm p _; do
  [ "$kind" = skill ] || continue
  all_names+=("$nm")
  all_froms+=("$cache/$src/$p")
  all_locked+=(1)
  case " $missing_cache " in
    *" $src "*) ;;
    *) [ -d "$cache/$src" ] || missing_cache="$missing_cache $src" ;;
  esac
done <<< "$rows"

# The same name in both sources is an error. Install neither copy.
dup=0
i=0
while [ "$i" -lt "${#all_names[@]}" ]; do
  j=$((i + 1))
  while [ "$j" -lt "${#all_names[@]}" ]; do
    if [ "${all_names[$i]}" = "${all_names[$j]}" ]; then
      echo "error      ${all_names[$i]} (in both ${all_froms[$i]} and ${all_froms[$j]})" >&2
      dup=1
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done
if [ "$dup" -eq 1 ]; then
  exit 1
fi

if [ -n "$lock_note" ]; then
  echo "note       $lock_note" >&2
fi
if [ -n "$missing_cache" ]; then
  echo "note       no fetched copy for:${missing_cache}. Run scripts/fetch-skills.sh to fetch the locked skills into $cache. The own skills in skills/ are installed now." >&2
fi

# Without names, take every skill whose SKILL.md exists. A locked skill whose fetched copy is
# missing is left out (see the note above); asking for it by name is an error.
if [ "${#names[@]}" -eq 0 ]; then
  i=0
  while [ "$i" -lt "${#all_names[@]}" ]; do
    if [ -f "${all_froms[$i]}/SKILL.md" ]; then
      names+=("${all_names[$i]}")
    fi
    i=$((i + 1))
  done
fi

if [ "${#names[@]}" -eq 0 ]; then
  echo "No skills found in $own or in $cache (run scripts/fetch-skills.sh)" >&2
  exit 1
fi

# Dependencies: before a skill that mentions a plugin of the lock is linked, say whether the
# computer already has that plugin. Read only. Never an install.
dep_report() {
  local plugin_rows pname n k hits lvl txt
  [ "$mode" = install ] || return 0
  [ -n "$rows" ] || return 0
  # shellcheck source=lib-deps.sh
  DEP_REPO="$repo"
  . "$repo/scripts/lib-deps.sh"
  dep_init
  plugin_rows="$(dep_rows_of plugin-req)"
  [ -n "$plugin_rows" ] || return 0
  while IFS='|' read -r _ pname _; do
    [ -n "$pname" ] || continue
    hits=""
    for n in "${names[@]}"; do
      k=0
      while [ "$k" -lt "${#all_names[@]}" ]; do
        if [ "${all_names[$k]}" = "$n" ] && [ -f "${all_froms[$k]}/SKILL.md" ]; then
          if grep -qiw -- "$pname" "${all_froms[$k]}/SKILL.md" 2>/dev/null; then
            hits="$hits $n"
          fi
        fi
        k=$((k + 1))
      done
    done
    if [ -z "$hits" ]; then
      echo "dependency $pname: no skill to install mentions it, so nothing to check."
      continue
    fi
    echo "dependency $pname: needed by${hits}. Checking whether this computer already has it (read only)."
    dep_plugin_scan "$pname" "$proj_root" "$HOME/.claude/skills" "$HOME/.agents/skills" "$proj_root/.claude/skills" "$proj_root/.agents/skills"
    while IFS="$(printf '\t')" read -r lvl txt; do
      [ -n "$lvl" ] || continue
      echo "dependency   $lvl: $txt"
    done <<< "$(dep_plugin_lines)"
    if [ "$dep_overall" = not_found ]; then
      echo "dependency   this script does not install plugins. Install $pname by hand, from $dep_plink"
    fi
  done <<< "$plugin_rows"
  return 0
}
dep_report

if [ -n "$project" ] && [ "$mode" = install ]; then
  echo "target     $dest"
fi
# Only an install makes the folder. --list and --uninstall never create one.
[ "$mode" = install ] && mkdir -p "$dest"
status=0

for name in "${names[@]}"; do
  # An unknown name falls back to the own folder, so install reports it as an error.
  from="$own/$name"
  locked=0
  i=0
  while [ "$i" -lt "${#all_names[@]}" ]; do
    if [ "${all_names[$i]}" = "$name" ]; then
      from="${all_froms[$i]}"
      locked="${all_locked[$i]}"
    fi
    i=$((i + 1))
  done
  to="$dest/$name"

  if [ "$mode" = list ]; then
    if [ -L "$to" ] && [ "$(readlink "$to")" = "$from" ]; then
      echo "installed  $name"
    elif [ -L "$to" ] && [ ! -e "$to" ]; then
      # A symlink whose target is gone is dangling: -L is true, -e is false.
      echo "broken     $name"
    else
      echo "missing    $name"
    fi
    continue
  fi

  if [ "$mode" = uninstall ]; then
    if [ -L "$to" ] && [ "$(readlink "$to")" = "$from" ]; then
      rm "$to"
      echo "removed    $name"
    else
      echo "skipped    $name (not installed from this repo)"
    fi
    continue
  fi

  if [ ! -f "$from/SKILL.md" ]; then
    if [ "$locked" -eq 1 ]; then
      echo "error      $name (no $from/SKILL.md; run scripts/fetch-skills.sh)" >&2
    else
      echo "error      $name (no $own/$name/SKILL.md, and $name is not in skills.lock.json)" >&2
    fi
    status=1
    continue
  fi

  if [ -L "$to" ] && [ "$(readlink "$to")" = "$from" ]; then
    echo "up to date $name"
  elif [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" -eq 1 ]; then
      rm -rf "$to"
      ln -s "$from" "$to"
      echo "replaced   $name"
    elif [ -L "$to" ] && [ ! -e "$to" ]; then
      echo "broken     $name (link target $(readlink "$to") is missing; use --force to replace)" >&2
      status=1
    else
      echo "skipped    $name (already exists at $to; use --force to replace)" >&2
      status=1
    fi
  else
    ln -s "$from" "$to"
    echo "installed  $name"
  fi
done

exit "$status"

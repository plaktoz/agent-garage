#!/usr/bin/env bash
# Install the agents of this repo into ~/.claude/agents as symlinks (Claude Code).
# Codex CLI reads .codex/agents/*.toml from the project; this script does not install those.
# Usage: scripts/install-agents.sh [--force] [--uninstall] [--list] [agent-name ...]
# CLAUDE_AGENTS_DIR overrides the target folder.
# Windows: run it in Git Bash. A link needs Developer Mode. The script sets MSYS=winsymlinks:nativestrict,
#   so ln -s makes a real link or fails. If a copy was made instead, the script removes it, reports an
#   error and exits non-zero. Not tested on Windows: this is from reading the script.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$repo/agents"
force=0
mode=install
names=()

# Windows (Git Bash, MSYS, Cygwin): without this setting, ln -s makes a copy and not a link.
is_win=0
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) is_win=1; export MSYS=winsymlinks:nativestrict ;;
esac

# check_link TO NAME: on Windows, ln -s can make a copy instead of a link. Such a copy is removed
# and reported. On other systems this does nothing.
check_link() {
  [ "$is_win" -eq 1 ] || return 0
  [ -L "$1" ] && return 0
  rm -rf "$1"
  echo "error      $2 (ln -s made a copy, not a link, so the copy was removed. Turn on Windows Developer Mode, then run in Git Bash with MSYS=winsymlinks:nativestrict)" >&2
  return 1
}

for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --uninstall) mode=uninstall ;;
    --list) mode=list ;;
    -h | --help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d'; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) names+=("$arg") ;;
  esac
done

# The target folder: CLAUDE_AGENTS_DIR, else ~/.claude/agents. The home folder is HOME, else USERPROFILE (Windows).
if [ -n "${CLAUDE_AGENTS_DIR:-}" ]; then
  dest="$CLAUDE_AGENTS_DIR"
else
  home="${HOME:-${USERPROFILE:-}}"
  if [ -z "$home" ]; then
    echo "error: neither HOME nor USERPROFILE is set" >&2
    exit 2
  fi
  dest="$home/.claude/agents"
fi

# An agent is a .md file in agents/.
if [ "${#names[@]}" -eq 0 ]; then
  for file in "$src"/*.md; do
    [ -f "$file" ] && names+=("$(basename "$file" .md)")
  done
fi

if [ "${#names[@]}" -eq 0 ]; then
  echo "No agents found in $src" >&2
  exit 1
fi

# Only an install makes the folder. --list and --uninstall never create one.
[ "$mode" = install ] && mkdir -p "$dest"
status=0

for name in "${names[@]}"; do
  from="$src/$name.md"
  to="$dest/$name.md"

  if [ "$mode" = list ]; then
    if [ -L "$to" ] && [ "$(readlink "$to")" = "$from" ]; then
      echo "installed  $name"
    elif [ -L "$to" ] && [ ! -e "$to" ]; then
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

  if [ ! -f "$from" ]; then
    echo "error      $name (no $from)" >&2
    status=1
    continue
  fi

  if [ -L "$to" ] && [ "$(readlink "$to")" = "$from" ]; then
    echo "up to date $name"
  elif [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" -eq 1 ]; then
      rm -rf "$to"
      ln -s "$from" "$to"
      if check_link "$to" "$name"; then echo "replaced   $name"; else status=1; fi
    elif [ -L "$to" ] && [ ! -e "$to" ]; then
      echo "broken     $name (link target $(readlink "$to") is missing; use --force to replace)" >&2
      status=1
    else
      echo "skipped    $name (already exists at $to; use --force to replace)" >&2
      status=1
    fi
  else
    ln -s "$from" "$to"
    if check_link "$to" "$name"; then echo "installed  $name"; else status=1; fi
  fi
done

exit "$status"

#!/usr/bin/env bash
# Install the agents of this repo into ~/.claude/agents as copies (Claude Code).
# Each copy has a sidecar marker, <name>.md.agent-garage-source, that holds the source path.
# A file without the marker is not touched unless --force is given.
# Codex CLI reads .codex/agents/*.toml from the project; this script does not install those.
# Usage: scripts/install-agents.sh [--force] [--uninstall] [--list] [agent-name ...]
# Exit status: 0 ok, 1 an agent missing or skipped, 2 usage error.
# CLAUDE_AGENTS_DIR overrides the target folder.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$repo/agents"
force=0
mode=install
names=()

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

# Escape a path so that find -lname matches it literally.
glob_escape() {
  printf '%s' "$1" | sed 's/[][*?\\]/\\&/g'
}

# legacy_link TO: true if TO is a symlink made by an older version of this script, whose target is
# inside this repo. find -lname compares the link's text, so a dangling link is matched too.
legacy_link() {
  [ -L "$1" ] && [ -n "$(find "$1" -maxdepth 0 -lname "$(glob_escape "$repo")/*")" ]
}

# marker_in_repo MARKER: true if the marker holds a path inside this repo.
marker_in_repo() {
  [ -f "$1" ] || return 1
  case "$(cat "$1")" in
    "$repo"/*) return 0 ;;
  esac
  return 1
}

# copy_agent FROM TO MARKER: copy the agent and write its sidecar marker.
copy_agent() {
  cp "$1" "$2"
  printf '%s\n' "$1" > "$3"
}

# Only an install makes the folder. --list and --uninstall never create one.
[ "$mode" = install ] && mkdir -p "$dest"
status=0

for name in "${names[@]}"; do
  from="$src/$name.md"
  to="$dest/$name.md"
  marker="$to.agent-garage-source"

  if [ "$mode" = list ]; then
    if [ -L "$to" ]; then
      if [ -e "$to" ]; then
        echo "unmanaged  $name (a file not made by this script)"
      else
        echo "broken     $name"
      fi
    elif [ ! -e "$to" ]; then
      echo "missing    $name"
    elif [ ! -f "$marker" ]; then
      echo "unmanaged  $name (a file not made by this script)"
    elif cmp -s "$from" "$to"; then
      echo "installed  $name"
    else
      echo "stale      $name"
    fi
    continue
  fi

  if [ "$mode" = uninstall ]; then
    if legacy_link "$to" || marker_in_repo "$marker"; then
      rm -f "$to" "$marker"
      echo "removed    $name"
    elif [ ! -e "$to" ] && [ ! -L "$to" ]; then
      echo "missing    $name (nothing to remove)"
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

  if legacy_link "$to"; then
    rm "$to"
    copy_agent "$from" "$to" "$marker"
    echo "replaced   $name"
  elif [ -L "$to" ]; then
    if [ "$force" -eq 1 ]; then
      rm "$to"
      copy_agent "$from" "$to" "$marker"
      echo "replaced   $name"
    elif [ -e "$to" ]; then
      echo "skipped    $name (a symlink to somewhere else at $to; use --force to replace)" >&2
      status=1
    else
      echo "broken     $name (a dangling symlink at $to; use --force to replace)" >&2
      status=1
    fi
  elif [ -e "$to" ]; then
    if [ -f "$marker" ]; then
      if cmp -s "$from" "$to"; then
        echo "up to date $name"
      else
        rm -f "$to"
        copy_agent "$from" "$to" "$marker"
        echo "updated    $name"
      fi
    elif [ "$force" -eq 1 ]; then
      rm -f "$to"
      copy_agent "$from" "$to" "$marker"
      echo "replaced   $name"
    else
      echo "skipped    $name (already exists at $to, not made by this script; use --force to replace)" >&2
      status=1
    fi
  else
    copy_agent "$from" "$to" "$marker"
    echo "installed  $name"
  fi
done

exit "$status"

#!/usr/bin/env bash
# Prepare a git project for the agent kit: copy playbooks/*.md into <project>/.agents/playbooks/.
# Usage: scripts/bootstrap-project.sh <project-path> [--force] [--pstack <local|user>]
# Runs neither /setup-matt-pocock-skills nor the guardrails: it prints the steps to run by hand.
# pstack is opt-in: https://github.com/michael-denyer/pstack-claude. Without --pstack, this script only
# reports it (read-only). With --pstack it installs the locked copy in .cache/pstack-claude (made by
# scripts/fetch-skills.sh). It never installs again, updates, removes or replaces what is there.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home="${HOME:-${USERPROFILE:-}}"
src="$repo/playbooks"
cache_pstack="$repo/.cache/pstack-claude"
pstack_link="https://github.com/michael-denyer/pstack-claude"
force=0
pstack_on=0
pstack_scope=""
proj_arg=""
proj=""
status=0
pstack_action=none
mkt_action=add

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-project.sh <project-path> [--force] [--pstack <scope>]

Copies the playbooks (playbooks/*.md) into <project-path>/.agents/playbooks/.
The project path must be the top folder of a git repository.

Options:
  --force           Replace a playbook that differs from the kit's copy.
                    Without it, a changed file is skipped.
  --pstack <scope>  Install pstack (https://github.com/michael-denyer/pstack-claude) at the commit
                    in skills.lock.json, from .cache/pstack-claude (run scripts/fetch-skills.sh
                    first). Scope is local or user. project is refused: it writes the plugin
                    into the shared .claude/settings.json. Needs the claude command. Every
                    check is made before anything is copied. Nothing already installed is
                    installed again, and no marketplace is removed or replaced.
  -h, --help        Show this help.

Exit status: 0 ok, 1 a problem during the work, 2 usage error.
EOF
}

usage_error() {
  echo "error: $1" >&2
  echo "Run with --help for usage." >&2
  exit 2
}

fail() {
  echo "error: $1" >&2
  exit 1
}

# Shared dependency check (read only). Used for pstack: its id, minimum version and link come from
# skills.lock.json, not from this file.
DEP_REPO="$repo"
# shellcheck source=lib-deps.sh
. "$repo/scripts/lib-deps.sh"
dep_init

# run_check CHECKER: run pstack's check-playbooks.mjs against the project and show its real result.
run_check() {
  local out
  echo "pstack check: running $1 against $proj"
  if out="$(node "$1" "$proj" 2>&1)"; then
    echo "pstack check: passed. $out"
  else
    status=1
    echo "pstack check: FAILED"
    printf '%s\n' "$out" | sed 's/^/  /'
  fi
}

# pstack_scan: read only. Sets the dep_* variables for pstack (see scripts/lib-deps.sh).
pstack_scan() {
  dep_plugin_scan pstack "$proj" "$home/.agents/skills" "$proj/.agents/skills"
}

# pstack_lines: prints the findings of pstack_scan, one per line.
pstack_lines() {
  local lvl txt
  while IFS="$(printf '\t')" read -r lvl txt; do
    [ -n "$lvl" ] || continue
    printf '  %-5s %s\n' "$lvl" "$txt"
  done <<< "$(dep_plugin_lines)"
}

# pstack_report: read only. Prints what pstack_scan finds. When an install for this project is
# 0.9.57 or later, runs the playbook check from it.
pstack_report() {
  local checker="" reason="no pstack install for this project" scope version ppath enabled ipath
  pstack_scan
  pstack_lines
  if [ "$dep_overall" = found_here ]; then
    while IFS='|' read -r scope version ppath enabled ipath; do
      [ -n "$scope" ] || continue
      case "$(dep_ver_state "$version" "$dep_pmin")" in
        ok)
          if [ -f "$ipath/skills/poteto-mode/scripts/check-playbooks.mjs" ]; then
            checker="$ipath/skills/poteto-mode/scripts/check-playbooks.mjs"
          else
            reason="pstack $version at $ipath has no check-playbooks.mjs"
          fi
          ;;
        old) reason="pstack $version is below $dep_pmin, the first version with project playbooks" ;;
        *) reason="pstack $version: the version is not recognised, so the check was not run" ;;
      esac
      [ -z "$checker" ] || break
    done <<< "$dep_here"
  elif [ "$dep_overall" = found_linked ]; then
    reason="pstack skills are linked, but the plugin is not installed for this project"
  fi
  if [ -n "$checker" ]; then
    run_check "$checker"
  else
    echo "pstack check skipped: $reason."
  fi
  return 0
}

# blocked_help: printed when a pstack-claude marketplace is already there and is not the locked copy.
blocked_help() {
  echo "pstack: $1"
  echo "  This script does not add the locked copy, and it does not remove or replace a marketplace or"
  echo "  an install. Nothing was copied and nothing was changed. Source: $pstack_link"
  echo "  To use the locked copy at this scope, by hand:"
  if [ "$dep_mstate" = found ]; then
    echo "    claude plugin marketplace remove pstack-claude     (you choose this; it removes the current one)"
  fi
  echo "    claude plugin marketplace add \"$cache_pstack\""
  echo "    claude plugin install pstack@pstack-claude --scope $pstack_scope"
  echo "  To keep what is there, do nothing, or install from the marketplace you have by hand."
}

# pstack_precheck: every check that can stop a pstack install. Makes no change. Sets pstack_action
# (found, install) and mkt_action (add, present). Exits 1 before anything is copied when it cannot install.
pstack_precheck() {
  local plug plug_path plug_tree got cache_phys mkt_path
  pstack_action=none
  mkt_action=add
  [ "$pstack_on" -eq 1 ] || return 0
  if ! dep_plugin_lookup pstack; then
    fail "skills.lock.json has no pstack entry, or node cannot read it. Nothing was copied."
  fi
  pstack_scan
  if [ "$dep_overall" = found_here ] || [ "$dep_overall" = found_linked ]; then
    pstack_action=found
    return 0
  fi
  if [ "$dep_pstate" = skipped ]; then
    pstack_lines
    fail "--pstack needs claude and node, and the plugin check was skipped ($dep_pdetail). Nothing was copied."
  fi
  # An install that exists only for other projects is still pstack on this computer. The rule for
  # the shared marketplace says: do not add one when a pstack-claude install or marketplace exists.
  # So this stops here, and prints the situation and the commands. It does not install a second copy.
  if [ "$dep_overall" = found_elsewhere ]; then
    pstack_lines
    blocked_help "an install exists for another project (see above). Installing the locked copy for this project would be a second install, so it is not done. Nothing was copied."
    exit 1
  fi
  if [ "$dep_mstate" = skipped ]; then
    fail "the pstack-claude marketplace check was skipped ($dep_detail). Nothing was copied."
  fi
  if [ ! -d "$cache_pstack" ]; then
    fail "$cache_pstack is missing. Run scripts/fetch-skills.sh first, then run this again. Nothing was copied or changed."
  fi
  plug="$(dep_row plugin "$dep_psrc")"
  plug_path="$(printf '%s' "$plug" | awk -F'|' '{ print $3 }')"
  plug_tree="$(printf '%s' "$plug" | awk -F'|' '{ print $4 }')"
  got=""
  if [ -n "$plug_path" ] && [ -d "$cache_pstack/$plug_path" ]; then
    got="$(node "$DEP_REPO/scripts/skills-lock.cjs" tree "$cache_pstack/$plug_path" 2>/dev/null || true)"
  fi
  if [ -z "$plug_tree" ] || [ "$got" != "$plug_tree" ]; then
    fail "$cache_pstack/$plug_path does not match skills.lock.json. Run scripts/fetch-skills.sh first. Nothing was copied or changed."
  fi
  if [ "$dep_mstate" = skipped ]; then
    fail "the pstack-claude marketplace check was skipped ($dep_detail). Nothing was copied."
  fi
  if [ "$dep_mstate" = found ]; then
    mkt_path="$(printf '%s' "$dep_mkt" | awk -F'|' '{ print $3 }')"
    cache_phys="$(dep_path_key "$cache_pstack")"
    if [ -n "$mkt_path" ] && [ -d "$mkt_path" ] && [ "$(dep_path_key "$mkt_path")" = "$cache_phys" ]; then
      mkt_action=present
    else
      blocked_help "a pstack-claude marketplace is already added ($dep_mkt), and it is not the locked copy. Nothing was copied."
      exit 1
    fi
  fi
  pstack_action=install
}

# Arguments.
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --force) force=1 ;;
    --pstack)
      [ "$pstack_on" -eq 0 ] || usage_error "--pstack was given more than once"
      [ "$#" -ge 2 ] || usage_error "--pstack needs a scope: local or user"
      pstack_on=1
      pstack_scope="$2"
      shift
      ;;
    -*) usage_error "unknown option: $1" ;;
    *)
      [ -z "$proj_arg" ] || usage_error "only one project path is allowed"
      proj_arg="$1"
      ;;
  esac
  shift
done

[ -n "$proj_arg" ] || usage_error "a project path is required"

if [ "$pstack_on" -eq 1 ]; then
  case "$pstack_scope" in
    local | user) ;;
    project)
      usage_error "--pstack project is refused. Project scope writes the plugin into the project's shared .claude/settings.json, which every clone of the project would load. Use --pstack local (this project, not shared) or --pstack user (every project). $pstack_link"
      ;;
    *) usage_error "--pstack scope must be local or user (got: ${pstack_scope:-nothing})" ;;
  esac
fi

[ -d "$proj_arg" ] || fail "not a folder: $proj_arg"
proj="$(cd "$proj_arg" && pwd -P)"
if ! top="$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null)"; then
  fail "not a git repository: $proj_arg (run git init first, or pick the project's folder)"
fi
[ "$(dep_path_key "$top")" = "$(dep_path_key "$proj")" ] || fail "$proj_arg is inside the git repository $top. Give that folder instead."

[ -d "$src" ] || fail "no playbooks folder at $src"
[ -n "$home" ] || fail "neither HOME nor USERPROFILE is set. The pstack check reads ~/.agents/skills, so set one of them. Nothing was copied."

# Every check that can fail is made before the first change.
pstack_precheck

# Copy the playbooks.
dest="$proj/.agents/playbooks"
count=0
echo "Playbooks in $dest:"
for file in "$src"/*.md; do
  [ -f "$file" ] || continue
  count=$((count + 1))
  name="$(basename "$file")"
  to="$dest/$name"
  mkdir -p "$dest"
  if [ -d "$to" ]; then
    fail "$to is a folder. Remove it, then run again."
  fi
  if [ -f "$to" ] && cmp -s "$file" "$to"; then
    echo "up to date $name"
  elif [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" -eq 1 ]; then
      rm -f "$to"
      cp "$file" "$to"
      echo "replaced   $name"
    else
      echo "skipped    $name (changed locally; use --force)"
      status=1
    fi
  else
    cp "$file" "$to"
    echo "copied     $name"
  fi
done
[ "$count" -gt 0 ] || fail "no playbooks (*.md) in $src"

# pstack: opt-in install, or a read-only report.
echo ""
if [ "$pstack_on" -eq 1 ]; then
  if [ "$pstack_action" = found ]; then
    echo "pstack: already installed for this project, so it is not installed again."
    echo "        An update is a separate step: ask for it, then run claude plugin marketplace update"
    echo "        pstack-claude and claude plugin update pstack@pstack-claude --scope <scope>."
  else
    if [ "$mkt_action" = add ]; then
      echo "marketplace pstack-claude: adding the locked copy at $cache_pstack"
      if ! (cd "$proj" && claude plugin marketplace add "$cache_pstack"); then
        fail "claude plugin marketplace add failed. The playbooks were copied, pstack was not installed."
      fi
    else
      echo "marketplace pstack-claude: the locked copy is already added"
    fi
    echo "pstack: installing the locked copy at scope $pstack_scope ($pstack_link)"
    if ! (cd "$proj" && claude plugin install pstack@pstack-claude --scope "$pstack_scope"); then
      fail "claude plugin install failed. The playbooks were copied."
    fi
  fi
  pstack_report
else
  pstack_report
  if [ "$dep_overall" != found_here ] && [ "$dep_overall" != found_linked ]; then
    echo "To install pstack for this project ($pstack_link):"
    echo "  1. bash \"$repo/scripts/fetch-skills.sh\"     (once, to make the locked copy in .cache/)"
    echo "  2. bash \"$repo/scripts/bootstrap-project.sh\" \"$proj\" --pstack <local|user>"
    echo "     (that adds the locked copy as the pstack-claude marketplace, then installs the plugin;"
    echo "      it does nothing when pstack is already there)"
  fi
fi

echo ""
echo "Next steps, by hand (this script runs neither):"
echo "  1. Link the skills if they are not installed: bash \"$repo/scripts/install-skills.sh\""
echo "  2. In the project, run /setup-matt-pocock-skills in Claude Code."
echo "  3. Optional: /git-guardrails-claude-code. It needs jq, and its hook blocks every git push."
echo "     Add it only to a project where that is wanted."

exit "$status"

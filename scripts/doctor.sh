#!/usr/bin/env bash
# Read-only check of this machine for the claude-mods kit. It changes nothing: it writes no
# file, and it runs no install, update, enable, disable or marketplace add/update/remove.
# Usage: scripts/doctor.sh      (from any folder; prints the report, then exits)
#
# Reports:
#   Tools     from requires.tools in skills.lock.json: found or not, version where cheap.
#   Platform  WSL (from /proc/version): warns when the repo is under /mnt/.
#   Skills    each kit skill: the own skills in skills/ and the locked skills (their fetched
#             copies in .cache/, from skills.lock.json), in two skill folders:
#               ~/.claude/skills   Claude Code
#               ~/.agents/skills   Codex, OpenCode, Gemini CLI (install-skills.sh --agents)
#             ok        a link that resolves to this repo's folder (skills/ or .cache/)
#             shadowed  another link, or a real folder or file, is in the way (named)
#             broken    a link whose target is gone
#             missing   nothing with that name in the folder
#   Lock      each locked skill: its fetched copy in .cache/ is present and its git tree hash
#             equals the lock. Installed and wrong: an error. Not installed: a warning.
#             Each copy in skills/ is compared with the copy recorded in the lock (a warning).
#   Calls     every name in calls and mentions of a locked skill or copy must be a locked skill,
#             a copy or an own skill. A missing call is an error; a missing mention a warning.
#   Playbooks the names in the "Skills used" block of playbooks/*.md. A Pocock name must be a
#             locked skill, a copy or an own skill. A pstack name must be in the locked pstack
#             plugin (its fetched copy). A name that is not found is a warning.
#   Plugins   from requires.plugins: the locked version and commit, what is installed (claude plugin
#             list), the marketplace, and the plugin's skills that are linked in a skill folder.
#             Old or missing is a warning. A check that cannot run says "check skipped".
#
# The dependency checks (tools, plugins) are shared with the installer and bootstrap, in
# scripts/lib-deps.sh. Nothing about a particular plugin is written here.
#
# Rules for the skill folders:
#   - CLAUDE_SKILLS_DIR, when set, replaces ~/.claude/skills (install-skills.sh does the same).
#     It also moves install-skills.sh's target, so the --agents fix line is wrong while it is set.
#   - A folder that does not exist is "not used", not an error. So is a shared folder that holds
#     no kit skill at all (for example one another tool made). The Claude Code folder with no kit
#     skill is a warning, not a failure, because the user may not use Claude Code.
#   - A used folder must hold every kit skill. Shadowed, broken and missing entries fail.
#   - If no folder is used, that is a warning: nothing is installed, and nothing is missing from
#     a folder that exists.
#   - A name in both sources (skills/ and the lock) fails, as install-skills.sh refuses it.
#
# Exit status: 0 when nothing failed. 1 when something failed (see above). 2 when HOME and USERPROFILE are not set.
# A missing claude, node, jq, gh or fetched copy never fails by itself: it is a note or a warning,
# or a failure only for a skill that is installed (see Lock).
#
# Fix commands are printed. None is run. A "mv" moves a real folder aside (to before-kit-NAME
# next to the skill folder). It never deletes one.
#
# Fixture hooks, for tests only:
#   HOME                  the default folders are $HOME/.claude/skills and $HOME/.agents/skills
#   CLAUDE_SKILLS_DIR     replaces ~/.claude/skills
#   DOCTOR_PROC_VERSION   a file read in place of /proc/version
#   DOCTOR_REPO_PATH      a path used in place of the repo path, for the WSL /mnt/ check only
#
# Runs on bash 3.2 (macOS), Linux, WSL, Git Bash and Cygwin.

set -u

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
home="${HOME:-${USERPROFILE:-}}"
if [ -z "$home" ]; then
  echo "error: neither HOME nor USERPROFILE is set. Set one of them, then run this again." >&2
  exit 2
fi
claude_dir="${CLAUDE_SKILLS_DIR:-$home/.claude/skills}"
agents_dir="$home/.agents/skills"
cache="$repo/.cache"
helper="$repo/scripts/skills-lock.cjs"
fails=0
warns=0
used=0

say() { printf '  %-10s %s\n' "$1" "$2"; }
fix() { printf '             fix: %s\n' "$1"; }
fail_line() { fails=$((fails + 1)); say "$1" "$2"; }
warn_line() { warns=$((warns + 1)); say warn "$1"; }

# The shared dependency check (read only). See scripts/lib-deps.sh.
DEP_REPO="$repo"
# shellcheck source=lib-deps.sh
. "$repo/scripts/lib-deps.sh"
dep_init

case "$(uname -s 2>/dev/null)" in
  Darwin) os_kind=macos ;;
  Linux) os_kind=linux ;;
  MINGW* | MSYS*) os_kind=gitbash ;;
  CYGWIN*) os_kind=cygwin ;;
  *) os_kind=other ;;
esac

printf 'claude-mods doctor (read only: changes nothing)\n'
printf 'Repo:     %s\n' "$repo"
printf 'Platform: %s (%s)\n' "$os_kind" "$(uname -sr 2>/dev/null)"

# ---- Tools ---------------------------------------------------------------

# linux_install PKG: the install command for PKG with the package manager found on this computer.
linux_install() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "sudo apt-get install $1"
  elif command -v dnf >/dev/null 2>&1; then
    echo "sudo dnf install $1"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew install $1"
  else
    echo "install $1 with your package manager"
  fi
}

# win_install PKG: the install command for PKG on Windows (winget or scoop).
win_install() {
  case "$1" in
    git) echo "winget install Git.Git   (or scoop install git)" ;;
    node) echo "winget install OpenJS.NodeJS.LTS   (or scoop install nodejs-lts)" ;;
    jq) echo "winget install jqlang.jq   (or scoop install jq)" ;;
    gh) echo "winget install GitHub.cli   (or scoop install gh)" ;;
    *) echo "install $1 with winget or scoop" ;;
  esac
}

tool_fix() {
  case "$os_kind:$1" in
    *:claude) echo "npm install -g @anthropic-ai/claude-code" ;;
    macos:*) echo "brew install $1" ;;
    linux:gh) echo "see https://cli.github.com (or your package manager)" ;;
    linux:node) linux_install nodejs ;;
    linux:*) linux_install "$1" ;;
    gitbash:*) win_install "$1" ;;
    cygwin:*) echo "install $1 with the Cygwin setup program, or winget" ;;
    *) echo "install $1 with your package manager" ;;
  esac
}

# tool_line NAME LEVEL WHY LINK: LEVEL is warn or note. Prints the version when found.
tool_line() {
  dep_tool "$1"
  if [ "$dep_state" = found ]; then
    say ok "$1 $dep_version"
  elif [ "$2" = warn ]; then
    warn_line "$1 not found. $3 Source: $4"
    fix "$(tool_fix "$1")"
  else
    say note "$1 not found. $3 Source: $4"
    fix "$(tool_fix "$1")"
  fi
}

echo ""
echo "Tools"
say ok "bash $BASH_VERSION"
if [ -z "$DEP_ROWS" ]; then
  say note "tool list not read: skills.lock.json cannot be read (node is missing, or the file is missing or invalid)."
else
  while IFS='|' read -r _ tname tlevel tlink _ twhy; do
    [ -n "$tname" ] || continue
    tool_line "$tname" "$tlevel" "$twhy" "$tlink"
  done <<< "$(dep_rows_of tool)"
fi

# ---- Platform ------------------------------------------------------------

echo ""
echo "Platform"
procver="${DOCTOR_PROC_VERSION:-/proc/version}"
is_wsl=0
if [ "$os_kind" = linux ] || [ -n "${DOCTOR_PROC_VERSION:-}" ]; then
  if [ -r "$procver" ] && grep -qi microsoft "$procver"; then
    is_wsl=1
  fi
fi
if [ "$is_wsl" -eq 1 ]; then
  case "${DOCTOR_REPO_PATH:-$repo}" in
    /mnt/*)
      origin="$(git -C "$repo" config --get remote.origin.url 2>/dev/null)"
      warn_line "WSL: the repo is under /mnt/ (the Windows drive). WSL keeps its own ~/.claude, separate from Windows."
      fix "git clone ${origin:-<repo-url>} ~/claude-mods   (then run scripts/doctor.sh from there)"
      ;;
    *) say ok "WSL: the repo is in the Linux file system" ;;
  esac
else
  say ok "not WSL"
fi
if [ "$os_kind" = gitbash ]; then
  say note "Git Bash: a link needs Developer Mode or MSYS=winsymlinks:nativestrict (not checked here). Without it a link may be a copy, and this check reports it as shadowed."
elif [ "$os_kind" = cygwin ]; then
  say note "Cygwin: a link needs CYGWIN=winsymlinks:native (not checked here). Without it a link may be a copy, and this check reports it as shadowed."
fi

# ---- Skills --------------------------------------------------------------

kit_names=()
kit_srcs=()
kit_n=0

# add_kit_entry NAME SRC: adds one kit skill. A name already in the list is an error. The first
# copy stays in the list.
add_kit_entry() {
  local name="$1" src="$2" j clash=0
  j=0
  while [ "$j" -lt "$kit_n" ]; do
    if [ "${kit_names[$j]}" = "$name" ]; then
      clash=1
      fail_line error "$name is in both ${kit_srcs[$j]} and $src. Rename one of them (skills.lock.json names the locked skills)."
    fi
    j=$((j + 1))
  done
  [ "$clash" -eq 0 ] || return 0
  kit_names[$kit_n]="$name"
  kit_srcs[$kit_n]="$src"
  kit_n=$((kit_n + 1))
}

# add_kit_root FOLDER: adds each own skill folder (one with a SKILL.md) to the kit list.
add_kit_root() {
  local dir src
  for dir in "$1"/*/; do
    [ -f "${dir}SKILL.md" ] || continue
    src="${dir%/}"
    add_kit_entry "${src##*/}" "$src"
  done
}

# classify LINK SOURCE: sets st (ok, shadowed, broken or missing) and detail.
classify() {
  local t="$1" s="$2" pt ps
  detail=""
  if [ -L "$t" ]; then
    if [ ! -e "$t" ]; then
      st=broken
      detail="link to $(readlink "$t"), whose target is gone"
    else
      pt="$(dep_path_key "$t")"
      ps="$(dep_path_key "$s")"
      if [ -n "$pt" ] && [ "$pt" = "$ps" ]; then
        st=ok
      elif [ -n "$pt" ]; then
        st=shadowed
        detail="link to $pt (not this repo's skills/ or .cache/)"
      else
        st=shadowed
        detail="link to $(readlink "$t") (not this repo's skills/ or .cache/)"
      fi
    fi
  elif [ -e "$t" ]; then
    st=shadowed
    if [ -d "$t" ]; then
      detail="a real folder is in the way"
    else
      detail="a real file is in the way"
    fi
  else
    st=missing
    detail="not in this folder"
  fi
}

# folder_check DIR LABEL FLAG ROLE: FLAG is "" or " --agents" (the install-skills.sh option for this folder).
# ROLE is primary (Claude Code) or shared (~/.agents/skills, read by other harnesses).
folder_check() {
  local dir="$1" label="$2" flag="$3" role="$4" i name src t st detail present parent redo=""
  parent="${dir%/*}"
  if [ ! -d "$dir" ]; then
    if [ -e "$dir" ] || [ -L "$dir" ]; then
      fail_line error "$dir is not a folder (a file or a broken link)."
      fix "mv \"$dir\" \"$parent/before-kit-${dir##*/}\""
    else
      say "not used" "$dir (does not exist)"
    fi
    return
  fi
  present=0
  i=0
  while [ "$i" -lt "$kit_n" ]; do
    name="${kit_names[$i]}"
    if [ -L "$dir/$name" ] || [ -e "$dir/$name" ]; then
      present=1
    fi
    i=$((i + 1))
  done
  if [ "$present" -eq 0 ]; then
    if [ "$role" = primary ]; then
      warn_line "$dir holds no kit skill. If you use Claude Code, install them:"
      fix "\"$repo/scripts/install-skills.sh\"   (or set CLAUDE_SKILLS_DIR to the folder you use)"
    else
      say "not used" "$dir (holds no kit skill)"
    fi
    return
  fi
  used=$((used + 1))
  echo ""
  echo "Folder: $dir ($label)"
  i=0
  while [ "$i" -lt "$kit_n" ]; do
    name="${kit_names[$i]}"
    src="${kit_srcs[$i]}"
    t="$dir/$name"
    classify "$t" "$src"
    if [ -n "$detail" ]; then
      printf '  %-10s %-30s %s\n' "$st" "$name" "$detail"
    else
      printf '  %-10s %s\n' "$st" "$name"
    fi
    if [ "$st" != ok ]; then
      fails=$((fails + 1))
      redo="$redo $name"
      if [ -L "$t" ]; then
        fix "rm \"$t\""
      elif [ -e "$t" ]; then
        fix "mv \"$t\" \"$parent/before-kit-$name\""
      fi
    fi
    i=$((i + 1))
  done
  if [ -n "$redo" ]; then
    fix "\"$repo/scripts/install-skills.sh\"$flag$redo"
  fi
}

echo ""
echo "Skills"
add_kit_root "$repo/skills"
while IFS='|' read -r _ lsrc lname lpath _; do
  [ -n "$lname" ] || continue
  add_kit_entry "$lname" "$cache/$lsrc/$lpath"
done <<< "$(dep_rows_of skill)"
printf '  %d kit skill(s): own in skills/, locked in .cache/ (skills.lock.json)\n' "$kit_n"
folder_check "$claude_dir" "Claude Code" "" primary
folder_check "$agents_dir" "Codex, OpenCode, Gemini CLI" " --agents" shared
if [ "$used" -eq 0 ]; then
  warn_line "No kit skill is installed in any skill folder. Install them:"
  fix "\"$repo/scripts/install-skills.sh\"   (Claude Code)"
  fix "\"$repo/scripts/install-skills.sh\" --agents   (Codex, OpenCode, Gemini CLI)"
fi

# ---- Lock ----------------------------------------------------------------

# installed_here NAME: 1 when a skill entry NAME is in either skill folder.
installed_here() {
  if [ -L "$claude_dir/$1" ] || [ -e "$claude_dir/$1" ] || [ -L "$agents_dir/$1" ] || [ -e "$agents_dir/$1" ]; then
    return 0
  fi
  return 1
}

echo ""
echo "Lock (skills.lock.json; the fetched copies are in .cache/)"
if [ -z "$DEP_ROWS" ]; then
  say note "lock check skipped: skills.lock.json cannot be read (node is missing, or the file is missing or invalid)."
else
  lock_ok=0
  not_fetched=""
  while IFS='|' read -r _ lsrc lname lpath ltree; do
    [ -n "$lname" ] || continue
    dir="$cache/$lsrc/$lpath"
    if [ ! -d "$dir" ]; then
      if installed_here "$lname"; then
        fail_line error "$lname is installed, but its fetched copy is missing ($dir). Run: \"$repo/scripts/fetch-skills.sh\""
      else
        not_fetched="$not_fetched $lname"
      fi
      continue
    fi
    got="$(node "$helper" tree "$dir" 2>/dev/null)"
    if [ "$got" != "$ltree" ]; then
      if installed_here "$lname"; then
        fail_line error "$lname: the fetched copy differs from skills.lock.json (lock ${ltree:0:7}, copy ${got:0:7}). Run: \"$repo/scripts/fetch-skills.sh\" (it restores the recorded commit)"
      else
        warn_line "$lname: the fetched copy differs from skills.lock.json. Not installed, so this is not an error. Run: \"$repo/scripts/fetch-skills.sh\""
      fi
      continue
    fi
    lock_ok=$((lock_ok + 1))
  done <<< "$(dep_rows_of skill)"
  if [ -n "$not_fetched" ]; then
    warn_line "not fetched:$not_fetched. Run: \"$repo/scripts/fetch-skills.sh\" (needed only to install them)"
  fi
  say ok "$lock_ok locked skill(s) match skills.lock.json (git tree hash)"
  while IFS='|' read -r _ csrc cname cfrom ctree cdest; do
    [ -n "$cname" ] || continue
    got=""
    [ -d "$repo/$cdest" ] && got="$(node "$helper" tree "$repo/$cdest" 2>/dev/null)"
    if [ "$got" != "$ctree" ]; then
      warn_line "$cname: $cdest differs from the copy recorded in skills.lock.json (copied from $cfrom). It is an own skill now, so this is not an error. Check the change, then update the lock by hand if it is meant."
    fi
  done <<< "$(dep_rows_of copy)"
fi

# ---- Calls and playbooks -------------------------------------------------

# known: the names a skill may call or mention: the locked skills, the copies and the own skills.
known=" "
if [ -n "$DEP_ROWS" ]; then
  known="$known$(dep_rows_of skill | awk -F'|' '{ printf "%s ", $3 }')$(dep_rows_of copy | awk -F'|' '{ printf "%s ", $3 }')"
fi
for d in "$repo"/skills/*/; do
  if [ -f "${d}SKILL.md" ]; then
    known="$known$(basename "$d") "
  fi
done
echo ""
echo "Calls and mentions (calls and mentions of the locked skills and copies)"
calls_n=0
if [ -z "$DEP_ROWS" ]; then
  say note "calls and mentions not checked: skills.lock.json cannot be read."
else
  while IFS='|' read -r _ esrc eowner ekind ename; do
    [ -n "$ename" ] || continue
    calls_n=$((calls_n + 1))
    case "$known" in
      *" $ename "*) continue ;;
    esac
    if [ "$ekind" = calls ]; then
      fail_line error "$eowner calls $ename, which is not a locked skill, a copy or an own skill in skills/. Add $ename to skills.lock.json, or fix the call."
    else
      warn_line "$eowner mentions $ename, which is not a locked skill, a copy or an own skill in skills/."
    fi
  done <<< "$(dep_rows_of edge)"
  say ok "$calls_n calls and mentions read from skills.lock.json"
fi

# playbook_tokens FILE: "section|token" for each backticked name in the "Skills used" block.
# section is pstack (a "- pstack" bullet), pocock (a "- Pocock" bullet), or nothing (not checked).
playbook_tokens() {
  awk '
    /^Skills used/ { inb = 1; sec = ""; next }
    inb && /^$/ { inb = 0; sec = ""; next }
    !inb { next }
    /^- / {
      sec = ""
      if ($0 ~ /^- pstack[ :(]/) sec = "pstack"
      else if ($0 ~ /^- Pocock[ :(]/) sec = "pocock"
    }
    sec != "" {
      line = $0
      while (match(line, /`[^`]+`/)) {
        tok = substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
        print sec "|" tok
      }
    }
  ' "$1"
}

echo ""
echo "Playbook skill names (the Skills used block of playbooks/*.md)"
pb_checked=0
pb_pstack_skipped=0
pstack_skills=""
if [ -n "$DEP_ROWS" ] && dep_plugin_lookup pstack; then
  pp_path="$(dep_row plugin "$dep_psrc" | awk -F'|' '{ print $3 }')"
  pstack_skills="$cache/$dep_psrc/$pp_path/skills"
fi
for pb in "$repo"/playbooks/*.md; do
  [ -f "$pb" ] || continue
  pbname="$(basename "$pb")"
  while IFS='|' read -r psec ptok; do
    [ -n "$ptok" ] || continue
    ptok="${ptok#/}"
    case "$ptok" in
      "" | *[!a-z0-9-]*) continue ;;
    esac
    pb_checked=$((pb_checked + 1))
    if [ "$psec" = pocock ]; then
      case "$known" in
        *" $ptok "*) ;;
        *) warn_line "$pbname: Pocock skill \`$ptok\` is not a locked skill, a copy or an own skill." ;;
      esac
    else
      if [ -z "$pstack_skills" ] || [ ! -d "$pstack_skills" ]; then
        pb_pstack_skipped=1
      elif [ ! -f "$pstack_skills/$ptok/SKILL.md" ]; then
        warn_line "$pbname: pstack skill \`$ptok\` is not in the locked pstack plugin ($pstack_skills)."
      fi
    fi
  done <<< "$(playbook_tokens "$pb")"
done
if [ "$pb_pstack_skipped" -eq 1 ]; then
  say note "pstack names in the playbooks not checked: the locked pstack copy is missing. Run: \"$repo/scripts/fetch-skills.sh\""
fi
say ok "$pb_checked name(s) read from the playbooks (a warning above names any that is not found)"

# ---- Plugins -------------------------------------------------------------

# dep_lines_out: prints the findings of dep_plugin_lines with the right level.
dep_lines_out() {
  local lvl txt
  while IFS="$(printf '\t')" read -r lvl txt; do
    [ -n "$lvl" ] || continue
    case "$lvl" in
      warn) warn_line "$txt" ;;
      ok) say ok "$txt" ;;
      *) say note "$txt" ;;
    esac
  done <<< "$(dep_plugin_lines)"
}

echo ""
echo "Plugins (optional; from requires.plugins in skills.lock.json)"
if [ -z "$DEP_ROWS" ]; then
  say note "plugin check skipped: skills.lock.json cannot be read."
else
  plugin_names="$(dep_rows_of plugin-req | awk -F'|' '{ print $2 }')"
  if [ -z "$plugin_names" ]; then
    say note "no plugin is named in skills.lock.json."
  fi
  for pn in $plugin_names; do
    dep_plugin_scan "$pn" "$PWD" "$claude_dir" "$agents_dir"
    locked_v="$(dep_row plugin "$dep_psrc" | awk -F'|' '{ print $5 }')"
    if [ -n "$dep_pcommit" ]; then
      say ok "$pn: locked at version ${locked_v:-unknown}, commit ${dep_pcommit:0:7}, minimum $dep_pmin. Source: $dep_plink"
    fi
    dep_lines_out
    if [ "$dep_overall" = not_found ]; then
      fix "bash \"$repo/scripts/fetch-skills.sh\"   (once, to fetch the locked copy)"
      if [ "$pn" = pstack ]; then
        fix "bash \"$repo/scripts/bootstrap-project.sh\" <project> --pstack <local|user>   (installs it from the locked copy for one project)"
      else
        fix "install $pn by hand, from $dep_plink"
      fi
    fi
  done
fi

# ---- Result --------------------------------------------------------------

echo ""
if [ "$fails" -eq 0 ]; then
  echo "Result: no failures, $warns warning(s)."
  exit 0
fi
echo "Result: $fails failure(s), $warns warning(s). Run the fix commands above, then run this check again."
exit 1

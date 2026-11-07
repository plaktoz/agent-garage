# lib-deps.sh: read-only checks of the dependencies that skills.lock.json names. Sourced, not run.
#
#   DEP_REPO="<repo root>"; . "$DEP_REPO/scripts/lib-deps.sh"; dep_init
#
# One check for every dependency, in three kinds. Each is read only (no install, no update):
#   tool    a command on PATH.                      Lock: requires.tools
#   plugin  a Claude Code plugin, read with         Lock: requires.plugins (id, source, marketplace),
#           `claude plugin list --json` and         and sources (url, minimumVersion, link)
#           `claude plugin marketplace list --json`
#   skill   an entry in a skill folder:             ~/.claude/skills, ~/.agents/skills and the
#           ~/.claude/skills, ~/.agents/skills,     project's .agents/skills (the caller names them)
#           <project>/.agents/skills
# No dependency is named in this file. The id, the minimum version and the link of a plugin come
# from the lock, so a new entry in requires needs no change here.
#
# Answers: found, not_found, or skipped (the checking tool is missing or its output is unreadable).
# A skipped check is never read as "not found". Results are plain variables, so each caller decides
# what to print and what counts as a failure:
#   dep_tool NAME                 dep_state, dep_detail (path), dep_version
#   dep_plugin_scan NAME PROJECT [SKILL_DIR...]
#                                 dep_overall = found_here | found_linked | found_elsewhere |
#                                               not_found | skipped
#                                 dep_here, dep_other: lines "scope|version|projectPath|enabled|installPath"
#                                 dep_links: lines "<entry>  ->  <target>" (skill entries from the plugin)
#                                 dep_pstate, dep_pdetail (plugin list), dep_mstate, dep_mkt (marketplace)
#   dep_plugin_lines              after a scan: one line per finding, "level<TAB>text", level ok|note|warn
#   dep_path_key PATH             the physical path of a folder, for comparing two folders (lower case on Windows)
#
# found_here      installed for PROJECT (user scope, or the project path is PROJECT)
# found_linked    the plugin's skills are linked in a skill folder (no plugin install needed to find them)
# found_elsewhere installed only for other projects (does not count for PROJECT)
#
# The JSON is read with node. Runs on bash 3.2, macOS, Linux, WSL and Git Bash, with or without
# set -e and pipefail in the caller.

dep_init() {
  DEP_LOCK="$DEP_REPO/skills.lock.json"
  DEP_HELPER="$DEP_REPO/scripts/skills-lock.cjs"
  DEP_ROWS=""
  DEP_HAS_NODE=0
  dep_state=""
  dep_detail=""
  dep_version=""
  dep_installs=""
  dep_mkt=""
  dep_pid=""
  dep_psrc=""
  dep_pmkt=""
  dep_pusers=""
  dep_purl=""
  dep_pcommit=""
  dep_pmin=""
  dep_plink=""
  dep_pname=""
  dep_overall=""
  dep_here=""
  dep_other=""
  dep_links=""
  dep_pstate=""
  dep_pdetail=""
  dep_mstate=""
  if command -v node >/dev/null 2>&1 && [ -f "$DEP_LOCK" ] && [ -f "$DEP_HELPER" ]; then
    if DEP_ROWS="$(node "$DEP_HELPER" list "$DEP_LOCK" 2>/dev/null)"; then
      DEP_HAS_NODE=1
    else
      DEP_ROWS=""
    fi
  fi
}

# dep_rows_of KIND: every row of one kind (source, skill, copy, edge, plugin, tool, plugin-req).
dep_rows_of() {
  printf '%s\n' "$DEP_ROWS" | awk -F'|' -v k="$1" '$1 == k'
}

# dep_row KIND NAME: the first row of one kind whose name (field 2) is NAME.
dep_row() {
  printf '%s\n' "$DEP_ROWS" | awk -F'|' -v k="$1" -v n="$2" '$1 == k && $2 == n && !d { print; d = 1 }'
}

# dep_tool NAME: a command on PATH. Sets dep_state, dep_detail (the path), dep_version (first line).
dep_tool() {
  dep_version=""
  if command -v "$1" >/dev/null 2>&1; then
    dep_state=found
    dep_detail="$(command -v "$1")"
    dep_version="$("$1" --version 2>/dev/null | awk 'NR == 1')" || dep_version=""
  else
    dep_state=not_found
    dep_detail="not on PATH"
  fi
  return 0
}

# dep_plugin_lookup NAME: loads the lock's plugin NAME and its source. Returns 1 when the lock has
# no such plugin. Sets dep_pname, dep_pid, dep_psrc, dep_pmkt, dep_pusers, dep_purl, dep_pcommit,
# dep_pmin, dep_plink.
dep_plugin_lookup() {
  local r s
  dep_pname="$1"
  dep_pid=""
  dep_psrc=""
  dep_pmkt=""
  dep_pusers=""
  dep_purl=""
  dep_pcommit=""
  dep_pmin=""
  dep_plink=""
  r="$(dep_row plugin-req "$1")"
  [ -n "$r" ] || return 1
  IFS='|' read -r _ _ dep_pid dep_psrc dep_pmkt dep_pusers <<< "$r"
  s="$(dep_row source "$dep_psrc")"
  [ -n "$s" ] || return 1
  IFS='|' read -r _ _ dep_purl dep_pcommit dep_pmin dep_plink _ <<< "$s"
  return 0
}

# dep_claude_ready: returns 0 when claude and node can both be used for a read. Otherwise sets
# dep_state=skipped and dep_detail to the reason, and returns 1.
dep_claude_ready() {
  if ! command -v claude >/dev/null 2>&1; then
    dep_state=skipped
    dep_detail="no claude command on PATH"
    return 1
  fi
  if [ "$DEP_HAS_NODE" -ne 1 ]; then
    dep_state=skipped
    dep_detail="node is not installed, or skills.lock.json is not readable (the JSON of claude is read with node)"
    return 1
  fi
  return 0
}

# dep_plugin_installs ID: the installs of plugin ID that claude knows. Runs in the current folder
# (claude plugin list reads the project scope from it). Sets dep_state, dep_detail, dep_installs.
dep_plugin_installs() {
  local pjson rc=0 out
  dep_installs=""
  dep_claude_ready || return 0
  pjson="$(claude plugin list --json 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    dep_state=skipped
    dep_detail="claude plugin list --json exited $rc"
    return 0
  fi
  if ! out="$(node -e '
    var j = JSON.parse(require("fs").readFileSync(0, "utf8"));
    j.forEach(function (p) {
      if (p.id === process.argv[1]) {
        console.log([p.scope, p.version, p.projectPath || "", p.enabled ? "enabled" : "disabled", p.installPath || ""].join("|"));
      }
    });' "$1" 2>/dev/null <<< "$pjson")"; then
    dep_state=skipped
    dep_detail="the output of claude plugin list --json is not JSON"
    return 0
  fi
  dep_installs="$out"
  if [ -n "$dep_installs" ]; then
    dep_state=found
    dep_detail="installed"
  else
    dep_state=not_found
    dep_detail="not installed"
  fi
  return 0
}

# dep_marketplace_lookup NAME: the marketplace NAME that claude knows. Sets dep_state, dep_detail
# and dep_mkt (name|source|path|repo).
dep_marketplace_lookup() {
  local mjson rc=0 out
  dep_mkt=""
  dep_claude_ready || return 0
  mjson="$(claude plugin marketplace list --json 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    dep_state=skipped
    dep_detail="claude plugin marketplace list --json exited $rc"
    return 0
  fi
  if ! out="$(node -e '
    var j = JSON.parse(require("fs").readFileSync(0, "utf8"));
    j.forEach(function (p) {
      if (p.name === process.argv[1]) {
        console.log([p.name, p.source || "", p.path || "", p.repo || ""].join("|"));
      }
    });' "$1" 2>/dev/null <<< "$mjson")"; then
    dep_state=skipped
    dep_detail="the output of claude plugin marketplace list --json is not JSON"
    return 0
  fi
  dep_mkt="$out"
  if [ -n "$dep_mkt" ]; then
    dep_state=found
    dep_detail="configured"
  else
    dep_state=not_found
    dep_detail="not configured"
  fi
  return 0
}

# dep_skill NAME DIR...: a skill entry NAME (link, folder or file) in any of the folders. Sets
# dep_state (found or not_found) and dep_detail, one "entry (kind)" per hit. Read only.
dep_skill() {
  local name="$1" d hits="" t
  shift
  for d in "$@"; do
    t="$d/$name"
    if [ -L "$t" ]; then
      hits="$hits $t (link)"
    elif [ -d "$t" ]; then
      hits="$hits $t (folder)"
    elif [ -e "$t" ]; then
      hits="$hits $t (file)"
    fi
  done
  if [ -n "$hits" ]; then
    dep_state=found
    dep_detail="${hits# }"
  else
    dep_state=not_found
    dep_detail="not in any of the folders given"
  fi
  return 0
}

# dep_skill_links PATTERN DIR...: skill entries in the folders that are links whose target matches
# the glob PATTERN. Prints "<entry>  ->  <target>", one per line.
dep_skill_links() {
  local pat="$1" d e t
  shift
  for d in "$@"; do
    [ -d "$d" ] || continue
    for e in "$d"/*; do
      [ -L "$e" ] || continue
      t="$(readlink "$e")"
      case "$t" in
        $pat) printf '%s  ->  %s\n' "$e" "$t" ;;
      esac
    done
  done
  return 0
}

# dep_ver_state VERSION MIN: prints ok (at or above MIN), old (below), or unknown (not numbers).
dep_ver_state() {
  if [ -z "$2" ]; then
    echo unknown
    return 0
  fi
  case "$1" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *)
      echo unknown
      return 0
      ;;
  esac
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    k = (n > m) ? n : m
    for (i = 1; i <= k; i++) {
      p = x[i] + 0; q = y[i] + 0
      if (p > q) { print "ok"; exit }
      if (p < q) { print "old"; exit }
    }
    print "ok"
  }'
}

# dep_path_key PATH: the physical path of an existing folder, for comparing two folders. Git Bash and
# Cygwin ignore case in paths, so the key is lower case there. Prints nothing when PATH is not a folder.
dep_path_key() {
  local p
  p="$(cd "$1" 2>/dev/null && pwd -P)" || return 0
  case "$(uname -s 2>/dev/null)" in
    MINGW* | MSYS* | CYGWIN*) p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')" ;;
  esac
  printf '%s' "$p"
}

# dep_plugin_scan NAME PROJECT [SKILL_DIR...]: see the header. Read only.
dep_plugin_scan() {
  local name="$1" proj="$2" scope version ppath enabled ipath pphys start="$PWD"
  shift 2
  dep_overall=""
  dep_here=""
  dep_other=""
  dep_links=""
  dep_pstate=""
  dep_pdetail=""
  dep_mstate=""
  dep_mkt=""
  if ! dep_plugin_lookup "$name"; then
    dep_overall=skipped
    dep_pstate=skipped
    dep_pdetail="skills.lock.json has no requires.plugins entry named $name (or no matching source)"
    return 0
  fi
  # Skill entries that link into the plugin's own files: the plugin name or its source name in the target.
  dep_links="$(dep_skill_links "*$dep_pname*" "$@"; dep_skill_links "*$dep_psrc*" "$@")"
  dep_links="$(printf '%s\n' "$dep_links" | awk 'NF && !seen[$0]++')"
  cd "$proj" 2>/dev/null || true
  dep_plugin_installs "$dep_pid"
  dep_pstate="$dep_state"
  dep_pdetail="$dep_detail"
  dep_marketplace_lookup "$dep_pmkt"
  dep_mstate="$dep_state"
  cd "$start" 2>/dev/null || true
  if [ "$dep_pstate" = found ]; then
    pphys="$proj"
    [ -d "$proj" ] && pphys="$(dep_path_key "$proj")"
    while IFS='|' read -r scope version ppath enabled ipath; do
      [ -n "$scope" ] || continue
      local pp="$ppath"
      if [ -n "$ppath" ] && [ -d "$ppath" ]; then pp="$(dep_path_key "$ppath")"; fi
      if [ "$scope" = user ] || [ "$pp" = "$pphys" ]; then
        dep_here="$dep_here$scope|$version|$ppath|$enabled|$ipath
"
      else
        dep_other="$dep_other$scope|$version|$ppath|$enabled|$ipath
"
      fi
    done <<< "$dep_installs"
  fi
  if [ -n "$dep_here" ]; then
    dep_overall=found_here
  elif [ -n "$dep_links" ]; then
    dep_overall=found_linked
  elif [ -n "$dep_other" ]; then
    dep_overall=found_elsewhere
  elif [ "$dep_pstate" = skipped ]; then
    dep_overall=skipped
  else
    dep_overall=not_found
  fi
  return 0
}

# dep_plugin_lines: after dep_plugin_scan. One finding per line, "level<TAB>text". Every text that
# names the plugin ends with its source link from the lock.
dep_plugin_lines() {
  local scope version ppath enabled ipath target line tab
  tab="$(printf '\t')"
  if [ "$dep_pstate" = skipped ]; then
    printf 'note%s%s\n' "$tab" "$dep_pname: check skipped ($dep_pdetail). Source: ${dep_plink:-not in the lock}"
  fi
  while IFS='|' read -r scope version ppath enabled ipath; do
    [ -n "$scope" ] || continue
    target="every project (user scope)"
    [ "$scope" = user ] || target="$ppath"
    case "$(dep_ver_state "$version" "$dep_pmin")" in
      old)
        printf 'warn%s%s\n' "$tab" "$dep_pname $version is installed (scope $scope, $enabled, for $target), below the minimum $dep_pmin in skills.lock.json. It is used as it is. Updating is a separate step that you must ask for. Source: $dep_plink"
        ;;
      ok)
        printf 'ok%s%s\n' "$tab" "$dep_pname $version is installed (scope $scope, $enabled, for $target), at or above the minimum $dep_pmin. Source: $dep_plink"
        ;;
      *)
        printf 'note%s%s\n' "$tab" "$dep_pname $version is installed (scope $scope, $enabled, for $target); the version is not recognised, so it was not compared with the minimum $dep_pmin. Source: $dep_plink"
        ;;
    esac
  done <<< "$dep_here"
  while IFS='|' read -r scope version ppath enabled ipath; do
    [ -n "$scope" ] || continue
    case "$(dep_ver_state "$version" "$dep_pmin")" in
      old)
        printf 'warn%s%s\n' "$tab" "$dep_pname $version is installed for another project (scope $scope, $enabled, $ppath), below the minimum $dep_pmin. That does not count for this project. Updating it is a separate step that you must ask for. Source: $dep_plink"
        ;;
      *)
        printf 'note%s%s\n' "$tab" "$dep_pname $version is also installed for another project (scope $scope, $enabled, $ppath). That does not count for this project. Source: $dep_plink"
        ;;
    esac
  done <<< "$dep_other"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf 'ok%s%s\n' "$tab" "$dep_pname skills are linked: $line. Source: $dep_plink"
  done <<< "$dep_links"
  case "$dep_mstate" in
    found)
      printf 'note%s%s\n' "$tab" "marketplace $dep_pmkt is configured: $(printf '%s' "$dep_mkt" | awk -F'|' '{ print "source " $2 (($4 != "") ? ", repo " $4 : "") (($3 != "") ? ", path " $3 : "") }'). Source: $dep_plink"
      ;;
    not_found)
      printf 'note%s%s\n' "$tab" "marketplace $dep_pmkt is not configured. Source: $dep_plink"
      ;;
  esac
  if [ "$dep_overall" = not_found ]; then
    local rec
    rec="$(dep_row plugin "$dep_psrc" | awk -F'|' '{ print $5 }')"
    printf 'note%s%s\n' "$tab" "$dep_pname is not found on this machine (no install, no linked skill). Source: $dep_plink  (lock records version ${rec:-unknown} at commit ${dep_pcommit:0:7}; minimum $dep_pmin)"
  fi
  return 0
}

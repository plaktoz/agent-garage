#!/usr/bin/env bash
# Fetch the third-party skills and plugins that skills.lock.json names, into .cache/<source>/
# (git-ignored), at the commit the lock records. Then check each tree hash against the lock.
#
# Usage: scripts/fetch-skills.sh [--source <name>] [--update]
#   (no option)      Check the cache against the lock. Network is used only when a clone, a commit
#                    or a checkout is missing. With everything present it makes no network call.
#   --source <name>  Only this source (mattpocock-skills or pstack-claude).
#   --update         Move each source to the newest commit of its default branch (network),
#                    recompute each path and tree hash, and rewrite skills.lock.json. Review the
#                    change with `git diff skills.lock.json`. calls and mentions are NOT changed:
#                    re-read the SKILL.md of each changed skill and edit them by hand.
#                    Nothing is written when a locked skill is missing or found twice upstream.
#   -h, --help       Show this help.
#
# Status per skill: ok (already there), fetched (this run cloned, fetched or checked out),
#   changed (tree hash differs; a problem), missing upstream (path not in the commit; a problem).
# Exit status: 0 ok, 1 a problem (network, missing skill, hash mismatch, bad lock), 2 usage error.
#
# Needs git and node (node reads the lock with scripts/skills-lock.cjs). Plain bash 3.2, the same
# on macOS, Linux, WSL and Git Bash. No jq, no python.

set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
lock="$repo/skills.lock.json"
helper="$here/skills-lock.cjs"
cache="$repo/.cache"
only=""
update=0
problems=0
ok_n=0
fetched_n=0
cur_src=""
cur_url=""
cur_commit=""
cur_skip=0
cur_bad=0
fetched_here=0
new_commit=""

usage() {
  cat <<'EOF'
Usage: scripts/fetch-skills.sh [--source <name>] [--update]

Fetches the skills and plugins that skills.lock.json names into .cache/<source>/ (git-ignored),
at the recorded commit, and checks each tree hash against the lock.

  --source <name>  Only this source (mattpocock-skills or pstack-claude).
  --update         Move each source to the newest commit of its default branch (network),
                   recompute paths and tree hashes, rewrite skills.lock.json, and list what changed.
                   Review it with: git diff skills.lock.json
                   calls and mentions are not changed: re-check them by hand.
                   Nothing is written if a locked skill is missing or found twice upstream.
  -h, --help       Show this help.

Exit status: 0 ok, 1 a problem (network, missing skill, hash mismatch, bad lock), 2 usage error.
EOF
}

usage_error() {
  echo "error: $1" >&2
  echo "Run with --help for usage." >&2
  exit 2
}

# problem TEXT: a failure, printed to stderr. The run exits 1.
problem() {
  echo "error  $1" >&2
  problems=$((problems + 1))
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --update) update=1 ;;
    --source)
      [ "$#" -ge 2 ] || usage_error "--source needs a source name"
      only="$2"
      shift
      ;;
    --source=*) only="${1#--source=}" ;;
    *) usage_error "unknown argument: $1" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || { echo "error: git is not installed. Nothing was fetched." >&2; exit 1; }
command -v node >/dev/null 2>&1 || {
  echo "error: node is not installed. It reads skills.lock.json. Install node, then run again. Nothing was fetched." >&2
  exit 1
}
[ -f "$lock" ] || { echo "error: no lock file at $lock" >&2; exit 1; }

rows="$(node "$helper" list "$lock")" || { echo "error: could not read $lock (see the message above)." >&2; exit 1; }
src_names="$(printf '%s\n' "$rows" | awk -F'|' '$1 == "source" { printf "%s ", $2 }')"

if [ -n "$only" ]; then
  case " $src_names" in
    *" $only "*) ;;
    *) usage_error "no source named $only in skills.lock.json (sources: ${src_names% })" ;;
  esac
fi

tmpdir="$(mktemp -d)" || { echo "error: could not make a temporary folder." >&2; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT
updfile="$tmpdir/updates.txt"
: > "$updfile"

# names_of KIND SRC: the skill or copy names of one source, one per line.
names_of() {
  printf '%s\n' "$rows" | awk -F'|' -v k="$1" -v s="$2" '$1 == k && $2 == s { print $3 }'
}

# ensure_clone SRC URL: a partial clone (blobs on demand) with no checkout. Network only if missing.
ensure_clone() {
  local dir="$cache/$1" have
  if [ -d "$dir/.git" ]; then
    # The lock URL is the source of truth: a clone that points elsewhere is moved to it.
    have="$(git -C "$dir" remote get-url origin 2>/dev/null)"
    if [ "$have" != "$2" ]; then
      git -C "$dir" remote set-url origin "$2" || { problem "source $1: cannot set origin to $2"; return 1; }
    fi
    return 0
  fi
  if [ -e "$dir" ]; then
    problem "source $1: $dir exists but is not a git clone. Remove it, then run again."
    return 1
  fi
  mkdir -p "$cache" || { problem "source $1: cannot create $cache"; return 1; }
  if ! git clone -q --filter=blob:none --no-checkout "$2" "$dir" 2>"$tmpdir/clone.err"; then
    problem "source $1: cannot clone $2. Network? $(head -n 1 "$tmpdir/clone.err")"
    rm -rf "$dir"
    return 1
  fi
  fetched_here=1
}

# ensure_commit SRC COMMIT: the commit is in the clone. Network only if it is missing.
ensure_commit() {
  local dir="$cache/$1"
  if git -C "$dir" cat-file -e "$2^{commit}" 2>/dev/null; then
    return 0
  fi
  if ! git -C "$dir" fetch -q --filter=blob:none origin "$2" 2>"$tmpdir/fetch.err"; then
    problem "source $1: cannot fetch commit ${2:0:7} from $cur_url. Network? $(head -n 1 "$tmpdir/fetch.err")"
    return 1
  fi
  fetched_here=1
}

# ensure_checkout SRC COMMIT: the working tree is the commit, detached. Network only if files are missing.
ensure_checkout() {
  local dir="$cache/$1" cur dirty
  cur="$(git -C "$dir" rev-parse -q --verify HEAD 2>/dev/null)"
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null)"
  if [ "$cur" = "$2" ] && [ -z "$dirty" ]; then
    return 0
  fi
  if ! git -C "$dir" checkout -q -f --detach "$2" 2>"$tmpdir/checkout.err"; then
    problem "source $1: cannot check out ${2:0:7}. $(head -n 1 "$tmpdir/checkout.err")"
    return 1
  fi
  fetched_here=1
}

# skill_dirs COMMIT SRC: "name<TAB>path" for each folder that has a SKILL.md at the commit.
skill_dirs() {
  git -C "$cache/$2" ls-tree -r --name-only "$1" 2>/dev/null | awk -F/ '
    $NF == "SKILL.md" && NF >= 2 {
      d = ""
      for (i = 1; i < NF; i++) d = (i == 1) ? $i : d "/" $i
      print $(NF - 1) "\t" d
    }'
}

# start_source NAME URL COMMIT: called for each source row. Prepares the clone and the commit.
start_source() {
  cur_src="$1"
  cur_url="${2%.git}"
  cur_commit="$3"
  cur_skip=0
  cur_bad=0
  fetched_here=0
  if [ -n "$only" ] && [ "$only" != "$cur_src" ]; then
    cur_skip=1
    return 0
  fi
  echo ""
  if [ "$update" -eq 0 ]; then
    echo "source $cur_src  $cur_url  commit ${cur_commit:0:7}"
  else
    echo "update $cur_src  $cur_url  (lock has ${cur_commit:0:7})"
  fi
  if ! ensure_clone "$cur_src" "$2"; then cur_bad=1; return 0; fi
  if [ "$update" -eq 0 ]; then
    if ! ensure_commit "$cur_src" "$cur_commit" || ! ensure_checkout "$cur_src" "$cur_commit"; then
      cur_bad=1
    fi
  else
    update_source_head || cur_bad=1
  fi
}

# update_source_head: moves the clone to the newest default-branch commit and records it in updfile.
update_source_head() {
  local dir="$cache/$cur_src" tip date extra="" n p known
  tip="$(git -C "$dir" ls-remote origin HEAD 2>"$tmpdir/ls.err" | awk 'NR == 1 { print $1 }')"
  if [ "${#tip}" -ne 40 ]; then
    problem "source $cur_src: cannot read the newest commit from $cur_url. Nothing was changed. $(head -n 1 "$tmpdir/ls.err")"
    return 1
  fi
  if ! git -C "$dir" fetch -q --filter=blob:none origin "$tip" 2>"$tmpdir/fetch.err"; then
    problem "source $cur_src: cannot fetch ${tip:0:7} from $cur_url. Nothing was changed. $(head -n 1 "$tmpdir/fetch.err")"
    return 1
  fi
  if ! git -C "$dir" checkout -q -f --detach "$tip" 2>"$tmpdir/checkout.err"; then
    problem "source $cur_src: cannot check out ${tip:0:7}. Nothing was changed. $(head -n 1 "$tmpdir/checkout.err")"
    return 1
  fi
  fetched_here=1
  new_commit="$tip"
  date="$(git -C "$dir" log -1 --format=%cs "$tip")"
  printf 'commit|%s|%s|%s\n' "$cur_src" "$tip" "$date" >> "$updfile"
  echo "  newest commit ${tip:0:7} ($date)"
  # A source that lists its skills: upstream skills the lock does not list are reported, not added
  # (each needs its calls and mentions, which only a person can set).
  if [ -n "$(names_of skill "$cur_src")" ]; then
    known=" $(names_of skill "$cur_src" | tr '\n' ' ')$(names_of copy "$cur_src" | tr '\n' ' ') "
    while IFS="$(printf '\t')" read -r n p; do
      [ -n "$n" ] || continue
      case "$known" in
        *" $n "*) ;;
        *) extra="$extra $n" ;;
      esac
    done <<< "$(skill_dirs "$tip" "$cur_src")"
    if [ -n "$extra" ]; then
      echo "  new     upstream skills not in the lock (not added):$extra"
      echo "          to use one, add it to skills.lock.json by hand, with its calls and mentions"
    fi
  fi
  return 0
}

# check_skill NAME PATH TREE: one status line for a locked skill (no --update).
check_skill() {
  local name="$1" path="$2" tree="$3" dir="$cache/$cur_src" got status
  got="$(git -C "$dir" rev-parse -q --verify "$cur_commit:$path" 2>/dev/null)"
  if [ -z "$got" ]; then
    status="missing upstream"
    problem "$cur_src/$name: path $path is not in commit ${cur_commit:0:7}. Upstream: $cur_url"
  elif [ "$got" != "$tree" ]; then
    status="changed (tree hash differs)"
    problem "$cur_src/$name: lock has tree ${tree:0:7}, commit ${cur_commit:0:7} has ${got:0:7} at $path. Do not edit the lock by hand; restore it, or run --update after review. Upstream: $cur_url"
  elif [ ! -f "$dir/$path/SKILL.md" ]; then
    status="missing upstream"
    problem "$cur_src/$name: no $path/SKILL.md in the checkout."
  elif [ "$fetched_here" -eq 1 ]; then
    status="fetched"
    fetched_n=$((fetched_n + 1))
  else
    status="ok"
    ok_n=$((ok_n + 1))
  fi
  printf '  %-28s %s/%s\n' "$status" "$cur_src" "$name"
}

# find_skill NAME: --update. Looks up the folder with this name in the new commit, and records it.
find_skill() {
  local name="$1" hits count p got
  hits="$(skill_dirs "$new_commit" "$cur_src" | awk -F'\t' -v n="$name" '$1 == n { print $2 }')"
  count="$(printf '%s' "$hits" | grep -c .)"
  if [ "$count" -eq 0 ]; then
    problem "$cur_src/$name: not found in commit ${new_commit:0:7}. Not changed. Fix the lock by hand, then run again."
    return 0
  fi
  if [ "$count" -gt 1 ]; then
    problem "$cur_src/$name: found $count times in commit ${new_commit:0:7} ($(printf '%s' "$hits" | tr '\n' ' ')). Not changed."
    return 0
  fi
  p="$hits"
  got="$(git -C "$cache/$cur_src" rev-parse -q --verify "$new_commit:$p" 2>/dev/null)"
  printf 'skill|%s|%s|%s|%s\n' "$cur_src" "$name" "$p" "$got" >> "$updfile"
  echo "  found   $cur_src/$name at $p"
}

# plugin_check PATH TREE VERSION: one status line for a plugin entry (no --update).
plugin_check() {
  local ppath="$1" ptree="$2" pver="$3" got status
  got="$(git -C "$cache/$cur_src" rev-parse -q --verify "$cur_commit:$ppath" 2>/dev/null)"
  if [ -z "$got" ]; then
    status="missing upstream"
    problem "$cur_src: plugin folder $ppath is not in commit ${cur_commit:0:7}. Upstream: $cur_url"
  elif [ "$got" != "$ptree" ]; then
    status="changed (tree hash differs)"
    problem "$cur_src: plugin tree hash in the lock is ${ptree:0:7}, commit ${cur_commit:0:7} has ${got:0:7} at $ppath. Upstream: $cur_url"
  elif [ "$fetched_here" -eq 1 ]; then
    status="fetched"
    fetched_n=$((fetched_n + 1))
  else
    status="ok"
    ok_n=$((ok_n + 1))
  fi
  printf '  %-28s %s plugin %s (version %s)\n' "$status" "$cur_src" "$ppath" "$pver"
}

# update_plugin PATH: --update. Records the plugin folder and version at the new commit.
update_plugin() {
  local ppath="$1" ptree version=""
  ptree="$(git -C "$cache/$cur_src" rev-parse -q --verify "$new_commit:$ppath" 2>/dev/null)"
  if [ -z "$ptree" ]; then
    problem "$cur_src: plugin folder $ppath is not in commit ${new_commit:0:7}. Not changed."
    return 0
  fi
  if git -C "$cache/$cur_src" show "$new_commit:$ppath/.claude-plugin/plugin.json" > "$tmpdir/plugin.json" 2>/dev/null; then
    version="$(node "$helper" field "$tmpdir/plugin.json" version 2>/dev/null)"
  fi
  if [ -z "$version" ]; then
    echo "  note    $cur_src: no version in $ppath/.claude-plugin/plugin.json; the lock keeps its version."
  else
    echo "  plugin  $ppath at version $version"
  fi
  printf 'plugin|%s|%s|%s|%s\n' "$cur_src" "$ppath" "$ptree" "$version" >> "$updfile"
}

# ---- Main: one pass over the lock rows (read from fd 3, so git cannot take them) -----------------

while IFS='|' read -r kind f2 f3 f4 f5 _ <&3; do
  case "$kind" in
    source)
      start_source "$f2" "$f3" "$f4"
      ;;
    skill)
      [ "$cur_skip" -eq 0 ] && [ "$f2" = "$cur_src" ] || continue
      if [ "$cur_bad" -eq 1 ]; then
        printf '  %-28s %s/%s\n' "not checked" "$cur_src" "$f3"
      elif [ "$update" -eq 1 ]; then
        find_skill "$f3"
      else
        check_skill "$f3" "$f4" "$f5"
      fi
      ;;
    plugin)
      [ "$cur_skip" -eq 0 ] && [ "$f2" = "$cur_src" ] || continue
      if [ "$cur_bad" -eq 1 ]; then
        printf '  %-28s %s plugin %s\n' "not checked" "$cur_src" "$f3"
      elif [ "$update" -eq 1 ]; then
        update_plugin "$f3"
      else
        plugin_check "$f3" "$f4" "$f5"
      fi
      ;;
  esac
done 3<<< "$rows"

# Copies are not fetched. Say so once, for the sources in this run.
copy_note=""
for src in $src_names; do
  [ -z "$only" ] || [ "$only" = "$src" ] || continue
  c="$(names_of copy "$src" | tr '\n' ' ')"
  [ -z "$c" ] || copy_note="$copy_note$src: ${c% } "
done
if [ "$update" -eq 0 ] && [ -n "$copy_note" ]; then
  echo ""
  echo "not fetched (copied into skills/; see the copies entry in skills.lock.json): $copy_note"
fi

if [ "$update" -eq 1 ]; then
  if [ "$problems" -gt 0 ]; then
    echo ""
    echo "Result: $problems problem(s). skills.lock.json was NOT rewritten."
    exit 1
  fi
  echo ""
  if ! node "$helper" apply "$lock" "$updfile"; then
    echo "Result: could not rewrite skills.lock.json. See the message above." >&2
    exit 1
  fi
  echo ""
  echo "Next: review the change with: git diff skills.lock.json"
  echo "      calls and mentions were not changed. For each changed skill, re-read its SKILL.md for"
  echo "      new Skill-tool calls or skill names, and edit calls and mentions by hand."
  echo "      Then run scripts/fetch-skills.sh and scripts/doctor.sh."
  exit 0
fi

echo ""
if [ "$problems" -gt 0 ]; then
  echo "Result: $problems problem(s), $ok_n ok, $fetched_n fetched. Fix the problem(s) above, then run again."
  exit 1
fi
echo "Result: every locked skill and plugin is present and matches the lock: $ok_n ok, $fetched_n fetched."
exit 0

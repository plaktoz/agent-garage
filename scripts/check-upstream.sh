#!/usr/bin/env bash
# Check whether the sources in skills.lock.json moved upstream. Report only: it recommends one next
# step and never acts. It writes no file in the repo (it works in a temporary folder).
#
# Usage: scripts/check-upstream.sh [--source <name>]
#   --source <name>  Only this source (mattpocock-skills, ambition, good-readme or pstack-claude).
#   -h, --help       Show this help.
#
# For each source it compares the locked commit with the upstream head (git ls-remote). When the
# head moved it makes a temporary bare clone and reports:
#   - how many commits the head is ahead of the lock
#   - each locked skill whose folder changed, moved, or is gone (tree hash at the new head)
#   - skills added upstream since the lock (information only)
#   - for a plugin: the version at the new head against the lock and the minimum
#   - each top-level LICENSE, LICENCE or COPYING file added, removed or changed since the lock
# It does not check any skill of this
# repo. Only `scripts/fetch-skills.sh --update` changes the lock.
#
# Exit status: 0 nothing moved, 1 upstream moved, 2 usage error, 3 the check could not run
# (no network, no git or node, bad lock). Plain bash 3.2; needs git and node.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
lock="$repo/skills.lock.json"
helper="$here/skills-lock.cjs"
only=""

usage() {
  sed -n '2,/^set -u$/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --source)
      [ "$#" -ge 2 ] || { echo "error: --source needs a name" >&2; exit 2; }
      only="$2"; shift ;;
    *) echo "error: unknown option: $1" >&2; echo "Run with --help for usage." >&2; exit 2 ;;
  esac
  shift
done

cannot() { echo "error: $1" >&2; exit 3; }

command -v git >/dev/null 2>&1 || cannot "git is not on PATH. The check did not run."
command -v node >/dev/null 2>&1 || cannot "node is not on PATH. The check did not run."
[ -f "$lock" ] || cannot "skills.lock.json not found at $lock. The check did not run."

tmp="$(mktemp -d 2>/dev/null)" || cannot "cannot make a temporary folder."
trap 'rm -rf "$tmp"' EXIT

node "$helper" list "$lock" >"$tmp/rows" 2>"$tmp/err" || cannot "cannot read the lock: $(cat "$tmp/err")"
grep '^source|' "$tmp/rows" >"$tmp/sources"
if [ -n "$only" ]; then
  grep "^source|$only|" "$tmp/sources" >"$tmp/sources.one" || { echo "error: no source named $only in the lock" >&2; exit 2; }
  mv "$tmp/sources.one" "$tmp/sources"
fi

# vercmp A B: prints -1, 0 or 1 for dotted numeric versions.
vercmp() {
  node -e 'var a=process.argv[1].split("."),b=process.argv[2].split(".");for(var i=0;i<Math.max(a.length,b.length);i++){var x=parseInt(a[i]||"0",10),y=parseInt(b[i]||"0",10);if(x!==y){console.log(x<y?-1:1);process.exit(0)}}console.log(0)' "$1" "$2"
}

moved_any=0
cant=0
gone_list=""      # lines: source|name|detail
changed_list=""   # lines: source|name|oldshort|newshort|path
plugin_up=""      # lines: source|oldversion|newversion
plugin_odd=""     # lines: source|detail (plugin folder changed, version not newer or not readable)
plugin_low=""     # lines: source|newversion|minimum (new version below the minimum)
moved_only=""     # sources that moved with nothing locked changed
licence_list=""   # lines: source|detail

# licence_files BARE COMMIT: one line "name blob" for each top-level licence file, sorted.
licence_files() {
  git -C "$1" ls-tree "$2" 2>/dev/null \
    | awk -F'\t' '{ split($1, m, " "); n = $2; u = toupper(n);
        if (m[2] == "blob" && (u ~ /^LICEN[CS]E/ || u ~ /^COPYING/)) print n " " m[3] }' \
    | sort
}

# licence_diff OLD NEW: a short text naming each licence file added, removed or changed.
licence_diff() {
  printf '%s\n' "$1" | awk 'NF { print $1 }' | sort >"$tmp/lic.old"
  printf '%s\n' "$2" | awk 'NF { print $1 }' | sort >"$tmp/lic.new"
  out=""
  for f in $(comm -13 "$tmp/lic.old" "$tmp/lic.new"); do out="$out added $f;"; done
  for f in $(comm -23 "$tmp/lic.old" "$tmp/lic.new"); do out="$out removed $f;"; done
  for f in $(comm -12 "$tmp/lic.old" "$tmp/lic.new"); do
    a="$(printf '%s\n' "$1" | awk -v f="$f" '$1 == f { print $2 }')"
    b="$(printf '%s\n' "$2" | awk -v f="$f" '$1 == f { print $2 }')"
    [ "$a" != "$b" ] && out="$out changed $f;"
  done
  printf '%s' "${out# }"
}

while IFS='|' read -r _k name url commit minv link cdate; do
  echo "source $name  $link"
  short="${commit:0:7}"
  lsout="$(git ls-remote "$url" HEAD 2>"$tmp/err")"
  head="${lsout%%[[:space:]]*}"
  if [ -z "$head" ]; then
    echo "  could not reach upstream: $(head -n 1 "$tmp/err")"
    cant=1
    echo
    continue
  fi
  if [ "$head" = "$commit" ]; then
    echo "  locked $short ($cdate); upstream head is the same. Nothing moved."
    echo
    continue
  fi
  moved_any=1
  bare="$tmp/$name.git"
  if ! git clone --quiet --bare --no-tags --filter=blob:none "$url" "$bare" 2>"$tmp/err"; then
    rm -rf "$bare"
    if ! git clone --quiet --bare --no-tags "$url" "$bare" 2>"$tmp/err"; then
      echo "  could not clone upstream: $(head -n 1 "$tmp/err")"
      cant=1
      echo
      continue
    fi
  fi
  newhead="$(git -C "$bare" rev-parse HEAD)"
  nshort="${newhead:0:7}"
  if git -C "$bare" cat-file -e "$commit^{commit}" 2>/dev/null; then
    n="$(git -C "$bare" rev-list --count "$commit..$newhead")"
    if git -C "$bare" merge-base --is-ancestor "$commit" "$newhead" 2>/dev/null; then
      echo "  locked $short ($cdate); upstream head $nshort is $n commit(s) ahead."
    else
      echo "  locked $short ($cdate); upstream head $nshort. The history changed: the locked commit is not an ancestor."
    fi
    have_old=1
  else
    echo "  locked $short ($cdate); upstream head $nshort. The locked commit is no longer in the upstream history."
    have_old=0
  fi

  locked_changed=0
  while IFS='|' read -r _s _src sname spath stree; do
    [ -n "$sname" ] || continue
    cur="$(git -C "$bare" rev-parse -q --verify "$newhead:$spath" 2>/dev/null)"
    if [ -z "$cur" ]; then
      alt="$(git -C "$bare" ls-tree -r --name-only "$newhead" | grep "/$sname/SKILL.md\$" | head -n 1)"
      if [ -n "$alt" ]; then
        echo "  moved      $sname: $spath -> ${alt%/SKILL.md}"
        gone_list="$gone_list$name|$sname|moved to ${alt%/SKILL.md}
"
      else
        echo "  gone       $sname: $spath is not at the new head (removed or renamed)"
        gone_list="$gone_list$name|$sname|removed or renamed
"
      fi
      locked_changed=1
    elif [ "$cur" != "$stree" ]; then
      echo "  changed    $sname: $spath (tree ${stree:0:7} -> ${cur:0:7})"
      changed_list="$changed_list$name|$sname|$short|$nshort|$spath
"
      locked_changed=1
    fi
  done <<EOF
$(grep "^skill|$name|" "$tmp/rows")
EOF
  [ "$locked_changed" -eq 0 ] && echo "  every locked skill is unchanged"

  if [ "$have_old" -eq 1 ]; then
    git -C "$bare" ls-tree -r --name-only "$commit" | grep '/SKILL.md$' | sed 's#/SKILL.md$##' | sort >"$tmp/old.list"
    git -C "$bare" ls-tree -r --name-only "$newhead" | grep '/SKILL.md$' | sed 's#/SKILL.md$##' | sort >"$tmp/new.list"
    added="$(comm -13 "$tmp/old.list" "$tmp/new.list" | sed 's#.*/##' | tr '\n' ' ')"
    [ -n "$added" ] && echo "  added upstream since the lock (information only): $added"
  fi

  while IFS='|' read -r _p _psrc ppath ptree pver; do
    [ -n "$ppath" ] || continue
    pcur="$(git -C "$bare" rev-parse -q --verify "$newhead:$ppath" 2>/dev/null)"
    if [ -z "$pcur" ]; then
      echo "  plugin     $ppath is not at the new head"
      gone_list="$gone_list$name|$ppath|plugin folder removed or renamed
"
      continue
    fi
    git -C "$bare" show "$newhead:$ppath/.claude-plugin/plugin.json" >"$tmp/plugin.json" 2>/dev/null
    nver="$(node "$helper" field "$tmp/plugin.json" version 2>/dev/null)"
    if [ "$pcur" = "$ptree" ]; then
      echo "  plugin     $ppath unchanged"
    elif [ -z "$nver" ]; then
      echo "  plugin     $ppath changed; the new version could not be read"
      plugin_odd="$plugin_odd$name|$ppath changed and its version could not be read
"
      locked_changed=1
    else
      cmp="$(vercmp "$nver" "$pver")"
      cmpmin=""
      [ -n "$minv" ] && cmpmin="$(vercmp "$nver" "$minv")"
      if [ "$cmp" = "1" ]; then
        echo "  plugin     $ppath changed: version $pver -> $nver (minimum $minv)"
        plugin_up="$plugin_up$name|$pver|$nver
"
        locked_changed=1
      else
        echo "  plugin     $ppath changed: version $pver -> $nver, which is not newer than the lock"
        plugin_odd="$plugin_odd$name|$ppath changed, version $pver -> $nver is not newer than the lock
"
        locked_changed=1
      fi
      if [ "$cmpmin" = "-1" ]; then
        echo "  warn       new version $nver is below the minimum $minv"
        plugin_low="$plugin_low$name|$nver|$minv
"
        locked_changed=1
      fi
    fi
  done <<EOF
$(grep "^plugin|$name|" "$tmp/rows")
EOF
  # licence: the top-level LICENSE, LICENCE and COPYING files at the locked commit and the new head.
  # No tree hash of a locked skill covers them, so a licence change is checked here.
  if [ "$have_old" -eq 1 ]; then
    lic_old="$(licence_files "$bare" "$commit")"
    lic_new="$(licence_files "$bare" "$newhead")"
    if [ "$lic_old" != "$lic_new" ]; then
      lic_detail="$(licence_diff "$lic_old" "$lic_new")"
      echo "  licence    changed: $lic_detail"
      licence_list="$licence_list$name|$lic_detail
"
      locked_changed=1
    else
      echo "  licence    unchanged"
    fi
  else
    echo "  licence    not checked: the locked commit is not in the upstream history"
    licence_list="$licence_list$name|not checked, the locked commit is gone
"
    locked_changed=1
  fi

  [ "$locked_changed" -eq 0 ] && moved_only="$moved_only$name "
  echo
done <"$tmp/sources"

# Recommended next step: one step, chosen by rule, most urgent first.
echo "Recommended next step"
if [ -n "$licence_list" ]; then
  echo "  A licence file changed upstream, or could not be compared. Do not update. The owner decides"
  echo "  (tier 3 in docs/skills-sources.md section 7):"
  printf '%s' "$licence_list" | while IFS='|' read -r s d; do
    [ -n "$s" ] && echo "    $s: $d"
  done
  echo "  Read the new licence, then record the decision in docs/skills-sources.md section 9."
elif [ -n "$plugin_low" ]; then
  echo "  The plugin version at the new head is below the minimum. Do not update (tier 3 in"
  echo "  docs/skills-sources.md section 7). The owner decides:"
  printf '%s' "$plugin_low" | while IFS='|' read -r s nw m; do
    [ -n "$s" ] && echo "    $s: new version $nw, minimum $m"
  done
elif [ -n "$gone_list" ]; then
  echo "  A locked skill moved, was removed or was renamed. Update the playbooks that name it first:"
  printf '%s' "$gone_list" | while IFS='|' read -r s n d; do
    [ -n "$n" ] || continue
    pb="$(grep -lw -- "$n" "$repo"/playbooks/*.md 2>/dev/null | sed "s#^$repo/##" | tr '\n' ' ')"
    echo "    $n ($d); playbooks that name it: ${pb:-none}"
  done
  echo "  Then edit the lock entry by hand and run: bash scripts/fetch-skills.sh --update"
  echo "  (--update refuses to run while a locked skill is missing upstream.)"
elif [ -n "$changed_list" ]; then
  echo "  A locked skill changed. Read the change for new commands, network calls and publishing steps"
  echo "  before you update:"
  printf '%s' "$changed_list" | while IFS='|' read -r s n o nw p; do
    [ -n "$n" ] || continue
    echo "    git -C .cache/$s fetch --quiet origin && git -C .cache/$s diff $o..$nw -- $p"
  done
  echo "  (Run bash scripts/fetch-skills.sh first if .cache/ is missing.) Then run:"
  echo "    bash scripts/fetch-skills.sh --update"
elif [ -n "$plugin_odd" ]; then
  echo "  The plugin folder changed, but its version did not go up or could not be read. Read the"
  echo "  change before you update (tier 2 in docs/skills-sources.md section 7):"
  printf '%s' "$plugin_odd" | while IFS='|' read -r s d; do
    [ -n "$s" ] && echo "    $s: $d"
  done
elif [ -n "$plugin_up" ]; then
  echo "  The plugin version is above the lock. Run its playbook check against the new version in a"
  echo "  temporary copy of the project, then update the lock:"
  printf '%s' "$plugin_up" | while IFS='|' read -r s o nw; do
    [ -n "$s" ] && echo "    $s: $o -> $nw"
  done
  echo "    bash scripts/fetch-skills.sh --update"
elif [ "$moved_any" -eq 1 ]; then
  echo "  Upstream moved, but no locked skill or plugin folder changed. No action is needed."
  echo "  Optional: bash scripts/fetch-skills.sh --update (to record the new commit)."
elif [ "$cant" -eq 1 ]; then
  echo "  None can be decided. The check could not reach every source, so it does not know whether"
  echo "  anything moved. Fix the connection and run it again."
else
  echo "  None. Nothing moved."
fi

if [ "$cant" -eq 1 ]; then
  echo
  echo "The check could not run for every source (see above). Exit 3." >&2
  exit 3
fi
[ "$moved_any" -eq 1 ] && exit 1
exit 0

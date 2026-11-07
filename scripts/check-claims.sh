#!/usr/bin/env bash
# Check the claims in README.md against the scripts they describe, and the source names in the
# scripts against skills.lock.json. Read only: it writes no file and needs no network.
# Usage: scripts/check-claims.sh      (-h, --help shows this text)
#
# For each script in the table at the top of the code, it compares the README section for that
# script with the script:
#   options  each option in the script's usage text (its "Usage:" line and its "#   --x" lines) is
#            named in the README section. One direction only: an option that the README names and
#            the script does not have is not reported. --help is not checked.
#   exits    the codes on the script's "Exit status:" line are the codes that the README section
#            names after "exits" ("It exits 0 ..."). A script without that line is noted, not checked.
# For each script whose usage says "Only this source (a or b)", the names must equal the source keys
# in skills.lock.json. The README table of the lock (### `skills.lock.json`) must list the same keys.
# The "## License" section of the README must agree with the root LICENSE file: with the file, the
# section names MIT and does not say "no root LICENSE"; without the file, the section says so.
#
# Output: one line per stale claim, "FAIL <file>:<line>: <what differs>", then a count. Lines that
# start with NOTE are not failures.
# Exit status: 0 no stale claim, 1 at least one stale claim, 2 usage error or the check cannot run
# (the README or the lock is missing, or node is not installed).
# Plain bash 3.2. Needs grep, sed, awk, sort, tr, cut and node. No jq, no python.
#
# Checked in the README: sections of README.md named in the SECTIONS list below. A section that is
# renamed or removed is a stale claim.

set -u

show_help() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

if [ $# -gt 0 ]; then
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) echo "check-claims.sh: unknown option: $1" >&2
       echo "Usage: scripts/check-claims.sh   (see --help)" >&2
       exit 2 ;;
  esac
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
README="$REPO/README.md"
LOCK="$REPO/skills.lock.json"

if [ ! -f "$README" ] || [ ! -f "$LOCK" ]; then
  echo "check-claims.sh: README.md and skills.lock.json are needed in $REPO. Check not run." >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  echo "check-claims.sh: node is needed to read skills.lock.json. Check not run." >&2
  exit 2
fi

# script|README heading|level. Level 3 ends a section at the next "##" or "###" heading; level 2 at
# the next "##" heading, so the "###" subsections of a "##" section stay in it.
SECTIONS='scripts/doctor.sh|### `scripts/doctor.sh`|3
scripts/bootstrap-project.sh|### `scripts/bootstrap-project.sh`|3
scripts/fetch-skills.sh|### `scripts/fetch-skills.sh`|3
scripts/check-upstream.sh|### `scripts/check-upstream.sh`|3
scripts/install-skills.sh|## Install skills|2
scripts/install-agents.sh|## Install agents|2
claude/scripts/install-mods.sh|## Install mods|2'

FAILS=0
CHECKS=0

fail() {
  FAILS=$((FAILS + 1))
  echo "FAIL $1"
}

# text FILE: the file with CRLF line ends removed (a Windows checkout can add them).
text() {
  tr -d '\r' < "$1"
}

# section FILE HEADING LEVEL: the lines under HEADING as "line:text".
section() {
  text "$1" | awk -v h="$2" -v lvl="$3" '
    !on && $0 == h { on = 1; next }
    on && lvl == 3 && /^##+ / { exit }
    on && lvl == 2 && /^## / { exit }
    on { print NR ":" $0 }
  '
}

# usage_options FILE: the option names in the usage text of a script, one per line, without --help.
usage_options() {
  text "$1" | awk 'NR == 1 && /^#!/ { next } !/^#/ { exit } /^# +--|^# *Usage:/ { print }' \
    | grep -o -e '--[a-z][a-z-]*' | grep -v -x -e '--help' | sort -u
}

# script_exit_codes FILE: the codes named on the "Exit status:" line(s), in one line.
script_exit_codes() {
  text "$1" | grep 'Exit status:' | sed 's/.*Exit status://' | grep -o -E '[0-9]+' \
    | sort -u | tr '\n' ' '
}

# readme_exit_codes: reads section lines on stdin; the codes after "exits", in one line.
readme_exit_codes() {
  grep -o -E 'exits? [0-9]+' | grep -o -E '[0-9]+' | sort -u | tr '\n' ' '
}

LOCK_KEYS=$(node "$REPO/scripts/skills-lock.cjs" list "$LOCK" | awk -F'|' '$1 == "source" { print $2 }' | sort -u)
if [ -z "$LOCK_KEYS" ]; then
  echo "check-claims.sh: no sources could be read from skills.lock.json. Check not run." >&2
  exit 2
fi

while IFS='|' read -r script heading level; do
  path="$REPO/$script"
  if [ ! -f "$path" ]; then
    fail "$script: the script named in check-claims.sh is not there"
    continue
  fi
  sec=$(section "$README" "$heading" "$level")
  if [ -z "$sec" ]; then
    fail "README.md: no section \"$heading\" for $script"
    continue
  fi

  # options: each option of the usage text is named in the section.
  for opt in $(usage_options "$path"); do
    CHECKS=$((CHECKS + 1))
    if ! printf '%s\n' "$sec" | grep -q -F -e "$opt"; then
      ln=$(text "$path" | grep -n -F -e "$opt" | head -1 | cut -d: -f1)
      fail "$script:${ln:-1}: option $opt is in the usage text, but \"$heading\" in README.md does not name it"
    fi
  done

  # exits: the codes match the codes the section names.
  h=$(script_exit_codes "$path")
  if [ -n "$h" ]; then
    CHECKS=$((CHECKS + 1))
    r=$(printf '%s\n' "$sec" | readme_exit_codes)
    if [ "$h" != "$r" ]; then
      rl=$(printf '%s\n' "$sec" | grep -m1 -E 'exits? [0-9]' | cut -d: -f1)
      fail "README.md:${rl:-?}: \"$heading\" names exit codes [$r], $script says [$h]"
    fi
  else
    echo "NOTE $script: no \"Exit status:\" line, exit codes not checked"
  fi
done <<EOF
$SECTIONS
EOF

# sources: every "Only this source (a or b)" names exactly the keys of the lock.
for f in $(grep -l -F 'Only this source (' "$REPO"/scripts/*.sh "$REPO"/claude/scripts/*.sh 2>/dev/null); do
  rel=${f#"$REPO"/}
  [ "$rel" = "scripts/check-claims.sh" ] && continue
  hits=$(text "$f" | awk '/Only this source \(/ {
    s = $0; sub(/.*Only this source \(/, "", s); sub(/\).*/, "", s);
    gsub(/,/, " ", s); gsub(/ or /, " ", s); print NR ":" s }')
  while IFS=: read -r ln names; do
    [ -n "$ln" ] || continue
    CHECKS=$((CHECKS + 1))
    want=$(printf '%s\n' $names | sort -u)
    if [ "$want" != "$LOCK_KEYS" ]; then
      fail "$rel:$ln: source names [$(echo $want)], skills.lock.json has [$(echo $LOCK_KEYS)]"
    fi
  done <<EOF
$hits
EOF
done

# lock table: the README table of skills.lock.json lists the lock's sources.
CHECKS=$((CHECKS + 1))
hl=$(grep -n -F -e '### `skills.lock.json`' "$README" | head -1 | cut -d: -f1)
rows=$(section "$README" '### `skills.lock.json`' 3 | cut -d: -f2- \
  | awk -F'|' '/^\| `/ { n = $2; gsub(/[ `]/, "", n); print n }' | sort -u)
if [ "$rows" != "$LOCK_KEYS" ]; then
  fail "README.md:${hl:-?}: the skills.lock.json table lists [$(echo $rows)], the lock has [$(echo $LOCK_KEYS)]"
fi

# skill counts: the numbers that the README and docs/skills-sources.md give for the skills.
SKILL_ROWS=$(node "$REPO/scripts/skills-lock.cjs" list "$LOCK" | awk -F'|' '$1 == "skill" { print $2 }')
OWN=0
for d in "$REPO"/skills/*/; do
  [ -f "${d}SKILL.md" ] && OWN=$((OWN + 1))
done
LOCKED=$(printf '%s\n' "$SKILL_ROWS" | grep -c .)
TOTAL=$((OWN + LOCKED))

# count_claim FILE PATTERN WANT LABEL: each match of PATTERN (an extended regex whose first number
# is the claim) in FILE must give WANT.
count_claim() {
  _f=$1; _p=$2; _want=$3; _label=$4
  text "$_f" | grep -n -o -E -e "$_p" | while IFS=: read -r _ln _hit; do
    _got=$(printf '%s\n' "$_hit" | grep -o -E '[0-9]+' | head -1)
    echo "$_ln:$_got"
  done > "$TMPCOUNT"
  if [ ! -s "$TMPCOUNT" ]; then
    CHECKS=$((CHECKS + 1))
    fail "${_f#"$REPO"/}: no claim \"$_label\" found; the sentence changed or moved"
    return
  fi
  while IFS=: read -r _ln _got; do
    CHECKS=$((CHECKS + 1))
    if [ "$_got" != "$_want" ]; then
      fail "${_f#"$REPO"/}:$_ln: \"$_label\" says $_got, the files give $_want"
    fi
  done < "$TMPCOUNT"
}

TMPCOUNT=$(mktemp "${TMPDIR:-/tmp}/check-claims.XXXXXX")
trap 'rm -f "$TMPCOUNT"' EXIT

count_claim "$README" 'prints `installed` for [0-9]+ skills' "$TOTAL" "installed for N skills"
count_claim "$README" 'links all [0-9]+ skills' "$TOTAL" "links all N skills"
count_claim "$README" 'links only the [0-9]+ own skills' "$OWN" "links only the N own skills"
count_claim "$README" 'the lock names [0-9]+ skills' "$LOCKED" "the lock names N skills"
for src in $LOCK_KEYS; do
  n=$(printf '%s\n' "$SKILL_ROWS" | grep -c -x -F "$src")
  [ "$n" -gt 0 ] || continue
  case "$src" in
    mattpocock-skills)
      count_claim "$README" '[0-9]+ from mattpocock/skills' "$n" "N from mattpocock/skills"
      count_claim "$README" '`mattpocock-skills` \| [^|]*\| [0-9]+ skills' "$n" "table row mattpocock-skills"
      count_claim "$REPO/docs/skills-sources.md" '[0-9]+ skills, fetched into' "$n" "sources row mattpocock-skills"
      ;;
    ambition)
      count_claim "$README" '[0-9]+ from ambition' "$n" "N from ambition"
      ;;
    good-readme)
      count_claim "$README" '[0-9]+ from good-readme' "$n" "N from good-readme"
      ;;
  esac
done

# licence: the "## License" section of the README agrees with the root LICENSE file on disk.
lic=$(section "$README" '## License' 2)
if [ -z "$lic" ]; then
  CHECKS=$((CHECKS + 1))
  fail "README.md: no section \"## License\""
else
  lic_ln=$(printf '%s\n' "$lic" | grep -m1 -E '^[0-9]+:.' | cut -d: -f1)
  none_ln=$(printf '%s\n' "$lic" | grep -m1 -i -E 'no root `?LICENSE' | cut -d: -f1)
  CHECKS=$((CHECKS + 1))
  if [ -f "$REPO/LICENSE" ]; then
    if [ -n "$none_ln" ]; then
      fail "README.md:$none_ln: the License section says there is no root LICENSE, but $REPO/LICENSE exists"
    fi
    CHECKS=$((CHECKS + 1))
    if ! printf '%s\n' "$lic" | grep -q -w -e 'MIT'; then
      fail "README.md:${lic_ln:-?}: the root LICENSE exists, but the License section does not name MIT"
    fi
  elif [ -z "$none_ln" ]; then
    fail "README.md:${lic_ln:-?}: there is no root LICENSE file, but the License section does not say so"
  fi
fi

echo "$CHECKS claims checked, $FAILS stale."
if [ "$FAILS" -gt 0 ]; then
  exit 1
fi
exit 0

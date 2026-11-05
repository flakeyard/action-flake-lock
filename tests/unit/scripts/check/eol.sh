# shellcheck shell=bash
# Tests of scripts/check/eol.sh.

: "${root:?}"
eol_script=$root/scripts/check/eol.sh
eol_work=$(mktemp -d)
eol_file=$eol_work/eol

# eol_run NAME EXPECTED CONTENT MESSAGE [ARG...]: run the script on an EOL
# file with CONTENT, given to printf %b, and the arguments ARG; EXPECTED is ok
# or fail, and its output has MESSAGE.
eol_run() {
  local name=$1 expected=$2 content=$3 message=$4 output status=0
  shift 4
  printf '%b' "$content" >"$eol_file"
  start "eol: $name"
  output=$("$eol_script" "$@" 2>&1) || status=$?
  if [[ $expected == ok && $status -ne 0 ]] || [[ $expected == fail && $status -eq 0 ]]; then
    report "expected $expected, exit status $status: $output"
  elif [[ $output != *"$message"* ]]; then
    report "no message '$message' in: $output"
  fi
  finish
}

for case in "2026-10-29 ok supported" "2026-12-10 ok in 21 days" "2027-01-02 fail reached its end of life"; do
  read -r today expected message <<<"$case"
  eol_run "$today" "$expected" '# comment\nnixos-26.05 2026-12-31\n' "$message" "$eol_file" "$today"
done

# A malformed EOL file fails with a message instead of counting from today.
while IFS='|' read -r name content message; do
  eol_run "$name" fail "$content" "$message" "$eol_file" 2026-10-29
done <<'CASES'
no date|# comment\nnixos-26.05\n|'' is not a date
an invalid date|nixos-26.05 2026-02-30\n|'2026-02-30' is not a date
another date format|nixos-26.05 31.12.2026\n|'31.12.2026' is not a date
no data line|# comment\n\n|no data line
an empty file||no data line
two data lines|nixos-26.05 2026-12-31\nnixos-26.11 2027-06-30\n|more than one data line
not a branch|2026-12-31\n|'2026-12-31' is not a branch
an extra field|nixos-26.05 2026-12-31 x\n|unexpected 'x'
CASES

eol_run "a last line without a newline" ok 'nixos-26.05 2026-12-31' \
  "supported until 2026-12-31" "$eol_file" 2026-10-29
eol_run "an invalid today" fail 'nixos-26.05 2026-12-31\n' "'' is not a date" "$eol_file" ""
eol_run "a missing file" fail '' "" "$eol_work/none"

# eol_branch: the branch that nixpkgs-eol of this repository names.
eol_branch() {
  local line
  while IFS= read -r line; do
    [[ $line == '#'* || -z $line ]] || {
      printf '%s\n' "${line%% *}"
      return 0
    }
  done <"$root/nixpkgs-eol"
}

for lock in flake.lock dev/flake.lock; do
  start "eol: nixpkgs-eol names the branch of $lock"
  jq -e --arg branch "$(eol_branch)" '.nodes.nixpkgs.original.ref == $branch' "$root/$lock" >/dev/null \
    || report "nixpkgs-eol names $(eol_branch), $lock follows another branch"
  finish
done

rm -rf -- "$eol_work"

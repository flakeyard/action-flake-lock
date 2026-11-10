# shellcheck shell=bash
# The tools of the action, jq and gh, built from its own flake with the nix of
# the job (ADR-0001). Sourced after env.sh and report.sh, not run.

# The store path of each tool, in a file named after it.
TOOLS_DIR=$STATE_DIR/tools

# job_nix: prints the absolute path of nix on the PATH of the job.
job_nix() {
  local nix
  nix=$(PATH=$JOB_PATH type -P nix) && [[ $nix == /* ]] && printf '%s\n' "$nix"
}

# is_one_path TEXT: TEXT is one absolute path on one line.
is_one_path() {
  local text=$1
  [[ $text == /* && $text != *$'\n'* ]]
}

# record_tool NAME PATH: records PATH as the store path of the tool NAME.
record_tool() {
  local name=$1 path=$2
  mkdir -p -- "$TOOLS_DIR"
  printf '%s\n' "$path" >"$TOOLS_DIR/$name"
}

# build_tool NIX NAME: builds the package NAME of the action's flake with NIX,
# as locked, and records its store path; fails unless the build prints
# exactly one path, since a package with several outputs prints one each.
build_tool() {
  local nix=$1 name=$2 paths
  paths=$("$nix" build --no-link --print-out-paths --no-update-lock-file "path:$ACTION_DIR#$name") || {
    error "Cannot build $name from the flake of the action."
    return 1
  }
  if ! is_one_path "$paths"; then
    error "nix build of $name printed '${paths//$'\n'/ }', expected one store path."
    return 1
  fi
  record_tool "$name" "$paths"
}

# tool NAME: prints the executable of the tool NAME that the step tools built;
# fails when there is none.
tool() {
  local name=$1 path
  [[ -r $TOOLS_DIR/$name ]] || return 1
  path=$(<"$TOOLS_DIR/$name")/bin/$name
  [[ -x $path ]] && printf '%s\n' "$path"
}

# parsed_jq PROGRAM [ARG...]: runs PROGRAM with the jq of the action, which
# the step sets in jq, and the modules of scripts/lock, on the parsed lock as
# $parsed; strings are printed as text.
parsed_jq() {
  local program=$1
  shift
  # shellcheck disable=SC2154 # jq is set by the step
  "$jq" -rn -L "$LOCK_MODULES" --slurpfile parsed "$PARSED_LOCK" "$@" "$program"
}

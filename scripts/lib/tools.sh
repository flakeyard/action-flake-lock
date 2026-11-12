# shellcheck shell=bash
# The tools of the action, jq and gh, substituted with the nix of the job from
# the store paths that tools.nix records for the packages of its own flake
# (ADR-0001, ADR-0003). Sourced after env.sh and the report.sh of the shell
# library, not run.

# The store path of each tool, in a file named after it.
TOOLS_DIR=$STATE_DIR/tools
# The store path of each package of the root flake, by system; generated with
# `nix run ./dev#update-tools` and checked by dev/flake.nix.
TOOLS_FILE=$ACTION_DIR/tools.nix

# job_nix: prints the absolute path of nix on the PATH of the job.
job_nix() {
  local nix
  # shellcheck disable=SC2154 # JOB_PATH is set by step_environment
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

# job_system NIX: prints the system of NIX, such as x86_64-linux.
job_system() {
  local nix=$1
  "$nix" config show system
}

# substitute NIX NAME PATH: substitutes PATH, the store path of the tool NAME,
# with NIX; fails unless nix prints exactly PATH.
substitute() {
  local nix=$1 name=$2 path=$3 printed
  printed=$("$nix" build --no-link --print-out-paths "$path") || {
    error "Cannot substitute $name from $path: the binary cache of nixpkgs, such as cache.nixos.org, must be a trusted substituter."
    return 1
  }
  if [[ $printed != "$path" ]]; then
    error "nix build of $name printed '${printed//$'\n'/ }', expected $path."
    return 1
  fi
}

# realise_tool NIX SYSTEM NAME: substitutes the store path that tools.nix
# records for the tool NAME on SYSTEM, without evaluating nixpkgs, and records
# it; fails unless tools.nix records exactly one path.
realise_tool() {
  local nix=$1 system=$2 name=$3 path
  if ! path=$("$nix" eval --raw --file "$TOOLS_FILE" "$system.$name") || ! is_one_path "$path"; then
    error "tools.nix records no store path of $name for $system."
    return 1
  fi
  substitute "$nix" "$name" "$path" || return 1
  record_tool "$name" "$path"
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

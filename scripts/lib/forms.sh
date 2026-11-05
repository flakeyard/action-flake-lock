# shellcheck shell=bash
# The forms of the inputs, and the lock file that the input path names.
# Sourced after env.sh, not run.

# A source of allow-duplicates as the duplicates rule compares sources: a
# repository on github.com in lower case, and an optional dir.
# shellcheck disable=SC2034 # used by step/check.sh
readonly SOURCE_FORM='^github\.com/[a-z0-9-]+/[a-z0-9._-]+(\?dir=[A-Za-z0-9._/-]+)?$'
# shellcheck disable=SC2034 # used by step/check.sh
readonly BOOLEAN_FORM='^(true|false)$'

# items LIST: prints the lines of LIST without surrounding whitespace, and
# without blank lines.
items() {
  local list=$1 line
  while IFS=$' \t\r' read -r line; do
    [[ -z $line ]] || printf '%s\n' "$line"
  done <<<"$list"
}

# workspace: prints the real path of the workspace.
workspace() {
  realpath -e -- "${GITHUB_WORKSPACE:?}"
}

# lock_file PATH: prints the real path of PATH, relative to the workspace;
# fails when it does not exist.
lock_file() {
  local path=$1
  realpath -e -- "$(workspace)/$path" 2>/dev/null
}

# lock_problem PATH: prints why PATH, relative to the workspace, cannot be
# read as the lock file; prints nothing when it can.
lock_problem() {
  local path=$1 real
  if [[ -z $path || $path == /* ]]; then
    echo "path must be relative to the workspace, not '$path'."
  elif ! real=$(lock_file "$path"); then
    echo "No lock file at $path."
  elif [[ $real != "$(workspace)"/* ]]; then
    echo "The lock file $path is outside the workspace."
  elif [[ ! -f $real ]]; then
    echo "The lock file $path is not a regular file."
  fi
}

# A GitHub token as GitHub issues them; nothing else is printed or passed.
# shellcheck disable=SC2034 # used by step/releases.sh
readonly TOKEN_FORM='^[A-Za-z0-9_.-]+$'
# The name of a repository as GitHub allows it. It needs a character other
# than a dot: ".." or "." would change the path of an API call.
# shellcheck disable=SC2034 # used by step/releases.sh
readonly REPOSITORY_NAME_FORM='^[A-Za-z0-9._-]*[A-Za-z0-9_-][A-Za-z0-9._-]*$'

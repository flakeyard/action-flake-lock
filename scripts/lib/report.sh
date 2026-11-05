# shellcheck shell=bash
# Messages of a step: errors, warnings and notices in the log, and lines of
# the job summary. Messages often quote text that others choose, such as a pull
# request title or a file of the repository, so every message is escaped: it
# cannot end its workflow command and start another, and it cannot leave a code
# span of the summary.

# escape_command TEXT: print TEXT as the message of one workflow command.
escape_command() {
  local text=$1
  text=${text//%/%25}
  text=${text//$'\r'/%0D}
  text=${text//$'\n'/%0A}
  printf '%s\n' "$text"
}

# error MESSAGE: report an error and go on.
error() {
  printf '::error::%s\n' "$(escape_command "$*")"
}

# fail MESSAGE: report an error and exit.
fail() {
  error "$*"
  exit 1
}

# warning MESSAGE: report a warning.
warning() {
  printf '::warning::%s\n' "$(escape_command "$*")"
}

# notice MESSAGE: report a notice.
notice() {
  printf '::notice::%s\n' "$(escape_command "$*")"
}

# summary TEXT: append a line to the job summary.
summary() {
  printf '%s\n' "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# code_span TEXT: print TEXT as inline code of the job summary, also inside a
# table cell. It cannot leave the code span or the cell, so it renders as no
# link or markup.
code_span() {
  local text=$1 tick='`'
  text=${text//$'\n'/ }
  text=${text//$'\r'/ }
  text=${text//\`/\'}
  text=${text//|/\\|}
  printf '%s%s%s\n' "$tick" "$text" "$tick"
}

# shellcheck shell=bash
# Messages of a step: errors and notices in the log, and lines of the job
# summary. Messages often quote text that others choose, such as a pull
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

# GitHub keeps at most MAX_ERRORS error annotations of a step. The first
# MAX_ERRORS - 1 are written at once; the last one is held until
# flush_errors, which writes it when it is the last error, or else a line that
# says how many more errors there are.
readonly MAX_ERRORS=10
errors=0 held_error=""

# error_command PROPERTIES MESSAGE: an error annotation with the escaped
# PROPERTIES, such as " file=f,title=t", within MAX_ERRORS.
error_command() {
  local properties=$1 message=$2 line
  errors=$((errors + 1))
  line="::error$properties::$(escape_command "$message")"
  if ((errors < MAX_ERRORS)); then
    printf '%s\n' "$line"
  elif ((errors == MAX_ERRORS)); then
    held_error=$line
  fi
}

# flush_errors [WHERE]: the last error annotation of the step: the held error,
# or how many more errors there are and WHERE they are listed. Call it once,
# as the step ends.
flush_errors() {
  local where=${1-} more=$((errors - MAX_ERRORS + 1))
  if ((more == 1)); then
    printf '%s\n' "$held_error"
  elif ((more > 1)); then
    printf '::error::%s\n' "$(escape_command "$more more errors are not shown here${where:+; $where}.")"
  fi
}

# error MESSAGE: report an error and go on.
error() {
  error_command "" "$*"
}

# fail MESSAGE: report an error and exit.
fail() {
  error "$*"
  flush_errors
  exit 1
}

# notice MESSAGE: report a notice.
notice() {
  printf '::notice::%s\n' "$(escape_command "$*")"
}

# escape_property TEXT: print TEXT as a property of one workflow command, such
# as the title of an annotation: also "," and ":" end a property.
escape_property() {
  local text=$1
  text=$(escape_command "$text")
  text=${text//:/%3A}
  text=${text//,/%2C}
  printf '%s\n' "$text"
}

# annotate FILE TITLE MESSAGE: an error annotation of FILE, within the
# MAX_ERRORS of the step.
annotate() {
  local file=$1 title=$2 message=$3
  error_command " file=$(escape_property "$file"),title=$(escape_property "$title")" "$message"
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

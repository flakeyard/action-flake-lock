# shellcheck shell=bash
# Tests of scripts/lib/report.sh: untrusted text cannot start a workflow command or
# leave a code span.

lib=report.sh

setup
run_lib "report: an error ends at the end of its line" fail "$lib" \
  fail $'bad title\n::warning::forged\r'
expect stdout '::error::bad title%0A::warning::forged%0D'
finish

setup
run_lib "report: percent signs are escaped first" ok "$lib" notice '100%0A'
expect stdout '::notice::100%250A'
finish

setup
run_lib "report: errors do not exit" ok "$lib" error one
expect stdout '::error::one'
finish

setup
run_lib "report: a code span keeps one line and its cell" ok "$lib" \
  code_span $'a`b|c\nd'
expect stdout "\`a'b\\|c d\`"
finish

setup
run_lib "report: the summary gets one line" ok "$lib" summary '| a | b |'
expect summary '| a | b |'
finish

# errors_of COUNT: COUNT errors, then the last annotation.
errors_of() {
  local count=$1 i
  for ((i = 1; i <= count; i++)); do error "e$i"; done
  flush_errors "see the summary"
}

setup
run_lib "report: eleven errors are nine and how many more" ok "$lib" errors_of 11
expect errors 10
expect message "::error::e9"
expect no-message "::error::e10"
expect message "::error::2 more errors are not shown here; see the summary."
finish

# nine_then_fail: nine errors, then a failure.
nine_then_fail() {
  local i
  for i in {1..9}; do error "e$i"; done
  fail last
}

setup
run_lib "report: a failure after nine errors is the tenth" fail "$lib" nine_then_fail
expect errors 10
expect message "::error::last"
finish

setup
run_lib "report: a property ends at a comma or a colon" ok "$lib" \
  escape_property $'a,b:c%d\r\n::x'
expect stdout 'a%2Cb%3Ac%25d%0D%0A%3A%3Ax'
finish

setup
run_lib "report: an annotation escapes its file, title and message" ok "$lib" \
  annotate $'f,1:2' $'t,i:t\nle' $'m%e\r\n::warning::s'
expect stdout '::error file=f%2C1%3A2,title=t%2Ci%3At%0Ale::m%25e%0D%0A::warning::s'
finish

# eleven_annotations: annotate eleven times, then the last annotation.
eleven_annotations() {
  local i
  for i in {1..11}; do annotate f t "m$i"; done
  flush_errors "the job summary lists all of them"
}

setup
run_lib "report: annotations share the 10 errors of a step" ok "$lib" eleven_annotations
expect errors 10
expect message "title=t::m9"
expect no-message "::m10"
expect message "::error::2 more errors are not shown here; the job summary lists all of them."
finish

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

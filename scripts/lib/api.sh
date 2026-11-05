# shellcheck shell=bash
# Calls of the GitHub API through the gh of the action, retried while they
# fail in a way that may pass on its own, as lib/github/api.sh of
# workflow-check does. Sourced after env.sh, not run.

# Attempts of a request that fails with a server error, a rate limit or no
# response, and the seconds to wait before the second one (doubled after).
readonly API_ATTEMPTS=3
readonly API_RETRY_DELAY=${API_RETRY_DELAY:-5}
readonly TRANSIENT_ERROR='HTTP (5[0-9][0-9]|429)|timeout|connection reset|unexpected EOF'
# A GraphQL error that may pass on its own; gh prints the others with HTTP 200.
readonly TRANSIENT_GRAPHQL_ERROR='"type": *"RATE_LIMITED"'

# is_transient ERROR_FILE BODY_FILE: true when the error of gh in ERROR_FILE,
# with the response body in BODY_FILE, may pass on its own: a server error, a
# rate limit, or no HTTP status and no GraphQL error at all.
is_transient() {
  local error_file=$1 body_file=$2
  grep -Eq "$TRANSIENT_ERROR" "$error_file" && return 0
  grep -Eq "$TRANSIENT_GRAPHQL_ERROR" "$body_file" && return 0
  ! grep -q 'HTTP [0-9]' "$error_file" && ! grep -q '"errors"' "$body_file"
}

# should_retry STATUS ATTEMPT DIR: true when a failed attempt, with its error
# and body in DIR, may be repeated.
should_retry() {
  local status=$1 attempt=$2 dir=$3
  ((status != 0 && attempt < API_ATTEMPTS)) || return 1
  is_transient "$dir/error" "$dir/body"
}

# api_request ARG...: runs gh api ARG... and prints the response body; on an
# error, prints it on stderr and fails. Transient errors are retried up to
# API_ATTEMPTS times.
api_request() {
  local tmp status attempt=1 delay=$API_RETRY_DELAY result=0
  tmp=$(mktemp -d)
  while :; do
    status=0
    gh api "$@" >"$tmp/body" 2>"$tmp/error" || status=$?
    should_retry "$status" "$attempt" "$tmp" || break
    sleep "$delay"
    attempt=$((attempt + 1)) delay=$((delay * 2))
  done
  if ((status == 0)); then cat -- "$tmp/body"; else cat -- "$tmp/error" >&2 && result=1; fi
  rm -rf -- "$tmp"
  return "$result"
}

#!/usr/bin/env bash
# Looks up the releases of every flakeyard repository of the lock with the gh
# of the action, once per repository and for at most MAX_REPOSITORIES of them,
# and applies the release rule into FINDINGS_DIR. An input whose releases
# could not be looked up is a finding of its own, which fails the run as well.
# The only step that gets the token.
#
# Inputs (environment): TOKEN.
set -euo pipefail
# Builtins only until lib/env.sh replaces PATH, which is the job's.
lib=${BASH_SOURCE[0]%/*}/../lib
# shellcheck source-path=SCRIPTDIR source=../lib/env.sh
source "$lib/env.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/report.sh
source "$lib/report.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/forms.sh
source "$lib/forms.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/tools.sh
source "$lib/tools.sh"
# shellcheck source-path=SCRIPTDIR source=../lib/api.sh
source "$lib/api.sh"

readonly LOOKUPS=$STATE_DIR/releases.jsonl
readonly OWNER=flakeyard
# The upper bound of lookups in one run.
readonly MAX_REPOSITORIES=50
# Every release of a repository with the commit of its tag, 100 per page:
# GraphQL peels annotated tags in tagCommit.
# shellcheck disable=SC2016 # variables of GraphQL
readonly RELEASES_QUERY='query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    releases(first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { tagName isDraft immutable tagCommit { oid } }
    }
  }
}'
# The programs of jq, over the parsed lock as $parsed.
# shellcheck disable=SC2016 # variables of jq
readonly REPOSITORIES_PROGRAM='include "releases"; $parsed[0] | flakeyard_repositories[]'
# shellcheck disable=SC2016 # variables of jq
readonly FINDINGS_PROGRAM='include "releases"; $parsed[0] | [release_findings($lookups)]'
# The lookup of a repository, from its GraphQL pages or the reason it failed.
# shellcheck disable=SC2016 # variables of jq
readonly RELEASES_PROGRAM='include "releases"; {repo: $repo, releases: ([inputs] | releases)}'
# shellcheck disable=SC2016 # variables of jq
readonly ERROR_PROGRAM='{repo: $repo, error: $error}'

# use_token: validates and masks the token and sets up gh for github.com only.
use_token() {
  [[ ${TOKEN-} =~ $TOKEN_FORM ]] \
    || fail "Invalid github-token: expected only letters, digits, underscores, dots and hyphens."
  echo "::add-mask::$TOKEN"
  export GH_TOKEN=$TOKEN GH_HOST=github.com
  unset GH_ENTERPRISE_TOKEN GH_REPO GH_CONFIG_DIR
}

# record_releases REPO: records the releases of REPO from the GraphQL pages on
# standard input.
record_releases() {
  local repo=$1
  "$jq" -cn -L "$LOCK_MODULES" --arg repo "$repo" "$RELEASES_PROGRAM" >>"$LOOKUPS"
}

# record_error REPO REASON: records that the releases of REPO were not looked
# up, and why.
record_error() {
  local repo=$1 reason=$2
  "$jq" -cn --arg repo "$repo" --arg error "$reason" "$ERROR_PROGRAM" >>"$LOOKUPS"
}

# look_up REPO: records the releases of the flakeyard repository REPO. The
# name comes from the lock, so it is checked before it reaches the API.
look_up() {
  local repo=$1 pages
  if [[ ! $repo =~ $REPOSITORY_NAME_FORM ]]; then
    record_error "$repo" "it is not the name of a repository"
  elif pages=$(api_request graphql --paginate -f query="$RELEASES_QUERY" -f owner="$OWNER" -f name="$repo"); then
    record_releases "$repo" <<<"$pages"
  else
    record_error "$repo" "the GitHub API failed, see the log"
  fi
}

# look_up_all REPO...: records the releases of the first MAX_REPOSITORIES of
# REPO, and an error for the others.
look_up_all() {
  local repos=("$@") repo
  for repo in "${repos[@]:0:MAX_REPOSITORIES}"; do
    look_up "$repo"
  done
  for repo in "${repos[@]:MAX_REPOSITORIES}"; do
    record_error "$repo" "the lock has more than $MAX_REPOSITORIES flakeyard repositories"
  done
}

main() {
  local gh listed repos=()
  # The jq of the action, for parsed_jq and the records.
  jq=$(tool jq) || fail "The tools step did not build jq."
  gh=$(tool gh) || fail "The tools step did not build gh."
  use_token
  export PATH=${gh%/*}:$PATH
  listed=$(parsed_jq "$REPOSITORIES_PROGRAM")
  [[ -z $listed ]] || mapfile -t repos <<<"$listed"
  : >"$LOOKUPS"
  look_up_all "${repos[@]}"
  mkdir -p -- "$FINDINGS_DIR"
  parsed_jq "$FINDINGS_PROGRAM" --slurpfile lookups "$LOOKUPS" >"$FINDINGS_DIR/release.json"
}

main "$@"

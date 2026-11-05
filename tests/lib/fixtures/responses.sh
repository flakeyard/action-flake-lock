# shellcheck shell=bash
# Responses of the gh stub: pages of releases from the GraphQL API. Source
# this file after case.sh.
# shellcheck disable=SC2154 # work comes from setup.

# release_file REPO: the file that answers the releases of flakeyard/REPO.
release_file() {
  local repo=$1
  printf '%s\n' "$work/fixtures/graphql-flakeyard-$repo"
}

# release_node RELEASE: a release of the API from RELEASE, TAG=COMMIT with
# :mutable or :draft after it for such a release.
release_node() {
  local release=$1 tag commit kind immutable=true draft=false
  IFS='=:' read -r tag commit kind <<<"$release"
  [[ $kind != mutable ]] || immutable=false
  [[ $kind != draft ]] || draft=true
  printf '{"tagName":"%s","isDraft":%s,"immutable":%s,"tagCommit":{"oid":"%s"}}' \
    "$tag" "$draft" "$immutable" "$commit"
}

# release_page REPO PAGE RELEASE...: page PAGE of the releases of
# flakeyard/REPO, 1 for the first one; RELEASE as release_node takes it.
release_page() {
  local repo=$1 page=$2 file nodes=() release
  shift 2
  file=$(release_file "$repo")
  ((page == 1)) || file=$file.$page
  for release; do nodes+=("$(release_node "$release")"); done
  local IFS=,
  printf '{"data":{"repository":{"releases":{"pageInfo":{},"nodes":[%s]}}}}\n' "${nodes[*]}" >"$file"
}

# releases_of REPO RELEASE...: one page with every release of flakeyard/REPO.
releases_of() {
  release_page "$1" 1 "${@:2}"
}

# transient_failures REPO COUNT: fail the next COUNT lookups of flakeyard/REPO
# with HTTP 504.
transient_failures() {
  local repo=$1 count=$2
  printf '%s\n' "$count" >"$(release_file "$repo").transient"
}

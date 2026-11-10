# shellcheck shell=bash
# Responses of the gh stub of the library: pages of releases from the GraphQL
# API. Source this file after fixtures.sh of the library.

# releases_request REPO: the name of the request for the releases of
# flakeyard/REPO, as fixture of the library takes it.
releases_request() {
  local repo=$1
  printf '%s\n' "graphql?owner=flakeyard&name=$repo"
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
  local repo=$1 page=$2 request body nodes=() release
  shift 2
  request=$(releases_request "$repo")
  for release; do nodes+=("$(release_node "$release")"); done
  local IFS=,
  body=$(printf '{"data":{"repository":{"releases":{"pageInfo":{},"nodes":[%s]}}}}' "${nodes[*]}")
  if ((page == 1)); then fixture "$request" "$body"; else next_page "$request" "$page" "$body"; fi
}

# releases_of REPO RELEASE...: one page with every release of flakeyard/REPO.
releases_of() {
  release_page "$1" 1 "${@:2}"
}

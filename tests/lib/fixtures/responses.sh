# shellcheck shell=bash
# Responses of the gh stub of the library: pages of releases from the GraphQL
# API. Source this file after fixtures.sh of the library.

# releases_request REPO: the name of the request for the releases of
# flakeyard/REPO, as fixture of the library takes it.
releases_request() {
  local repo=$1
  printf '%s\n' "graphql?owner=flakeyard&name=$repo"
}

# The time at which a release was published unless RELEASE gives another.
readonly DEFAULT_PUBLISHED=2026-01-01T12:00:00Z

# release_node RELEASE: a release of the API from RELEASE, TAG=COMMIT with
# :mutable, :draft or :prerelease after it for such a release, and @TIME of
# publishedAt after that, DEFAULT_PUBLISHED by default.
release_node() {
  local release=${1%@*} published=$DEFAULT_PUBLISHED tag commit kind
  local immutable=true draft=false prerelease=false
  [[ $1 != *@* ]] || published=${1##*@}
  IFS='=:' read -r tag commit kind <<<"$release"
  [[ $kind != mutable ]] || immutable=false
  [[ $kind != draft ]] || draft=true
  [[ $kind != prerelease ]] || prerelease=true
  printf '{"tagName":"%s","isDraft":%s,"isPrerelease":%s,"immutable":%s,"publishedAt":"%s","tagCommit":{"oid":"%s"}}' \
    "$tag" "$draft" "$prerelease" "$immutable" "$published" "$commit"
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

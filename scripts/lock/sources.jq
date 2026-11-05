# The source of a node of a flake.lock, taken from its locked attributes and
# normalized so that every recognised form of one repository on github.com
# compares equal (ADR-0001): github:, git+https, git+ssh and ssh://git@, and
# archive tarballs. Host, owner and repository are in lower case, without .git
# and a trailing /, and dir is kept. Other sources are null: they are skipped.

def github_host: "github.com";
# The owner of flakeyard inputs; fixed until a second organization is decided
# (FY-0022).
def flakeyard_owner: "flakeyard";

# The URL of a git repository: its scheme, an optional user, its host and its
# path.
def git_url_form: "^(https|ssh)://(git@)?(?<host>[^/:@]+)(:[0-9]+)?(?<path>/.*)$";
# The owner and repository in the path of a URL.
def repository_path_form: "^/(?<owner>[A-Za-z0-9-]+)/(?<repo>[A-Za-z0-9._-]+?)(\\.git)?/*$";
# An archive tarball of GitHub: https://github.com/<owner>/<repo>/archive/...
def tarball_url_form: "^https://(?<host>[^/:@]+)(?<path>/[^/]+/[^/]+)/archive/[^/]+$";

# on_github: the host of the input, a URL host or a host attribute, is
# github.com.
def on_github: ascii_downcase == github_host;

# repository: {owner, repo} in lower case, of an object with owner and repo.
def repository:
  {owner: (.owner | ascii_downcase), repo: (.repo | ascii_downcase | sub("\\.git$"; ""))};

# url_repository($form): the repository of a URL of the form $form, on
# github.com.
def url_repository($form):
  .url | strings | capture($form) | select(.host | on_github)
  | .path | capture(repository_path_form) | repository;

# locked_repository: the repository of locked attributes; nothing when they are
# not in a recognised form.
def locked_repository:
  if .type == "github" then
    select(.host // github_host | on_github) | select(.owner and .repo) | repository
  elif .type == "git" then url_repository(git_url_form)
  elif .type == "tarball" then url_repository(tarball_url_form)
  else empty end;

# source_id: the normalized source of {owner, repo, dir} as text, such as
# github.com/nixos/nixpkgs or github.com/<owner>/<repo>?dir=<dir>.
def source_id:
  "\(github_host)/\(.owner)/\(.repo)" + (if .dir then "?dir=\(.dir)" else "" end);

# source: {owner, repo, dir, id, flakeyard} of a node, or null when its
# source is not recognised. The owner is compared in lower case.
def source:
  (.locked // {}) as $locked
  | first($locked | objects | locked_repository) // null
  | if . then
      . + {dir: ($locked.dir // null), flakeyard: (.owner == flakeyard_owner)} | . + {id: source_id}
    else null end;

# with_sources: the parsed lock with the source of each node.
def with_sources: .nodes |= map(. + {source: source});

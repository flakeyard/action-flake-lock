# The release rule (ADR-0001, FY-0016): the rev of every flakeyard input is
# the commit of the tag of an immutable GitHub release vX.Y.Z, and its ref,
# when set, is vX of that major version or exactly that vX.Y.Z. Reads the
# parsed lock of nodes.jq with the sources of sources.jq, the releases that
# step/releases.sh looked up, and rev_form of forms.jq.

def release_tag_form: "^v(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)$";
# A ref that names a major version: vX or vX.Y.Z.
def ref_form: "^v(?<major>[0-9]+)(\\.[0-9]+\\.[0-9]+)?$";

# finding($node; $message): a violation of this rule by $node.
def finding($node; $message): {rule: "release", input: $node.attribute, message: $message};

# unverified($node; $reason): an input of $node that could not be verified,
# which fails the run as well.
def unverified($node; $reason):
  {rule: "release", input: $node.attribute, unverified: true}
  + {message: "Could not verify \($node.attribute), flakeyard/\($node.source.repo): \($reason)."};

# flakeyard_nodes: the nodes of flakeyard inputs.
def flakeyard_nodes: .nodes[] | select(.source.flakeyard);

# flakeyard_repositories: the repositories of the flakeyard inputs, each once.
def flakeyard_repositories: [flakeyard_nodes | .source.repo] | unique;

# releases: the immutable published releases vX.Y.Z of the GraphQL pages of
# releases, each with its version, the commit of its tag, whether it is a
# pre-release and when it was published.
def releases:
  [.[] | .data.repository.releases.nodes[]?
    | select(.immutable == true and .isDraft == false and (.tagName | test(release_tag_form)))
    | select(.tagCommit.oid | type == "string")
    | {tag: .tagName, commit: .tagCommit.oid}
    + {version: (.tagName | capture(release_tag_form) | [.major, .minor, .patch] | map(tonumber))}
    + {prerelease: (.isPrerelease != false), published: .publishedAt}];

# major($ref): the major version that $ref names, or null.
def major($ref): first($ref | strings | capture(ref_form) | .major | tonumber) // null;

# of_major($major): the releases of $major, or all of them when it is null.
def of_major($major): map(select($major == null or .version[0] == $major));

# newest($releases; $major): which release of $major, or of any major version
# when it is null, is the newest, as text.
def newest($releases; $major):
  ($releases | of_major($major) | max_by(.version)) as $newest
  | if $newest == null then
      "There is no immutable release \(if $major then "v\($major)" else "vX" end).Y.Z."
    elif $major then "The newest release of v\($major) is \($newest.tag) at \($newest.commit)."
    else "The newest release is \($newest.tag) at \($newest.commit)." end;

# problem($node; $releases; rev_form): what of the rule $node breaks; nothing when it
# keeps it. Several releases may tag the commit of its rev: a ref vX.Y.Z may
# be any of them.
def problem($node; $releases; rev_form):
  $node.locked.rev as $rev | $node.original.ref as $ref | major($ref) as $major
  | [$releases | of_major($major)[] | select(.commit == $rev) | .tag] as $tags
  | if $ref != null and $major == null then "its ref \($ref) is neither vX nor vX.Y.Z"
    elif ($rev | type != "string" or (test(rev_form) | not)) then "its rev is not a commit of 40 hex digits"
    elif $tags == [] then "its rev \($rev) is not the commit of an immutable release\(if $major then " v\($major).Y.Z" else "" end)"
    elif $ref != null and $ref != "v\($major)" and (any($tags[]; . == $ref) | not) then
      "its ref \($ref) is not the tag of a release of its rev, \($tags | join(", "))"
    else empty end;

# verdict($node; $releases; rev_form): a finding when $node breaks the rule.
def verdict($node; $releases; rev_form):
  first(problem($node; $releases; rev_form)) as $problem
  | finding($node; "\($node.attribute) of flakeyard/\($node.source.repo): \($problem). \(newest($releases; major($node.original.ref)))");

# release_findings($lookups; rev_form): the findings of every flakeyard input,
# from $lookups of {repo, releases} or {repo, error}.
def release_findings($lookups; rev_form):
  (reduce $lookups[] as $lookup ({}; .[$lookup.repo] = $lookup)) as $by_repo
  | flakeyard_nodes as $node
  | $by_repo[$node.source.repo] as $lookup
  | if $lookup == null then unverified($node; "it was not looked up")
    elif $lookup.error then unverified($node; $lookup.error)
    else verdict($node; $lookup.releases; rev_form) end;

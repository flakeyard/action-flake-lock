# The newer major version rule (ADR-0004, FY-0024, FY-0038): a warning for
# every flakeyard input whose repository has released a major version above
# its own. Reads the releases that step/releases.sh looked up, as releases of
# releases.jq makes them; the program of the rule passes the flakeyard nodes
# and the major version that the ref of a node names, from releases.jq.

# A time of publishedAt, in UTC.
def published_form: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$";
# The months that the previous major version receives security fixes after
# the first release of the next one (FY-0024).
def support_months: 6;
def seconds_per_day: 86400;

# finding($node; $message): a warning of this rule, which does not fail the
# run.
def finding($node; $message):
  {rule: "newer-major", input: $node.attribute, message: $message, level: "warning"};

# counted: the releases that make a newer major version: not pre-releases,
# with the time they were published.
def counted: map(select(.prerelease == false and (.published | type == "string" and test(published_form))));

# of_major($major): the releases of the major version $major.
def of_major($major): map(select(.version[0] == $major));

# first_release($major): the release of $major with the lowest version, or
# null; of counted releases.
def first_release($major): of_major($major) | min_by(.version);

# date: the UTC date, YYYY-MM-DD, of a release.
def date: .published[0:10];

# support_end: the last day of support, YYYY-MM-DD, of the major version
# before the one whose first release is published on the date YYYY-MM-DD: 6
# calendar months after it, or the last day of that month when it has no such
# day.
def support_end:
  split("-") | map(tonumber) as [$year, $month, $day]
  | ($month - 1 + support_months) as $months
  | [$year + ($months / 12 | floor), $months % 12] as [$end_year, $end_month]
  # The last day of the end month: the day before the first of the next.
  | (([$end_year, $end_month + 1, 1, 0, 0, 0, 0, 0] | mktime) - seconds_per_day | gmtime[2]) as $last
  | [$end_year, $end_month, ([$day, $last] | min), 0, 0, 0, 0, 0] | mktime | strftime("%Y-%m-%d");

# release_url($repo): the page of a release, whose notes have the migration
# guide.
def release_url($repo): "https://github.com/flakeyard/\($repo)/releases/tag/\(.tag)";

# own_major($releases; $ref_major): the major version of a node: the one its
# ref names, or without a ref that of the newest release of its rev; null when
# there is none.
def own_major($releases; $ref_major):
  if .original.ref != null then $ref_major
  else .locked.rev as $rev | [$releases[] | select(.commit == $rev)] | max_by(.version) | .version[0]?
  end;

# support($major; $newest; $releases; $today): the support of $major under
# FY-0024, when the newest major version is $newest, on the day $today.
def support($major; $newest; $releases; $today):
  if $major == 0 then "0.y.z releases are previews without support"
  else
    ($releases | first_release($newest) | date | support_end) as $end
    | (if $today > $end then "received security fixes until \($end)" else "receives security fixes until \($end)" end) as $fixes
    | if $newest == $major + 1 then "v\($major) \($fixes)"
      else "v\($major) receives no fixes; only v\($newest - 1) \($fixes)" end
  end;

# guides($major; $newest; $releases; $repo): the release notes of the first
# release of every major version after $major, up to $newest.
def guides($major; $newest; $releases; $repo):
  [range($major + 1; $newest + 1) as $k | $releases | first_release($k) | select(. != null)
    | "\(.tag), \(release_url($repo))"]
  | if length == 1 then "The migration guide is in the release notes of \(.[0])."
    else "The migration guides are in the release notes of \(join("; "))." end;

# warning($node; $major; $releases; $today): the warning of $node, of the
# major version $major, when its repository has $releases.
def warning($node; $major; $releases; $today):
  ($releases | counted) as $counted
  | ($counted | map(.version[0]) | max) as $newest
  | select($newest != null and $newest > $major)
  | ($counted | first_release($newest)) as $first
  | ($counted | of_major($newest) | max_by(.version)) as $latest
  | $node.source.repo as $repo
  | (if $node.original.ref != null then "follows" else "is at" end) as $verb
  | "\($node.attribute) of flakeyard/\($repo) \($verb) v\($major), and v\($newest) is released:"
    + " \($first.tag) on \($first | date), newest \($latest.tag)."
    + " \(support($major; $newest; $counted; $today))."
    + " \(guides($major; $newest; $counted; $repo))"
  | finding($node; .);

# newer_major_findings($lookups; $now; flakeyard_nodes; ref_major): the
# warnings of every flakeyard input at $now, seconds since 1970, from $lookups
# of {repo, releases} or {repo, error}. A repository that was not looked up
# has none: the release rule reports it. flakeyard_nodes gives the nodes of
# the parsed lock, and ref_major the major version that the ref of a node
# names, or null.
def newer_major_findings($lookups; $now; flakeyard_nodes; ref_major):
  ($now | floor | strftime("%Y-%m-%d")) as $today
  | (reduce $lookups[] as $lookup ({}; .[$lookup.repo] = $lookup)) as $by_repo
  | flakeyard_nodes as $node
  | $by_repo[$node.source.repo].releases as $releases
  | select($releases != null)
  | ($node | own_major($releases; $node | ref_major)) as $major
  | select($major != null)
  | warning($node; $major; $releases; $today);

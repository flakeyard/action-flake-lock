# The end of life rule (ADR-0002, FY-0036): the branch of every root nixpkgs
# input, the ref of its original, is still supported. Reads the parsed lock of
# nodes.jq with the sources of sources.jq. The support policy of NixOS is
# hard-coded here: a change of it is a release of the action.

# The normalized source of a root nixpkgs input.
def nixpkgs_source: "github.com/nixos/nixpkgs";
# A stable branch, nixos-YY.05 or nixos-YY.11, also -small.
def stable_branch_form: "^nixos-(?<year>[0-9]{2})\\.(?<release>05|11)(-small)?$";
def century: 2000;
# The days before the end of life from which the rule warns.
def warning_days: 30;
def seconds_per_day: 86400;
# The event of the runs in which a branch past its end of life fails them.
def failing_event: "schedule";
def advice: "switch to the next stable branch (FY-0036)";

# finding($input; $message; $level): a finding of this rule: a violation when
# $level is null, else a warning or a notice, which does not fail the run.
def finding($input; $message; $level):
  {rule: "nixpkgs-eol", input: $input, message: $message}
  + if $level then {level: $level} else {} end;

# end_of_life: the last supported day, YYYY-MM-DD, of a stable branch: 31
# December of 20YY for YY.05, 30 June of the year after for YY.11; null for
# any other branch.
def end_of_life:
  first(strings | capture(stable_branch_form)) // null
  | if . == null then null
    else (.year | tonumber + century) as $year
      | if .release == "05" then "\($year)-12-31" else "\($year + 1)-06-30" end
    end;

# day: the days since 1970 of a date YYYY-MM-DD, in UTC.
def day: "\(.)T00:00:00Z" | fromdateiso8601 / seconds_per_day;

# days_left: when the end of life is, from a number of days.
def days_left: if . == 0 then "today" elif . == 1 then "in 1 day" else "in \(.) days" end;

# verdict($node; $eol; $today; $event): the finding of $node, whose branch is
# supported until the end of the day $eol, on the day $today.
def verdict($node; $eol; $today; $event):
  (($eol | day) - $today) as $days
  | "\($node.attribute) follows \($node.original.ref)" as $subject
  | if $days > warning_days then empty
    elif $days >= 0 then
      finding($node.attribute; "\($subject), which reaches its end of life on \($eol), \($days | days_left); \(advice)."; "warning")
    else
      finding($node.attribute; "\($subject), which reached its end of life on \($eol); \(advice).";
        if $event == failing_event then null else "warning" end)
    end;

# unknown($node): the notice for $node, whose branch has no known end of life.
def unknown($node):
  (if $node.original.ref == null then "has no ref, so its"
    else "follows \($node.original.ref), whose" end) as $branch
  | finding($node.attribute; "\($node.attribute) \($branch) end of life is not known; \(advice)."; "notice");

# nixpkgs_eol_findings($now; $event): the findings of every root nixpkgs
# input at $now, seconds since 1970, in a run of the event $event.
def nixpkgs_eol_findings($now; $event):
  ($now / seconds_per_day | floor) as $today
  | .nodes[] | select(.parent == null and .source.id == nixpkgs_source)
  | (.original.ref | end_of_life) as $eol
  | if $eol == null then unknown(.) else verdict(.; $eol; $today; $event) end;

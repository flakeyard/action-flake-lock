# The duplicates rule (ADR-0001, FY-0017): two distinct nodes with the same
# normalized source, also at the same rev, unless the source is allowed. Reads
# the parsed lock of nodes.jq with the sources of sources.jq.

# finding($input; $message): a violation of this rule.
def finding($input; $message): {rule: "duplicates", input: $input, message: $message};

# groups($allowed): the nodes of each source that more than one node has, but
# the sources of $allowed.
def groups($allowed):
  [.nodes[] | select(.source != null)]
  | group_by(.source.id)
  | map(select(length > 1 and (.[0].source.id | IN($allowed[]) | not)));

# matching_inputs($group): the inputs of the root whose own node is in $group.
def matching_inputs($group):
  ($group | map(.name)) as $names
  | [.inputs[] | select(.node != null and (.node | IN($names[])))];

# follows_lines($group; $input): the follows that make every other node of
# $group the node of the root input $input.
def follows_lines($group; $input):
  [$group[] | select(.name != $input.node) | "\(.attribute).follows = \($input.name | tojson);"]
  | join(" ");

# third_party_parent($nodes): the node is brought by a flake that is not of
# flakeyard.
def third_party_parent($nodes):
  .parent as $parent
  | $parent != null and ([$nodes[] | select(.name == $parent) | .source.flakeyard] != [true]);

# fix($group): how to remove the duplicate of $group, from the parsed lock.
def fix($group):
  .nodes as $nodes
  | matching_inputs($group) as $inputs
  | if ($inputs | length) == 1 then "Add to flake.nix: \(follows_lines($group; $inputs[0]))"
    elif $group[0].source.flakeyard and any($group[]; third_party_parent($nodes)) then
      "The fix is a follows: let the flakes that bring it follow one input of this flake."
    else "Make them one node with follows, or list \($group[0].source.id) in allow-duplicates." end;

# duplicates($allowed): a finding for each duplicated source.
def duplicates($allowed):
  groups($allowed)[] as $group
  | $group[0].source.id as $id
  | finding($id; "\($id) is locked \($group | length) times: \($group | map(.attribute) | join(", ")). \(fix($group))");

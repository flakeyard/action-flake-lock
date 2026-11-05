# The nodes of a flake.lock that its root reaches, each with the shortest path
# of inputs from the root to it (ADR-0001). Modules do not include each other:
# jq 1.8 fails to compile calls through two levels of include.

# The versions of the lock file with the shape that this file reads.
def supported_versions: [5, 6, 7];

# is_reference: an input value, a node name or the path of a follows.
def is_reference:
  type == "string" or (type == "array" and all(.[]; type == "string"));

# is_node: a node, with inputs that are references.
def is_node:
  type == "object" and (.inputs // {} | type == "object" and all(.[]; is_reference));

# is_lock: the shape that every supported version has.
def is_lock:
  type == "object" and (.nodes | type == "object" and all(.[]; is_node))
  and (.root | type == "string") and (.nodes[.root] != null);

# problem($documents): why the documents of a lock file, as --slurpfile reads
# them, are not a lock that the action reads; nothing when they are.
def problem($documents):
  if ($documents | length) != 1 then "is not one JSON document"
  elif ($documents[0] | is_lock | not) then "is not a lock file of Nix"
  elif any(supported_versions[]; . == $documents[0].version) | not then
    "has version \($documents[0].version | tojson); the action reads versions \(supported_versions | join(", "))"
  else empty end;

# visit($lock; $name): adds the nodes that the inputs of $name declare and that
# were not reached before, with their paths, to {queue, reached}, so that a
# cyclic or crafted lock cannot make it loop. A follows declares no node: it
# names one that another input declares, and it is not resolved.
def visit($lock; $name):
  reduce ($lock.nodes[$name].inputs // {} | to_entries[] | select(.value | type == "string")) as $input (.;
    $input.value as $node
    | if .reached[$node] != null or $lock.nodes[$node] == null then .
      else
        .reached[$node] = {path: (.reached[$name].path + [$input.key]), parent: $name}
        | .queue += [$node]
      end);

# reached($lock): {name: {path, parent}} of every node that the root reaches,
# breadth first, so that each path is a shortest one.
def reached($lock):
  {queue: [$lock.root], reached: {($lock.root): {path: [], parent: null}}}
  | until(.queue == []; .queue[0] as $name | .queue |= .[1:] | visit($lock; $name))
  | .reached;

# root_input: {name, node} of an input of the root as {key, value}. An input
# that is a follows has no node of its own: its node is null.
def root_input: {name: .key, node: (.value | strings // null)};

# root_inputs($lock): the inputs of the root.
def root_inputs($lock):
  [$lock.nodes[$lock.root].inputs // {} | to_entries[] | root_input];

# A name that Nix takes as an attribute without quotes.
def identifier_form: "^[A-Za-z_][A-Za-z0-9_'-]*$";

# nix_attribute: a name as an attribute of Nix, quoted unless it is an
# identifier.
def nix_attribute:
  if test(identifier_form) then . else tojson | gsub("\\$\\{"; "\\${") end;

# input_attribute: the attribute of flake.nix that sets an input path, such as
# inputs.a.inputs.b.
def input_attribute: map("inputs.\(nix_attribute)") | join(".");

# node($lock; $name; $at): a node with its path, also as the attribute of
# flake.nix; parent is null for an input of the root.
def node($lock; $name; $at):
  $lock.nodes[$name] as $node
  | {name: $name, path: $at.path, attribute: ($at.path | input_attribute)}
  + {locked: $node.locked, original: $node.original}
  + {parent: (if $at.parent == $lock.root then null else $at.parent end)};

# parsed($lock): what the rules read: the inputs of the root and every node
# that the root reaches, but the root.
def parsed($lock):
  reached($lock) as $reached
  | {
      inputs: root_inputs($lock),
      nodes: [$reached | to_entries[] | select(.key != $lock.root) | node($lock; .key; .value)]
    };

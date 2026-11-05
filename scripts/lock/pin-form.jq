# The pin form rule (ADR-0001, FY-0016): every input of the root with a node
# of its own is written as
# git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<40 hex digits>&shallow=1,
# as its original attributes show. Reads the parsed lock of nodes.jq with the
# sources of sources.jq.

def github_url_form: "^https://github\\.com/[A-Za-z0-9-]+/[A-Za-z0-9._-]+$";
def rev_form: "^[0-9a-f]{40}$";
# The moving tag of a major version, the ref of every flakeyard input.
def major_tag_form: "^v[0-9]+$";
# Attributes that the form has not.
def absent_attributes: ["submodules", "lfs", "allRefs"];
def pin_form: "git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<commit>&shallow=1";

# finding($input; $message): a violation of this rule.
def finding($input; $message): {rule: "pin-form", input: $input, message: $message};

# matches($form): a string that matches $form.
def matches($form): type == "string" and test($form);

# stays_inside: a relative path that does not leave the directory it starts in.
def stays_inside:
  reduce (split("/")[] | select(. != "" and . != ".")) as $segment (0;
    if . < 0 then . elif $segment == ".." then . - 1 else . + 1 end)
  | . >= 0;

# is_exempt: a node of a relative path: input inside the repository.
def is_exempt:
  .original | .type == "path" and (.path | type == "string" and (startswith("/") | not) and stays_inside);

# form_problems: what of the form a node has not.
def form_problems:
  .original as $original | .locked as $locked
  | (if $original.type == "git" and ($original.url | matches(github_url_form)) then empty
      else "it is not a git+https URL of a repository on github.com" end),
    (if $original.ref | matches(".") then empty else "it has no ref" end),
    (if $original.rev | matches(rev_form) then empty else "it has no rev of 40 hex digits" end),
    (if $original.rev == $locked.rev then empty else "its rev is not the locked rev" end),
    (if $original.shallow == true then empty else "it is not shallow" end),
    (absent_attributes[] as $name | select($original | has($name)) | "it has \($name)");

# flakeyard_problems: what of the form a flakeyard node has not.
def flakeyard_problems:
  select(.source.flakeyard)
  | if .original.ref | matches(major_tag_form) then empty
    else "its ref is not the major tag vX of a flakeyard repository" end;

# pin_form_findings: a finding for each input of the root that is not in the
# form.
def pin_form_findings:
  .nodes[] | select(.parent == null and (is_exempt | not))
  | [form_problems, flakeyard_problems] as $problems
  | select($problems != [])
  | finding(.attribute; "\(.attribute) is not pinned as \(pin_form): \($problems | join("; ")).");

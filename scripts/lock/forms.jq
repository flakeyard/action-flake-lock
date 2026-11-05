# The forms that more than one rule checks. Modules do not include each other
# (nodes.jq says why): the program of a rule includes this file and passes the
# forms to the rule.

# A commit: 40 hex digits in lower case.
def rev_form: "^[0-9a-f]{40}$";

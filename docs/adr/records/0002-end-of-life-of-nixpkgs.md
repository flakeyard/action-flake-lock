---
id: ADR-0002
title: End of life of nixpkgs
status: accepted
date: 2026-11-07
supersedes: []
superseded_by: []
related: [ADR-0001]
affects: ["action.yml", "scripts/**", "tests/**", "nixpkgs-eol"]
review_by:
---

## Context

[FY-0036][fy-0036] supersedes [FY-0026][fy-0026]. It keeps the stable branch,
the switch to the next branch, the Nix minor version and the second nixpkgs for
broken tools, and replaces the end-of-life part. Every repository recorded the
end of life of its branch in a file `nixpkgs-eol` and ran a weekly job of its
own that read it. Under FY-0036, action-flake-lock derives the end of life from
`flake.lock` itself, and workflow-check runs the action, so no repository keeps
a date or a job of its own.

What FY-0036 requires of the action:

- The end of life is derived from the branch of each root nixpkgs input of the
  lock. `nixos-YY.05` and `nixos-YY.05-small` reach it on 31 December 20YY;
  `nixos-YY.11` and `nixos-YY.11-small` on 30 June of the year after 20YY; in
  both cases at the end of that day in UTC. The dates follow the NixOS support
  policy, checked against the announcement of NixOS 26.05 and endoflife.date.
  For any other branch the end of life is not known.
- From 30 days before that date, the action warns and the check passes. After
  it, the end of life is a violation only in runs of the `schedule` event; in
  runs of other events it is a warning, so a pull request is never blocked by
  the date. The weekly scheduled run is the check of FY-0026 that is not a
  required one.
- The rule is switched by an input `nixpkgs-eol`, `true` by default.
- The support policy is part of the action; a change of it is a release of the
  action.

[ADR-0001](0001-check-flake-lock.md) fixes the inputs of the action, says that
it has no warn-only mode and that a step writes at most 10 annotations, and
requires a major release for a tightening of a rule. Its scripts already have a
cap for error annotations only: warnings are written without one. GitHub keeps
at most 10 error and 10 warning annotations of a step, counted apart.

[FY-0024][fy-0024] makes `0.y.z` releases previews without compatibility
guarantees. The action is at `0.1.x`.

## Decision

### Rule

The action has a fourth rule, the **end of life of nixpkgs**, on unless the
input `nixpkgs-eol` is `false`. A root nixpkgs input is a root input whose
normalized source, in the sense of the duplicates rule of ADR-0001, is
`github.com/nixos/nixpkgs`. Its branch is the `ref` of its `original`.

| Branch                                 | End of life                       |
| -------------------------------------- | --------------------------------- |
| `nixos-YY.05`, `nixos-YY.05-small`     | 31 December 20YY, 23:59:59 UTC    |
| `nixos-YY.11`, `nixos-YY.11-small`     | 30 June of 20YY + 1, 23:59:59 UTC |
| any other branch, or no `ref` (notice) | not known                         |

For each root nixpkgs input, today's date is taken with `date -u` and compared
with the end of life of its branch:

- More than 30 days before it: nothing is reported.
- From 30 days before it to its end, included: a warning that names the branch,
  the date and the days left. The check passes.
- After it: in a run whose `GITHUB_EVENT_NAME` is `schedule`, a violation that
  names the branch and the date and fails the run; in every other event, a
  warning with the same text.
- A branch without a known end of life: a notice that says so. The check passes.

Every message says to switch to the next stable branch of FY-0036. The table is
hard-coded in the action; a change of the NixOS support policy is a release of
the action.

### Warnings are not violations

A warning or a notice does not fail the run. This is not a warn-only mode: no
input turns a violation into a warning, and the release, duplicates and pin form
rules report only violations. Only this rule warns, and only by the date and the
event that FY-0036 fixes.

### Report

Warnings and notices are listed in the job summary next to the violations. A
step writes at most 10 error annotations and at most 10 warning annotations,
each kind with its own count and the same logic: the first nine are written at
once, and the tenth is the last one of its kind or says how many more of that
kind the job summary has.

### Interface

The inputs are `path`, `allow-duplicates`, `pin-form`, `nixpkgs-eol` and
`github-token`. `nixpkgs-eol` is `true` by default; `false` switches the rule
off. The action still has no outputs. Besides the inputs, the rule reads
`GITHUB_EVENT_NAME`, which the runner sets; it reaches the scripts like the
other variables of a step, through the allowlist of `run-step.sh`.

### Release

The rule can fail a scheduled run of a passing project, so it is a tightening.
Before `v1.0.0`, a `0.y` bump plays the role of a major release
([FY-0024][fy-0024] previews): the rule ships on by default in `0.2.0`, after
`0.1.x`. From `v1.0.0` on, a tightening of this rule, such as a shorter warning
period, is a major release as ADR-0001 requires.

### This repository

The weekly scheduled run of `test.yaml` checks the root lock with the action
itself and `dev/flake.lock` through workflow-check, so both get the rule once
they run releases that have it. The file `nixpkgs-eol`, its script and the
weekly end-of-life job are removed once every repository runs a release of
workflow-check with the rule, as FY-0036 says.

### Tests

Tests set today's date with a stub of `date` first on `PATH`, as `gh` and `nix`
are stubbed. They cover both branch kinds and `-small`, the days around the
start of the warning and around the end of life, every event against `schedule`,
an unknown branch, an input without `ref`, two root nixpkgs inputs,
`nixpkgs-eol: false`, and more than 10 warnings in one step.

### Changes to ADR-0001

This record amends [ADR-0001](0001-check-flake-lock.md); its other decisions and
constraints stand:

- "Rules": a fourth rule, the end of life of nixpkgs, joins the three listed.
- "Interface" (constraint) and "Inputs" (decision): the inputs MUST be exactly
  `path`, `allow-duplicates`, `pin-form`, `nixpkgs-eol` and `github-token`.
- "Reporting" (constraint) and "Report" (decision): a warning is not a
  violation, so a run with warnings and no violation succeeds; "no warn-only
  mode" still holds as stated above. The cap of 10 annotations per step applies
  to error and warning annotations, counted apart.
- "Tools" (decision): the sentence that this repository records the end of life
  in `nixpkgs-eol` and runs the weekly job of FY-0026 holds only until the
  removal above.
- "Interface" (constraint), "Tightening any rule MUST be a major release":
  before `v1.0.0`, a `0.y` bump is that release.

## Constraints

- The action MUST derive the end of life only from the `ref` of the `original`
  of every root input whose normalized source is `github.com/nixos/nixpkgs`:
  `nixos-YY.05` and `nixos-YY.05-small` end on 31 December 20YY, `nixos-YY.11`
  and `nixos-YY.11-small` on 30 June of 20YY + 1, both at the end of the day in
  UTC.
- For any other branch, or no `ref`, the action MUST emit a notice that the end
  of life is not known and MUST NOT fail.
- From 30 days before the end of life to its end, the action MUST emit a warning
  and MUST NOT fail.
- After the end of life, the action MUST report a violation and fail when
  `GITHUB_EVENT_NAME` is `schedule`, and MUST emit a warning and MUST NOT fail
  for every other event.
- The rule MUST be switched by the input `nixpkgs-eol`, `true` by default.
- The support policy MUST be hard-coded in the action; a change of it MUST be a
  release of the action.
- Warnings and notices MUST NOT fail the run. Only this rule MAY warn; the other
  rules MUST report violations only.
- A step MUST write at most 10 error annotations and at most 10 warning
  annotations, each kind with its own count, the last of a kind naming how many
  more of that kind the job summary has.
- Tests MUST set the date through a stub of `date` on `PATH`, not through an
  input or a variable of the action.

## Consequences

- (+) No repository keeps a date or a weekly job for the end of life; the date
  follows the branch in the lock it describes.
- (+) A pull request is never blocked by the date, while the weekly scheduled
  run still fails after the end of life.
- (+) A second nixpkgs for a broken tool is checked as well, or reported as
  having no known end of life.
- (−) A change of the NixOS support policy needs a release of the action and an
  update in every consumer.
- (−) After the end of life, only scheduled runs fail; a repository without a
  weekly `schedule` sees only warnings.
- (−) A branch outside the table, such as `nixos-unstable`, gets a notice and no
  check.
- (±) The verdict of a scheduled run depends on the date, so rerunning an old
  commit may fail where it once passed.

## Alternatives considered

- **Keep `nixpkgs-eol` files and the weekly jobs.** Works today, but every
  repository repeats a date and a job, and the date can drift from the branch in
  the lock.
- **Fetch the end of life from endoflife.date at run time.** Follows a policy
  change without a release, but adds a network dependency and an unpinned input
  to every run.
- **Fail on the date in every event.** One verdict for every run, but it blocks
  unrelated pull requests on the day the branch reaches its end of life.
- **A date input or variable for tests.** Simpler tests, but it would let a
  caller move the date.

[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
[fy-0036]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0036-check-the-end-of-life-of-nixpkgs-in-flake-lock.md

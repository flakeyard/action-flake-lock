---
id: ADR-0004
title: Warn about a newer major version of flakeyard inputs
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: [ADR-0001, ADR-0002]
affects:
  [
    "action.yml",
    "scripts/step/check.sh",
    "scripts/step/releases.sh",
    "scripts/step/report.sh",
    "scripts/lock/**",
    "tests/**",
  ]
review_by:
---

## Context

[FY-0016][fy-0016] pins a flakeyard input with `ref=vX`, the moving tag of its
major version. Renovate follows that tag and never proposes a new major version:
it cannot change `ref` and `rev` together. The only signal of a new major
version is the warning that the last minor release of the old one prints during
evaluation. [FY-0038][fy-0038] records it in `nix/next-major.nix` of the atom,
notes that an evaluation warning appears only in the log of the job that
evaluates, which nobody reads in a passing run, and requires that
action-flake-lock warn, with an annotation, about every flakeyard input whose
repository has released a major version above the one named by its `ref`.

[FY-0024][fy-0024] fixes what the warning has to say:

- Releases start at `v1.0.0`; `0.y.z` releases are previews without
  compatibility guarantees or support, and are marked as pre-releases.
- The previous major version receives security fixes for 6 months after the
  first release of the next major version; older versions receive nothing.
- Every major release has a migration guide in its release notes.
- A new rule that could fail a passing project ships disabled in a minor
  release; a deprecation warns, for an action, with a workflow annotation.

What the action already has:

- The release rule of [ADR-0001](0001-check-flake-lock.md) looks up, in the step
  "Look up the releases", every release of every flakeyard repository of the
  lock: one GraphQL query per repository with `gh api graphql --paginate`, 100
  releases per page and every page, at most 50 repositories per run. Each lookup
  is recorded once per repository, not per major version. The query reads
  `tagName`, `isDraft`, `immutable` and `tagCommit.oid`; it reads neither
  `isPrerelease` nor `publishedAt`. `releases.jq` keeps the immutable published
  releases whose tag matches `vX.Y.Z`.
- A repository whose releases could not be looked up, because the API failed,
  its name is invalid or the lock has more than 50 flakeyard repositories, is
  reported by the release rule as "Could not verify", which fails the run.
- [ADR-0002](0002-end-of-life-of-nixpkgs.md) introduced warnings, which do not
  fail the run, and a cap of 10 warning annotations per step, counted apart from
  error annotations; it lets only the end of life of nixpkgs warn. Tests set
  today's date through a stub of `date`.
- The inputs are `path`, `allow-duplicates`, `pin-form`, `nixpkgs-eol` and
  `github-token`. The action is at `0.2.3`; release-please bumps the minor
  version for a `feat` before `v1.0.0` and marks `0.y.z` releases as
  pre-releases.

## Decision

### Rule

The action has a fifth rule, the **newer major version**, on unless the input
`newer-major` is `false`. It applies to every flakeyard input in the sense of
ADR-0001, root or not, like the release rule.

The major version of an input, M, is the one its `ref` names (`vX` or `vX.Y.Z`).
Without a `ref`, it is the major version of the newest release whose tag commit
is its `rev`; when there is none, the rule says nothing about the input, since
the release rule already reports it.

The releases that count are those the release rule keeps (immutable, not a
draft, tag `vX.Y.Z`) that are also not pre-releases. N is the highest major
version among them. When N > M, the rule writes one warning for the input; when
N ≤ M, nothing. For a `v0` input this means a warning once `v1.0.0` or any later
release exists. A pre-release never counts, whatever its tag, so `0.y.z`
releases never make a newer major version.

### Message

The first release of a major version K is the release of K with the lowest
version among the releases that count, normally `vK.0.0`. Its date is the UTC
date of its `publishedAt`. The support of M ends at the end, in UTC, of the day
6 calendar months after the date of the first release of M + 1, or of the last
day of that month when it has no such day.

The warning names:

1. the input (its attribute path), its repository and M;
2. N, its first release with its date, and the newest release of N;
3. the support of M, compared with today's date from `date -u`:
   - M = 0: `0.y.z` releases are previews without support;
   - N = M + 1: M receives security fixes until the end date above, or received
     them until that date when it has passed;
   - N > M + 1: M receives no fixes, since only `v(N - 1)` is still supported,
     and only until its own end date;
4. the migration guides: the release notes of the first release of every major
   version from M + 1 to N, each as
   `https://github.com/flakeyard/<repo>/releases/tag/<tag>`.

For example:

```text
atom-nix of flakeyard/atom-nix follows v1, and v2 is released: v2.0.0 on
2026-11-03, newest v2.1.0. v1 receives security fixes until 2027-05-03. The
migration guide is in the release notes of v2.0.0,
https://github.com/flakeyard/atom-nix/releases/tag/v2.0.0.
```

Two nodes of the same repository and major version get one warning each, as they
get one finding each from the release rule.

### Lookup

The rule reads the releases that the step "Look up the releases" already
fetched; it makes no request of its own. The GraphQL query of that step gains
the fields `isPrerelease` and `publishedAt` of each release. These are scalar
fields of nodes already fetched, so the number of requests, pages and
repositories is unchanged, as is the token: `github-token` with no permissions.
The lookup is not bounded by major version or by a page limit, so the newest
major version and the first release of every major version are already in it.
The REST endpoint `releases/latest` is not needed.

The same step writes the findings of the rule next to those of the release rule,
from the same lookups, when `newer-major` is not `false`.

### Failure to look up

The rule has no finding of its own for a repository whose releases could not be
looked up. Such a repository already fails the run through the release rule,
which is always on and reports every input of it as "Could not verify"
(ADR-0001). A notice from this rule as well would report the same cause twice;
an error would make a rule that only warns fail the run. The rule therefore
never fails the run, and a missing warning never does either.

### Report

The warnings are listed in the job summary with the title "Newer major version"
and written as warning annotations of the lock file. They share the cap of 10
warning annotations per step of ADR-0002 with the warnings of the end of life of
nixpkgs: the first nine warnings of the step are written at once, and the tenth
is the last one or says how many more warnings the job summary has.

### Interface

The inputs are `path`, `allow-duplicates`, `pin-form`, `nixpkgs-eol`,
`newer-major` and `github-token`. `newer-major` is `true` by default; `false`
switches the rule off, for a project that stays on an old major version on
purpose or whose warnings would crowd out others under the shared cap. It is
validated like `pin-form` and reaches the scripts through the allowlist of
`run-step.sh`. The action still has no outputs.

### Release

A warning cannot fail a passing project, so the rule is not a tightening and
ships on by default in a minor release ([FY-0024][fy-0024]): a `feat`, which
release-please makes `0.3.0` after `0.2.3`. From `v1.0.0` on, turning these
warnings into violations would be a tightening and a major release.

### Tests

The stub of `gh` returns pages with `isPrerelease` and `publishedAt`, and the
stub of `date` sets today. Tests cover: no newer major version; N = M + 1 before
and after the end of support; N > M + 1; a `v0` input with and without `v1.0.0`;
a newer major version that has only pre-releases, drafts or mutable releases; an
input without `ref`; a first release of a major version other than `vK.0.0`; the
end of support on the 31st of a month; two nodes of one repository; a repository
that could not be looked up, which gets "Could not verify" and no warning;
`newer-major: false`; and more than 10 warnings of both warning rules in one
step.

### Changes to ADR-0001 and ADR-0002

This record amends [ADR-0001](0001-check-flake-lock.md) and
[ADR-0002](0002-end-of-life-of-nixpkgs.md); their other decisions and
constraints stand:

- ADR-0001 "Rules": a fifth rule, the newer major version, joins the four
  listed.
- ADR-0001 "Interface" (constraint) and "Inputs" (decision), as amended by
  ADR-0002: the inputs MUST be exactly `path`, `allow-duplicates`, `pin-form`,
  `nixpkgs-eol`, `newer-major` and `github-token`.
- ADR-0001 "Steps": the release lookup also reads `isPrerelease` and
  `publishedAt` of each release.
- ADR-0002 "Warnings are not violations" and its constraint "Only this rule MAY
  warn; the other rules MUST report violations only": the end of life of nixpkgs
  and the newer major version MAY warn; the release, duplicates and pin form
  rules MUST report violations only. "No warn-only mode" still holds: no input
  turns a violation into a warning.

## Constraints

- With `newer-major` on, the action MUST write one warning for every flakeyard
  input, root or not, whose repository has an immutable, published,
  non-pre-release release `vX.Y.Z` of a major version above the one its `ref`
  names, or, without a `ref`, above that of the newest release of its `rev`.
- Pre-releases, drafts, mutable releases and tags not of the form `vX.Y.Z` MUST
  NOT count as a newer major version.
- The warning MUST name the input, its repository and major version, the newest
  major version with its first release and that release's date, the newest
  release, the support of the input's major version under [FY-0024][fy-0024]
  counted from the first release of the next major version, and the release
  notes of the first release of every newer major version as the migration
  guides.
- The rule MUST use only the releases that the release lookup fetched and MUST
  NOT make API requests of its own.
- The rule MUST NOT fail the run and MUST NOT report a repository that could not
  be looked up; the release rule reports it.
- The warnings MUST share the cap of 10 warning annotations per step with the
  other warnings, and MUST all be listed in the job summary.
- The rule MUST be switched by the input `newer-major`, `true` by default.
- Tests MUST set today's date through the stub of `date`.

## Consequences

- (+) A newer major version of a flakeyard input is announced as an annotation
  in every run of every consumer, with the end of support and the migration
  guide, not only in an evaluation log.
- (+) No extra API requests: the releases are read once, for both rules.
- (+) The warning works for every flakeyard repository with releases, not only
  for atoms that ship `nix/next-major.nix`.
- (−) A flakeyard input reached through a third-party or another flakeyard flake
  warns as well, although the consumer can fix it only by a `follows` or by
  waiting for that flake to update.
- (−) Warnings of this rule and of the end of life of nixpkgs share 10
  annotations per step; beyond them, only the job summary lists them.
- (−) The end of support is derived from `publishedAt`, which records when the
  release was published, not when its code was ready.
- (±) Until the newer major version is released, the warning of the last minor
  release of FY-0038 is the only signal; this rule starts with the release.
- (±) The verdict on the support of a major version depends on the date, so a
  rerun of an old commit may print a different text.

## Alternatives considered

- **The evaluation warning of the atom alone.** No change to the action, but
  [FY-0038][fy-0038] notes that it is seen only by people who read evaluation
  logs, and only atoms have it.
- **Renovate pull requests for major versions.** The natural channel, but
  Renovate cannot change `ref` and `rev` of a flake input together
  ([FY-0016][fy-0016]).
- **A separate action.** Keeps this action to its rules, but it would be a
  second reader of the same releases with its own lookup, token and tools, which
  [FY-0035][fy-0035] forbids.
- **`releases/latest` per repository.** One call gives the newest
  non-pre-release release, but not the first release of a major version and its
  date, and it adds a request per repository to what the lookup already has.
- **A notice when the lookup failed.** Says that the rule did not run, but the
  release rule already fails the run with "Could not verify" for the same
  repository.
- **Off by default.** The usual way for a new rule, but this rule only warns, so
  it cannot fail a passing project, and FY-0038 wants every consumer to see it.

[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md

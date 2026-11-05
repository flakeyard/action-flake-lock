---
id: ADR-0001
title: Check flake.lock
status: accepted
date: 2026-11-05
supersedes: []
superseded_by: []
related: []
affects:
  ["action.yml", "flake.nix", "flake.lock", "scripts/**", "dev/**", "tests/**"]
review_by:
---

## Context

action-flake-lock is step 6 of the bootstrap order of [FY-0022][fy-0022], which
requires an accepted ADR before its code is written and asks where its tools
come from. Decisions of flakeyard require of it:

- [FY-0016][fy-0016]: flakeyard inputs are pinned in the form
  `git+https://github.com/<owner>/<repo>?ref=vX&rev=<commit>&shallow=1`. Nix
  fetches `rev` and does not check that it belongs to `ref`, so the action MUST
  fail when the `rev` of a flakeyard input is not the commit of a release tag
  `vX.Y.Z` of the major version named by its `ref`.
- [FY-0017][fy-0017]: CI runs the action before evaluating the project's flake.
  It reports duplicated sources the atoms cannot see, such as a second nixpkgs:
  it compares normalized sources (case-insensitive host, owner and repository,
  `dir`), treats `github:` and `git+https://github.com` as the same source,
  skips sources it cannot identify, honours a list of intentional duplicates and
  prints a `follows` line only when exactly one root input matches. "Before any
  Nix evaluation" means before evaluating the project's flake: the action
  evaluates only its own.
- [FY-0030][fy-0030]: an action is a composite action with one task whose tools
  come from its own `flake.lock`; untrusted values reach scripts only through
  environment variables. Checking `flake.lock` is not an API step, so the tools
  of the runner may not be used for it.
- [FY-0026][fy-0026]: every nixpkgs pin follows the same stable branch,
  `nixos-26.05` today, records its end of life and runs a weekly end-of-life
  check. A tool broken on the stable branch MAY come from a second nixpkgs
  input, which is an intentional duplicate in the projects that do this.
- [FY-0024][fy-0024]: the public API of an action is its inputs, outputs,
  secrets, required permissions, events and runners. A rule that could fail a
  passing project ships disabled in a minor release.
- [FY-0028][fy-0028]: every dependency is pinned to an immutable reference. A
  tag `vX.Y.Z` is immutable only while its GitHub release is immutable and
  exists; the moving tag `vX` has no release.
- [FY-0033][fy-0033]: a stolen key of `flakeyard-bot` can create a release from
  any commit; the weekly release audit finds it, and forged releases are
  deleted.

A cold fetch and evaluation of `jq.bin` from `nixos-26.05` took 7 s on a
developer host and fetched 61 MiB of git objects; the cost on GitHub-hosted
runners was not measured. `nix build <flake>#jq` prints two store paths, `bin`
and `man`, because `pkgs.jq` has several outputs; a script that takes the first
line of that output may run the wrong path.

## Decision

### Rules

The action checks one `flake.lock` of the consumer. A flakeyard input is a node
whose `locked` source has host `github.com` and owner `flakeyard`, compared
without regard to case. The owner is fixed until a decision about a second
organization ([FY-0022][fy-0022]).

1. **Release rule** ([FY-0016][fy-0016]), always on. The `rev` of every
   flakeyard input is the commit of the tag of an immutable GitHub release
   `vX.Y.Z`. Its `ref`, when set, is `vX` of the same major version or exactly
   that `vX.Y.Z`. A violation names the newest valid release of that major
   version and its commit.
2. **Duplicates** ([FY-0017][fy-0017]), always on. The source of a node is taken
   from `locked`. Recognised forms on `github.com` are `github:`, `git+https`,
   `git+ssh` and `ssh://git@`, and tarballs
   `https://github.com/<owner>/<repo>/archive/...`. Host, owner and repository
   are compared without regard to case, `.git` and a trailing `/` are removed,
   and `dir` is part of the source. Every other source (GitLab, sourcehut,
   FlakeHub, other tarballs, `path`, indirect) is skipped. A duplicate is two
   distinct nodes with the same normalized source, also at the same `rev`.
   `follows` (array values in `inputs`) are resolved with a depth limit, so that
   a crafted or cyclic lock cannot loop. A `follows` line, nested ones such as
   `inputs.a.inputs.b.follows` included, is printed only when exactly one root
   input matches; for a flakeyard input reached through a third-party flake the
   message says that the fix is a `follows`. The input `allow-duplicates` lists
   intentional duplicates as normalized sources, such as
   `github.com/nixos/nixpkgs` or `github.com/<owner>/<repo>?dir=<dir>`; the
   second nixpkgs of [FY-0026][fy-0026] goes there.
3. **Pin form** ([FY-0016][fy-0016]), on unless the input `pin-form` is `false`.
   Every root input is written as
   `git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<40 hex digits>&shallow=1`,
   checked from `original`: `original.rev` equals `locked.rev`, `shallow` is
   `true`, and `submodules`, `lfs` and `allRefs` are absent, because the form of
   [FY-0016][fy-0016] has none of them. The `ref` of a flakeyard input is `vX`.
   Relative `path:` inputs inside the repository are exempt; absolute paths and
   `git+file` are violations. A root input that is a `follows` has no node of
   its own and is skipped.

The action accepts lock files of version 7, which Nix 2.35 writes, and versions
5 and 6 only when its tests show that they have the same shape. It fails on any
other version and on a missing lock file, with a message that says which.

### Tools

The action is a composite action with its own root flake. Its only input is
`nixpkgs`, pinned to `nixos-26.05` in the form of [FY-0016][fy-0016]. Its only
outputs are `packages.{x86_64,aarch64}-linux.{jq,gh}`, with `jq = pkgs.jq.bin`
and `gh = pkgs.gh`. A step builds a tool with

```sh
nix build --no-link --print-out-paths --no-update-lock-file \
  "path:$GITHUB_ACTION_PATH#<package>"
```

and fails unless that prints exactly one path. Tools run by absolute path, or
through `PATH` set only inside the step; the action never writes `$GITHUB_PATH`.
The `gh` of the action is pinned like `jq`, so the API exception of
[FY-0030][fy-0030] is not used.

`nix` must already be on `PATH`, with `nix-command` and `flakes` enabled: the
action does not install Nix, and action-setup-nix refuses to run when Nix
exists. The runner also provides `git` and `bash`. Supported runners are
GitHub-hosted Linux on x86_64 and arm64; GitHub Enterprise Server and other
operating systems are rejected in the first step. Determinate Nix and Lix are
not tested.

The repository's own checks live in `dev/flake.nix` with its own lock, so they
add nothing to what consumers fetch. The root flake's nixpkgs is updated by
Renovate once a month with commit type `fix`, by a rule in this repository's own
`renovate.json`, not in the renovate-config preset. The repository records the
end of life of its branch in `nixpkgs-eol` and runs the weekly end-of-life job
of [FY-0026][fy-0026].

### Steps

1. Parse the lock with the pinned `jq` into a file under `$RUNNER_TEMP`.
2. Look up releases with the pinned `gh`, through GraphQL or REST: annotated
   tags are peeled to their commits, tags are filtered by
   `^vX\.[0-9]+\.[0-9]+$`, lookups are deduplicated by repository and major
   version, their number has an upper bound, and transient failures are retried
   like `lib/github/api.sh` of workflow-check does. An input that could not be
   verified is reported apart from a violation, and fails the run as well.
3. Report.

### Inputs

- `path`: one lock file, `flake.lock` by default.
- `allow-duplicates`: a newline-separated list of normalized sources.
- `pin-form`: `true` by default.
- `github-token`: `github.token` by default. It needs no permissions; it is
  validated, masked and passed only in the environment of the API step.

The action has no outputs. Any tightening of a rule is a major release.

### Security

- Annotations escape both messages and properties (`%`, CR, LF, `,`, `:`).
- Text taken from the lock reaches `jq` only through `--arg` and `--argjson`.
- The lock is read only when it is a regular file whose real path is inside the
  workspace.
- Owner, repository, `rev` and `ref` are validated before they become part of an
  API path.
- `GH_HOST` is `github.com`; `GH_ENTERPRISE_TOKEN`, `GH_REPO` and
  `GH_CONFIG_DIR` are cleared.

### Report

One run reports every violation. The job summary lists all of them; each step
writes at most 10 annotations, the last one saying how many more the job summary
has. The action then exits with a non-zero status; it has no warn-only mode. A
duplicate that the atoms report as well is reported twice, once by each.

### Tests

Fixtures are lock files without `flake.nix`, so that the `nix` manager of
Renovate ignores them. `gh` and `nix` are replaced by stubs, as in `tests/bin`
of workflow-check. A test builds `path:.#jq` and `path:.#gh` directly and checks
that each yields exactly one path. CI runs on x86_64 and arm64.

### Bootstrap

Until this action is released, its own CI uses workflow-check 0.1.x without it,
and the README says so in a "Bootstrap" section. workflow-check adopts the
action in its first pull request after the action's release
([FY-0022][fy-0022]); how it calls the action is decided in [workflow-check
ADR-0002][wc-adr-0002].

The first implementation pull request measures the cost of the action on
runners, whether a token with `permissions: {}` reads the releases of public
repositories, and how release lookups paginate.

## Constraints

### Rules on the lock

- The action MUST fail when the `rev` of a flakeyard input is not the commit of
  the tag of an existing immutable GitHub release `vX.Y.Z`, or when its `ref` is
  set and is neither `vX` of that major version nor that `vX.Y.Z`.
- A release-rule violation MUST name the newest valid release of the major
  version and its commit.
- The owner `flakeyard` MUST be compared without regard to case and MUST NOT be
  an input of the action.
- The action MUST report two distinct nodes with the same normalized source as a
  duplicate, also at the same `rev`, unless the source is listed in
  `allow-duplicates`.
- Normalization MUST ignore case of host, owner and repository, MUST remove
  `.git` and a trailing `/`, and MUST keep `dir`. Sources outside the recognised
  forms MUST be skipped, not reported.
- Resolution of `follows` MUST stop at a depth limit; a cyclic or crafted lock
  MUST NOT make the action loop.
- A `follows` line MUST be printed only when exactly one root input matches.
- With `pin-form` on, every root input with a node MUST use the form of
  [FY-0016][fy-0016], with `original.rev` equal to `locked.rev`,
  `shallow = true` and no `submodules`, `lfs` or `allRefs`; the `ref` of a
  flakeyard input MUST be `vX`. Only relative `path:` inputs inside the
  repository MAY be exempt.
- The action MUST accept lock version 7 and MUST fail on versions other than 5,
  6 and 7 and on a missing lock file.

### Tools and runners

- The action MUST take `jq` and `gh` only from its own root flake, whose only
  input is `nixpkgs` on the stable branch of [FY-0026][fy-0026] and whose only
  outputs are `packages.{x86_64,aarch64}-linux.{jq,gh}`.
- Every tool build MUST use `--no-update-lock-file` and MUST fail unless it
  prints exactly one path.
- The action MUST NOT install Nix, MUST NOT evaluate the consumer's flake and
  MUST NOT write `$GITHUB_PATH`.
- The action MUST reject runners other than GitHub-hosted Linux on x86_64 and
  arm64, and GitHub Enterprise Server, before it builds anything.
- The repository's own checks MUST live in `dev/flake.nix`, not in the root
  flake.

### Interface

- The inputs MUST be exactly `path`, `allow-duplicates`, `pin-form` and
  `github-token`, and the action MUST have no outputs.
- `github-token` MUST need no permissions, MUST be masked and MUST appear only
  in the environment of the API step.
- Tightening any rule MUST be a major release.

### Untrusted text

- Annotation messages and properties MUST escape `%`, CR, LF, `,` and `:`.
- Text from the lock MUST reach `jq` only through `--arg` or `--argjson`, and
  MUST NOT appear in `${{ }}` expressions or in a program text.
- The lock MUST be read only when it is a regular file whose real path is inside
  the workspace.
- Owner, repository, `rev` and `ref` MUST be validated before they are used in
  an API path.
- The API step MUST set `GH_HOST=github.com` and clear `GH_ENTERPRISE_TOKEN`,
  `GH_REPO` and `GH_CONFIG_DIR`.

### Reporting

- One run MUST report every violation, all of them in the job summary, and MUST
  exit with a non-zero status when there is any.
- A step MUST write at most 10 annotations and then one that names how many more
  the job summary has.
- An input that could not be verified MUST be reported apart from a violation
  and MUST fail the run.
- The action MUST NOT have a warn-only mode.

### Test suite

- Test fixtures MUST be lock files without a `flake.nix`.
- Tests MUST use stubs of `gh` and `nix` for the rules, MUST build each package
  of the root flake directly and MUST check that it yields exactly one path.
- CI MUST run the tests on x86_64 and arm64.

## Consequences

- (+) A flakeyard input that points at unreleased code or at a deleted forged
  release fails CI before the project's flake is evaluated.
- (+) Duplicates that atoms cannot see, such as a second nixpkgs, are found with
  the line that fixes them when there is one.
- (+) `jq` and `gh` change only with a release of the action, and no API
  exception of [FY-0030][fy-0030] is needed.
- (+) The action reports every problem of a lock in one run.
- (−) The action fetches its own nixpkgs: 61 MiB and 7 s cold on a developer
  host, unmeasured on runners.
- (−) The pin form is not a security check: GitHub serves commits of forks under
  the URL of the parent repository, so a well-formed `rev` may come from a fork.
  Only the release rule protects flakeyard inputs.
- (−) Sources outside the recognised forms are skipped, so a duplicate through
  FlakeHub, for example a FlakeHub nixpkgs next to a GitHub one, is missed.
- (−) A release made with a stolen key passes the release rule until the release
  audit of [FY-0033][fy-0033] finds it and it is deleted.
- (−) Every monthly nixpkgs update is a `fix` release, which proposes an update
  of the action to every consumer each month.
- (−) Nix must be on `PATH` before the action; Determinate Nix and Lix are not
  tested.
- (±) A duplicate reported by an atom is reported again by the action.
- (±) Every tightening of a rule waits for a major release.

## Alternatives considered

- **An evaluator in pure Nix builtins.** No tools to build, but our own Nix code
  to debug, while the organization's established language for such checks is
  `jq`.
- **The `jq` and `gh` of the runner under the API exception of
  [FY-0030][fy-0030].** No Nix build, but the tools would be unpinned, and
  checking a lock is not an API step.
- **`git ls-remote` with a pinned `git`.** No API token, but it cannot see
  releases or whether they are immutable.
- **A separate `flake-lock` job before the matrix of workflow-check.** Checks
  once per run, but installs Nix a second time and adds 30 to 40 s in series.
- **Doing nothing.** Leaves the `rev` of flakeyard inputs unchecked, which
  [FY-0016][fy-0016] forbids.

[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
[fy-0028]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0028-supply-chain.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0033]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0033-custody-of-the-release-bot-key-and-audit-of-releases.md
[wc-adr-0002]:
  https://github.com/flakeyard/workflow-check/blob/main/docs/adr/records/0002-check-flake-lock.md

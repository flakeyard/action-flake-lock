# action-flake-lock

A composite GitHub Action that checks `flake.lock` of flakeyard repositories and
of projects generated from flakeyard templates.

It fails when the `rev` of a flakeyard input is not the commit of an immutable
release, when two nodes lock the same source, or when an input of the root is
not pinned in the form of [FY-0016][fy-0016]. It warns before the nixpkgs branch
of the lock reaches its end of life, and fails a scheduled run after it
([FY-0036][fy-0036]). It reads only the lock file and evaluates only its own
flake, so it runs before the project's flake is evaluated ([FY-0017][fy-0017]).

## Usage

```yaml
on:
  pull_request:
  schedule:
    - cron: "23 4 * * 1"

jobs:
  flake:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<commit> # v7.0.1
        with:
          persist-credentials: false
      - uses: flakeyard/action-setup-nix@<commit> # vX.Y.Z
      - uses: flakeyard/action-flake-lock@<commit> # vX.Y.Z
      - run: nix flake check --no-update-lock-file
```

Reference the action by full commit SHA, as above. It has no outputs: it
succeeds, or fails with every problem of the lock in the job summary and as
annotations of the lock file. Warnings and notices of the end of life are listed
there too and do not fail it; past the end of life, only runs of the `schedule`
event fail, so keep a weekly scheduled run, as above. GitHub shows at most 10
annotations of each kind per step, so when there are more errors or warnings,
the tenth of that kind says how many more the summary has. It has no warn-only
mode. Its first step runs [action-shell-lib][action-shell-lib], the shell
library of its other steps, which fails the job on a runner that the action does
not support.

## Inputs

- `path` (default `flake.lock`): the lock file, relative to the workspace. Its
  real path must be a regular file inside the workspace.
- `allow-duplicates` (default empty): normalized sources that may be locked more
  than once, one per line, such as `github.com/nixos/nixpkgs` or
  `github.com/<owner>/<repo>?dir=<dir>`. A second nixpkgs for a tool that is
  broken on the stable branch ([FY-0026][fy-0026]) goes here.
- `pin-form` (default `true`): `false` switches the pin form rule off.
- `nixpkgs-eol` (default `true`): `false` switches the end of life rule off.
- `github-token` (default `github.token`): reads the releases of flakeyard
  repositories through the GraphQL API. It needs no permissions; it is
  validated, masked and given only to the step that looks up releases.

## Rules

The rules are those of [ADR-0001][adr-0001] and [ADR-0002][adr-0002]. Only the
end of life writes warnings and notices; the other rules report violations,
which fail the run. A flakeyard input is a node whose locked source is a
repository of the owner `flakeyard` on `github.com`, in any case.

- **Release**, always on: the `rev` of every flakeyard input is the commit of
  the tag of an immutable GitHub release `vX.Y.Z`, and its `ref`, when set, is
  `vX` of that major version or exactly that `vX.Y.Z`. A violation names the
  newest valid release of the major version and its commit. An input whose
  releases could not be looked up is reported apart, as "Could not verify", and
  fails the run as well. Releases are looked up once per repository, for at most
  50 repositories.
- **Duplicates**, always on: two distinct nodes with the same normalized source,
  also at the same `rev`, unless `allow-duplicates` lists it. Sources are taken
  from `locked` in the forms `github:`, `git+https`, `git+ssh`, `ssh://git@` and
  `https://github.com/<owner>/<repo>/archive/...`; host, owner and repository
  are compared in lower case without `.git` and a trailing `/`, and `dir` is
  part of the source. Other sources, such as GitLab, sourcehut, FlakeHub, other
  tarballs, `path` and indirect ones, are skipped. When exactly one input of the
  root has the source, the message has the `follows` lines that fix it.
- **Pin form**, on unless `pin-form` is `false`: every input of the root with a
  node of its own is written as
  `git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<40 hex digits>&shallow=1`,
  with `original.rev` equal to `locked.rev` and without `submodules`, `lfs` and
  `allRefs`; the `ref` of a flakeyard input is `vX`. Relative `path:` inputs
  inside the repository are exempt.
- **End of life of nixpkgs**, on unless `nixpkgs-eol` is `false`: for every
  input of the root whose normalized source is `github.com/nixos/nixpkgs`, the
  branch in the `ref` of its `original` is supported. `nixos-YY.05` and
  `nixos-YY.05-small` are supported until 31 December 20YY, `nixos-YY.11` and
  `nixos-YY.11-small` until 30 June of the year after, both to the end of that
  day in UTC. From 30 days before that day to its end the action warns. After
  it, the end of life is a violation in runs of the `schedule` event and a
  warning in runs of other events, so that it never blocks a pull request. Any
  other branch, or no `ref`, gets a notice that its end of life is not known.
  Every message says to switch to the next stable branch. The dates are part of
  the action: a change of the NixOS support policy is a release of it.

The action reads lock files of versions 5, 6 and 7, and fails on any other
version and on a missing lock file.

## Runner requirements

- A GitHub-hosted Linux runner on x86_64 or arm64, such as `ubuntu-24.04` or
  `ubuntu-24.04-arm`, on `github.com`. The first step of the action, the shell
  library [action-shell-lib][action-shell-lib], fails the job on any other
  runner, self-hosted ones included; GitHub Enterprise Server is rejected next.
  Both happen before anything is built.
- `nix` on `PATH` with the experimental features `nix-command` and `flakes`,
  such as from [action-setup-nix][action-setup-nix]. The action does not install
  Nix. Determinate Nix and Lix are not tested.
- `git` and `bash` of the runner.

The action builds `jq` and `gh` from its own [`flake.nix`](flake.nix), whose
only input is nixpkgs, with `--no-update-lock-file`, and runs them by their
store paths; it never writes `$GITHUB_PATH`. The first run on a runner fetches
that nixpkgs.

## Versioning

The public API is the inputs, the absence of outputs, the permissions of the
token, the runners and the rules of [ADR-0001][adr-0001] and
[ADR-0002][adr-0002]. Tightening any rule is a major release; before `v1.0.0`, a
`0.y` release ([FY-0024][fy-0024]). A new nixpkgs of the root flake, which
Renovate proposes once a month, is a patch release, since it changes the tools
that the action runs. See [VERSIONING][versioning].

## Development

The root [`flake.nix`](flake.nix) holds only the tools that the action runs,
`jq` and `gh`, from one pinned nixpkgs. The checks of the repository live in
[`dev/flake.nix`](dev/flake.nix), with its own lock, so that consumers fetch
none of them: `formatting` (nixfmt), `shell` (shellcheck and shfmt) and `unit`
([`tests/run.sh`](tests/run.sh)). The `unit` check fetches the shell library at
the commit that [`action.yml`](action.yml) pins and gives it to the tests as
`SHELL_LIB`, whose harness and stubs of `gh`, `date` and `sleep` they use.
Alone, `tests/run.sh` needs `SHELL_LIB` set to a checkout of the library and
mikefarah `yq`, such as from `nix shell nixpkgs#yq-go`. Run the checks with:

```sh
nix flake check --no-update-lock-file ./dev
```

The repository checks itself with [`test.yaml`](.github/workflows/test.yaml) on
x86_64 and arm64 runners: the job `tools` runs the action on the root
`flake.lock`, which consumers get, then builds every package of the root flake
and checks that each yields one store path, the job `action` runs the action on
a lock that passes and on one that breaks every rule, and
[workflow-check][workflow-check] builds the checks of `./dev`, checks the pull
request title, `renovate.json` and the release behind its preset tag, and
reports `check / required`. Before a pull request, run actionlint, zizmor,
prettier, markdownlint, typos and `reuse lint`.

[`maintenance.yaml`](.github/workflows/maintenance.yaml) checks every week that
the nixpkgs branch recorded in [`nixpkgs-eol`](nixpkgs-eol) is still supported
([FY-0026][fy-0026]). The file, its script and the job go once every repository
runs a release of workflow-check with the end of life rule
([ADR-0002][adr-0002]). Renovate updates the nixpkgs of the root flake once a
month as a `fix`, since a new release of the action ships the new tools.

[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard with
[workflow-scorecard][workflow-scorecard]. The repository releases itself with
[workflow-release][workflow-release] through
[`release.yaml`](.github/workflows/release.yaml), whose release pull requests
are checked by a dispatched run of `test.yaml`. The design follows
[FY-0034][fy-0034] and [FY-0030][fy-0030].

## Bootstrap

Following [FY-0022][fy-0022], some checks of this repository are not released
yet. Until they are:

- actionlint, zizmor, prettier, markdownlint, typos and REUSE run locally before
  every pull request; the atoms will provide them.
- The CI of this repository uses workflow-check 0.1.x, which does not run this
  action yet; the jobs `tools` and `action` run it on the root `flake.lock` and
  on its own fixtures instead. workflow-check adopts the action in its first
  pull request after the first release ([workflow-check ADR-0002][wc-adr-0002]).

## License

[MIT](LICENSE).

[action-setup-nix]: https://github.com/flakeyard/action-setup-nix
[action-shell-lib]: https://github.com/flakeyard/action-shell-lib
[adr-0001]: docs/adr/records/0001-check-flake-lock.md
[adr-0002]: docs/adr/records/0002-end-of-life-of-nixpkgs.md
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[wc-adr-0002]:
  https://github.com/flakeyard/workflow-check/blob/main/docs/adr/records/0002-check-flake-lock.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
[workflow-scorecard]: https://github.com/flakeyard/workflow-scorecard
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
[fy-0036]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0036-check-the-end-of-life-of-nixpkgs-in-flake-lock.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md

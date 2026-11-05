# action-flake-lock

A composite GitHub Action that checks `flake.lock` of flakeyard repositories and
of projects generated from flakeyard templates.

The action is not released yet; its usage is described here with the first
release.

## Development

The root [`flake.nix`](flake.nix) holds only the tools that the action runs,
`jq` and `gh`, from one pinned nixpkgs. The checks of the repository live in
[`dev/flake.nix`](dev/flake.nix), with its own lock, so that consumers fetch
none of them: `formatting` (nixfmt), `shell` (shellcheck and shfmt) and `unit`
([`tests/run.sh`](tests/run.sh)). Run them with:

```sh
nix flake check --no-update-lock-file ./dev
```

The repository checks itself with [`test.yaml`](.github/workflows/test.yaml):
the job `tools` builds every package of the root flake on x86_64 and arm64
runners, and [workflow-check][workflow-check] builds the checks of `./dev`,
checks the pull request title, `renovate.json` and the release behind its preset
tag, and reports `check / required`. Before a pull request, run actionlint,
zizmor, prettier, markdownlint, typos and `reuse lint`.

[`maintenance.yaml`](.github/workflows/maintenance.yaml) checks every week that
the nixpkgs branch recorded in [`nixpkgs-eol`](nixpkgs-eol) is still supported
([FY-0026][fy-0026]). Renovate updates the nixpkgs of the root flake once a
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

## License

[MIT](LICENSE).

[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
[workflow-scorecard]: https://github.com/flakeyard/workflow-scorecard
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md

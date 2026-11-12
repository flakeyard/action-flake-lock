---
id: ADR-0003
title: Substitute the tools from recorded store paths
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: [ADR-0001]
affects:
  [
    "action.yml",
    "tools.nix",
    "scripts/lib/tools.sh",
    "scripts/step/tools.sh",
    "dev/nix/tool-paths.nix",
    "dev/nix/checks/tools.nix",
    "dev/nix/apps/update-tools.nix",
    "tests/bin/nix",
    "tests/unit/step/tools.sh",
  ]
review_by:
---

## Context

[ADR-0001](0001-check-flake-lock.md) builds `jq` and `gh` in every run with
`nix build --no-update-lock-file "path:$GITHUB_ACTION_PATH#<package>"`. To
evaluate that installable, Nix first fetches the nixpkgs of the root flake. In
run 43042347040 of workflow-check, the step "Build the tools" took 10 to 12 s in
every flake job on every system: 7.8 to 9 s to download the NAR of the nixpkgs
source from cache.nixos.org, and about 2.3 s for the closures of `jq` and `gh`.
Every caller pays this in every job, although the tools change only with a
release of the action.

The store path of a package is fixed by the lock of the root flake: the same
`flake.lock` evaluates to the same `outPath` on every machine. cache.nixos.org
has `jq.bin` and `gh` of `nixos-26.05` for x86_64-linux and aarch64-linux,
signed by the key that Nix trusts by default. A store path given to `nix build`
is substituted from a trusted binary cache without any evaluation, and Nix
checks the signature of what it downloads.

On a developer host with an empty store (`--store` in a temporary directory) and
an empty `XDG_CACHE_HOME`, three runs of the build of ADR-0001 took 6.3 to 7.4
s, and three runs of the substitution below took 1.9 to 2.1 s.

`jq` is one of the tools, so the step cannot read JSON before it has them; Nix
itself can read a Nix file without nixpkgs.

## Decision

### Recorded paths

The file `tools.nix` at the root of the action records the store path of every
package of the root flake for every system of it, as an attribute set
`<system>.<package> = "<store path>"` without string context. It is generated
from the root flake by `nix run ./dev#update-tools` in the root of the
repository, which evaluates the packages with the nixpkgs that the root
`flake.lock` pins and formats the file with nixfmt.

A check `tools` of `dev/flake.nix` evaluates the same paths and fails when
`tools.nix` records any other path, lacks one or has one too many. Its message
lists the differences and says to run `nix run ./dev#update-tools` and commit
`tools.nix`. The check tests itself first: it must find a record in which the
path of `gh` replaces that of `jq` on x86_64-linux.

### The step

The step "Build the tools" reads the system of the job's Nix with
`nix config show system`, and for each tool:

```sh
nix eval --raw --file "$GITHUB_ACTION_PATH/tools.nix" "<system>.<package>"
nix build --no-link --print-out-paths "<store path>"
```

It fails when `tools.nix` records no path, or more than one line, for the
package on that system; when the path cannot be substituted, with a message that
the binary cache of nixpkgs must be a trusted substituter; and when `nix build`
prints anything but that path. It evaluates neither nixpkgs nor the flake of the
action. Tools still run by absolute path, and the action never writes
`$GITHUB_PATH`.

### Updates of nixpkgs

Renovate updates the nixpkgs of the root flake in a pull request that does not
regenerate `tools.nix`: the Mend-hosted app runs no commands. The check `tools`
fails that pull request until `tools.nix` is regenerated on its branch and
committed. The update stays a `fix` release.

### Changes to ADR-0001

This record amends [ADR-0001](0001-check-flake-lock.md); its other decisions and
constraints stand:

- "Tools" (decision): a step no longer builds a tool with
  `nix build ... "path:$GITHUB_ACTION_PATH#<package>"`; it substitutes the path
  that `tools.nix` records, as above. The root flake, its only input and its
  only outputs stay; it is the source of `tools.nix`, not of a run.
- "Tools and runners" (constraint): `jq` and `gh` come only from the store paths
  that `tools.nix` records for the packages of the root flake, which the check
  `tools` keeps equal to them.
- "Tools and runners" (constraint): "Every tool build MUST use
  `--no-update-lock-file` and MUST fail unless it prints exactly one path" is
  replaced by the constraints below; `--no-update-lock-file` still applies to
  every build of the flake itself, such as in the tests.
- "Runner requirements": the job's Nix must trust a binary cache that has the
  paths, cache.nixos.org by default. A Nix without it, which built the tools
  from source before, now fails the step.

## Constraints

- The action MUST take `jq` and `gh` only from the store paths that `tools.nix`
  records for the system of the job's Nix, and MUST NOT evaluate nixpkgs or its
  own flake at run time.
- The step MUST fail when `tools.nix` records no single path for a tool on that
  system, when the path cannot be substituted, and when `nix build` prints
  anything but that path.
- The step MUST NOT disable signature checks or add substituters or trusted
  keys.
- `tools.nix` MUST hold exactly the `outPath` of every package of the root flake
  for every system of it, evaluated with the nixpkgs of the root `flake.lock`;
  the check `tools` of `dev/flake.nix` MUST fail otherwise and MUST say how to
  regenerate the file.
- A change of the root `flake.nix` or `flake.lock` MUST regenerate `tools.nix`
  in the same pull request.
- The check `tools` MUST NOT build the tools: the paths carry no string context.

## Consequences

- (+) The step takes about 2 s instead of 10 to 12 s in every job of every
  caller: it no longer downloads the nixpkgs source.
- (+) The tools stay pinned to the lock of the root flake, and their contents
  are verified by the signature of the binary cache.
- (−) Every Renovate update of nixpkgs needs a commit of `tools.nix` on its
  branch before it can merge, and Renovate stops rebasing a branch with such a
  commit.
- (−) The action depends on the binary cache of nixpkgs: a path that the cache
  has not built or has dropped fails the step, where a build would fall back to
  building from source.
- (±) The check `tools` fetches the nixpkgs of the root lock when building the
  checks of `dev/flake.nix`; it is the same as that of the dev lock while both
  follow the same commit.

## Alternatives considered

- **Keep the build of the flake.** Simplest, but costs 8 to 9 s of downloading
  in every job of every caller.
- **Cache the nixpkgs source with actions/cache.** Saves part of the download,
  but needs a cache per caller, a cache key and write access, and still unpacks
  the source.
- **Record the paths in JSON.** Readable by tools other than Nix, but the step
  needs `jq` to read it before it has `jq`.
- **Substitute with a fallback to the build.** Never fails on a missing path,
  but hides a stale `tools.nix` behind a slow run instead of failing.
- **The `jq` and `gh` of the runner.** No download, but unpinned, which ADR-0001
  rejects.

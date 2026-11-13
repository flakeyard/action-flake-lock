# Changelog

## [0.3.0](https://github.com/flakeyard/action-flake-lock/compare/v0.2.3...v0.3.0) (2026-11-13)


### Features

* add the input newer-major and report newer major versions ([#54](https://github.com/flakeyard/action-flake-lock/issues/54)) ([5aa86f0](https://github.com/flakeyard/action-flake-lock/commit/5aa86f0320e68d5ffedc67edb57c514626b2c4d2))
* warn about a newer major version of flakeyard inputs ([#53](https://github.com/flakeyard/action-flake-lock/issues/53)) ([8200d05](https://github.com/flakeyard/action-flake-lock/commit/8200d05c1b7bf0bc19dbae368368ac8303b52770))


### Bug Fixes

* **deps:** update flakeyard/action-shell-lib action to v0.3.0 - abandoned ([#45](https://github.com/flakeyard/action-flake-lock/issues/45)) ([8e5d3dd](https://github.com/flakeyard/action-flake-lock/commit/8e5d3dd1a8a8379c02b9025d7f74072e946b3a76))
* **deps:** update flakeyard/action-shell-lib action to v0.3.1 ([#52](https://github.com/flakeyard/action-flake-lock/issues/52)) ([fa1c62f](https://github.com/flakeyard/action-flake-lock/commit/fa1c62f17bfcd952fe760af9c59b1c36a435a83b))

## [0.2.3](https://github.com/flakeyard/action-flake-lock/compare/v0.2.2...v0.2.3) (2026-11-12)


### Bug Fixes

* adopt job_tool of action-shell-lib v0.3.0 ([#46](https://github.com/flakeyard/action-flake-lock/issues/46)) ([b1fe30a](https://github.com/flakeyard/action-flake-lock/commit/b1fe30a4445f2dc8927c0010291efd585ec4aed0))
* **deps:** update flakeyard/action-shell-lib action to v0.2.0 ([#42](https://github.com/flakeyard/action-flake-lock/issues/42)) ([039dde6](https://github.com/flakeyard/action-flake-lock/commit/039dde6b00a151ff7900e3b009803542314217e9))


### Performance Improvements

* substitute the tools from the store paths in tools.nix ([#43](https://github.com/flakeyard/action-flake-lock/issues/43)) ([53a77d8](https://github.com/flakeyard/action-flake-lock/commit/53a77d8623779861b4864f29b7fb92599396af8e))

## [0.2.2](https://github.com/flakeyard/action-flake-lock/compare/v0.2.1...v0.2.2) (2026-11-11)


### Bug Fixes

* **deps:** update flakeyard/action-shell-lib action to v0.1.4 ([#36](https://github.com/flakeyard/action-flake-lock/issues/36)) ([64660a7](https://github.com/flakeyard/action-flake-lock/commit/64660a7c79a0fb11b1842c182950c73b3446e17f))

## [0.2.1](https://github.com/flakeyard/action-flake-lock/compare/v0.2.0...v0.2.1) (2026-11-11)


### Bug Fixes

* **deps:** update flakeyard/action-shell-lib action to v0.1.3 ([#28](https://github.com/flakeyard/action-flake-lock/issues/28)) ([874997c](https://github.com/flakeyard/action-flake-lock/commit/874997c1a122f548dfc9516d17135dc10de95d98))

## [0.2.0](https://github.com/flakeyard/action-flake-lock/compare/v0.1.0...v0.2.0) (2026-11-10)


### Features

* check the end of life of nixpkgs ([#21](https://github.com/flakeyard/action-flake-lock/issues/21)) ([e2c16b5](https://github.com/flakeyard/action-flake-lock/commit/e2c16b5631618301572f1e39ba3279b51dadb79b))
* run the steps with the shell library ([#18](https://github.com/flakeyard/action-flake-lock/issues/18)) ([fa18bee](https://github.com/flakeyard/action-flake-lock/commit/fa18bee684e325638f18cce5de0f7f98928a04cb))

## 0.1.0 (2026-11-05)


### Features

* add the action and its report ([#9](https://github.com/flakeyard/action-flake-lock/issues/9)) ([618068e](https://github.com/flakeyard/action-flake-lock/commit/618068e21c4b03d944ae58005e57ba940019c6ea))
* check duplicated sources and the pin form ([#7](https://github.com/flakeyard/action-flake-lock/issues/7)) ([66462b9](https://github.com/flakeyard/action-flake-lock/commit/66462b9ca6ac12c1a2e0fb940bd1365a2d62455c))
* check that flakeyard inputs are released ([#8](https://github.com/flakeyard/action-flake-lock/issues/8)) ([6ea1df1](https://github.com/flakeyard/action-flake-lock/commit/6ea1df159669abf08a2e9c8df23916313583bc39))
* check the runner and the inputs, and build the tools ([#5](https://github.com/flakeyard/action-flake-lock/issues/5)) ([4e676d1](https://github.com/flakeyard/action-flake-lock/commit/4e676d15e3473df5c06672fc66daf3e67c6b47e9))
* parse the lock file ([#6](https://github.com/flakeyard/action-flake-lock/issues/6)) ([b8be22f](https://github.com/flakeyard/action-flake-lock/commit/b8be22fdee56f5401afa677a7c7495c381563893))

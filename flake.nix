{
  description = "action-flake-lock: the tools that the action runs.";

  # The only input (ADR-0001); Renovate updates it once a month.
  inputs.nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=08d3a97586f6b6343b3b5e799980773629432610&shallow=1";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # One store path each: pkgs.jq also has man, doc and dev outputs.
      tools =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          jq = pkgs.jq.bin;
          inherit (pkgs) gh;
        };
    in
    {
      packages = nixpkgs.lib.genAttrs systems tools;
    };
}

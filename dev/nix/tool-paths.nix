# The store paths of the packages of the root flake, evaluated with the nixpkgs
# that its lock pins, for the check and the app of tools.nix. They are strings
# without context, so that nothing depends on building the tools.
{
  perSystem =
    { lib, ... }:
    let
      lock = lib.importJSON ../../flake.lock;
      source = builtins.fetchTree lock.nodes.${lock.nodes.root.inputs.nixpkgs}.locked;
      # nixpkgs called as a flake: its flake.nix has no inputs but itself.
      nixpkgs = source // (import "${source}/flake.nix").outputs { self = nixpkgs; };
      root = (import ../../flake.nix).outputs { inherit nixpkgs; };
      outPath = package: builtins.unsafeDiscardStringContext package.outPath;
    in
    {
      _module.args.toolPaths = lib.mapAttrs (_: lib.mapAttrs (_: outPath)) root.packages;
    };
}

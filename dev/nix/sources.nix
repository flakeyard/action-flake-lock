# The action, its scripts and tests, and the files the tests compare, as one
# source for the checks.
{
  perSystem =
    { pkgs, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        root = ../..;
        fileset = pkgs.lib.fileset.unions [
          ../../action.yml
          ../../scripts
          ../../tests
          ../../flake.lock
          ../../nixpkgs-eol
          ../flake.lock
        ];
      };
    };
}

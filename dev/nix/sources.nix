# The action, its workflows, scripts and tests, as one source for the checks.
{
  perSystem =
    { pkgs, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        root = ../..;
        fileset = pkgs.lib.fileset.unions [
          ../../action.yml
          ../../.github/workflows
          ../../scripts
          ../../tests
        ];
      };
    };
}

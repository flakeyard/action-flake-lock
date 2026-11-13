# The action, its workflows, scripts and tests, as one source for the checks.
{
  perSystem =
    { pkgs, root, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        inherit root;
        fileset = pkgs.lib.fileset.unions [
          (root + "/action.yml")
          (root + "/.github/workflows")
          (root + "/scripts")
          (root + "/tests")
        ];
      };
    };
}

# The app check-eol: weekly maintenance, not required (FY-0026).
{
  perSystem =
    { lib, pkgs, ... }:
    {
      apps.check-eol = {
        type = "app";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "check-eol";
            runtimeInputs = [ pkgs.coreutils ];
            text = builtins.readFile ../../../../scripts/check/eol.sh;
          }
        );
        meta.description = "Warn before the nixpkgs branch reaches its end of life";
      };
    };
}

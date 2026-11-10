# tests/run.sh passes: the unit tests of the scripts, with the stubs of
# tests/bin instead of nix and gh, and the shell library that action.yml pins.
{
  perSystem =
    {
      pkgs,
      sources,
      shellLib,
      ...
    }:
    {
      checks.unit =
        pkgs.runCommand "unit"
          {
            nativeBuildInputs = with pkgs; [
              bash
              coreutils
              gnugrep
              gnused
              jq
            ];
          }
          ''
            # The sandbox has no /usr/bin/env.
            cp -r ${sources}/. source
            cp -r ${shellLib}/. shell-lib
            chmod -R u+w source shell-lib
            patchShebangs source shell-lib
            SHELL_LIB=$PWD/shell-lib bash source/tests/run.sh
            touch $out
          '';
    };
}

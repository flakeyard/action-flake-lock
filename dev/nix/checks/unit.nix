# tests/run.sh passes: the unit tests of the scripts, with the stubs of
# tests/bin instead of nix and gh.
{
  perSystem =
    { pkgs, sources, ... }:
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
            chmod -R u+w source
            patchShebangs source
            bash source/tests/run.sh
            touch $out
          '';
    };
}

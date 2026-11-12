# tools.nix records the store path of every package of the root flake, which
# the action substitutes without evaluating nixpkgs (ADR-0003).
{
  perSystem =
    {
      pkgs,
      lib,
      toolPaths,
      ...
    }:
    let
      # entries TOOLS: "system.package = path" for every path of TOOLS.
      entries =
        tools:
        lib.concatLists (
          lib.mapAttrsToList (
            system: lib.mapAttrsToList (package: path: "${system}.${package} = ${path}")
          ) tools
        );
      # problem RECORDED: why RECORDED is not toolPaths, or null.
      problem =
        recorded:
        let
          stale = lib.subtractLists (entries toolPaths) (entries recorded);
          missing = lib.subtractLists (entries recorded) (entries toolPaths);
        in
        if stale == [ ] && missing == [ ] then
          null
        else
          lib.concatStringsSep "\n" (
            [ "tools.nix does not match the packages of the root flake." ]
            ++ map (entry: "  recorded:  ${entry}") stale
            ++ map (entry: "  evaluated: ${entry}") missing
            ++ [ "Run `nix run ./dev#update-tools` in the root of the repository and commit tools.nix." ]
          );
      recorded = import ../../../tools.nix;
      # The mutation that the check must catch: the path of gh as that of jq.
      mutated = lib.recursiveUpdate toolPaths { x86_64-linux.jq = toolPaths.x86_64-linux.gh; };
    in
    {
      checks.tools =
        assert lib.assertMsg (problem mutated != null) "the check of tools.nix misses a wrong path";
        if problem recorded == null then
          pkgs.runCommand "tools" { } "touch $out"
        else
          throw (problem recorded);
    };
}

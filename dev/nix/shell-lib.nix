# The shell library at the commit that action.yml pins, for the tests: the
# commit is read from action.yml, so the repository pins it once.
{
  perSystem =
    { ... }:
    let
      pin = builtins.match ".*uses: flakeyard/action-shell-lib@([0-9a-f]{40}) .*" (
        builtins.readFile ../../action.yml
      );
    in
    {
      _module.args.shellLib =
        if pin == null then
          throw "action.yml pins no commit of flakeyard/action-shell-lib"
        else
          builtins.fetchGit {
            url = "https://github.com/flakeyard/action-shell-lib";
            rev = builtins.head pin;
            shallow = true;
          };
    };
}

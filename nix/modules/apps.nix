{ self, inputs, ... }:
let
  helpers = import ../lib.nix { inherit self inputs; };
in
{
  perSystem =
    { pkgs, ... }:
    {
      # There is no binary to launch, so `nix run` runs the same analyze + test
      # the check does, without the sandbox restriction.
      apps.default = {
        type = "app";
        program = helpers.mkCheckScript { inherit pkgs; };
        meta.description = "Run dart analyze and dart test for every package";
      };
    };
}

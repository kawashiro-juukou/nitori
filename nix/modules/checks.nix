{ self, inputs, ... }:
let
  helpers = import ../lib.nix { inherit self inputs; };
  inherit (helpers) successMarker;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.default =
        pkgs.runCommand "nitori-check"
          {
            # Fixed output so `dart pub get` keeps network access in the sandbox:
            # a regular derivation here cannot reach pub.dev. Writing the marker
            # up front makes a failing analyze/test surface as a non-zero exit
            # instead of a confusing hash mismatch.
            outputHash = "sha256:${builtins.hashString "sha256" successMarker}";
            outputHashMode = "flat";
            buildInputs = [ pkgs.dart ];
          }
          ''
            echo "nitori: analyze + test passed" > $out
            ${helpers.mkCheckScript { inherit pkgs; sandboxed = true; }}/bin/nitori-check-sandboxed
          '';
    };
}

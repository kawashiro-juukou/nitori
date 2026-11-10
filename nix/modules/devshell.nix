{ lib, self, inputs, ... }:
let
  # The nix/ directory is outside the flake's `specialArgs`, so its helpers are
  # called by hand rather than through the module system.
  helpers = import ../lib.nix {
    inherit self inputs;
    inherit (inputs) nixpkgs;
  };
  inherit (helpers) packages;
in
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.dart
          pkgs.git
          pkgs.jq
          pkgs.nixfmt
        ];

        # dart pub talks https; the sandbox has no default CA bundle.
        env.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

        shellHook = ''
          echo "nitori devShell - dart $(dart --version 2>&1 | cut -d' ' -f4)"
          echo "packages: ${lib.concatStringsSep " " packages}"
          echo "try: nix fmt | nix run .#check | nix flake check"
        '';
      };
    };
}

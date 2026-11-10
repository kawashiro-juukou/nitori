# Helpers shared by the perSystem modules.
{
  self ? null,
  inputs,
  nixpkgs ? inputs.nixpkgs,
}:
let
  inherit (nixpkgs) lib;
in
rec {
  # Dart packages in this monorepo.
  packages = [
    "nitori"
    "nitori_client"
    "nitori_core"
    "nitori_message"
    "nitori_server"
  ];

  # The pub cache and generated build artefacts are excluded so they are not
  # copied into the build sandbox; .dart_tool alone is ~60MB here.
  # Based on the flake's own source path, not `../.`, because only the
  # git-tracked tree is copied into the store for a flake.
  src =
    if self == null then
      abort "nix/lib.nix: helpers need `self` to filter the repository source"
    else
      lib.cleanSourceWith {
        src = self.outPath;
        filter =
          name: type:
          let
            baseName = lib.baseNameOf name;
          in
          lib.cleanSourceFilter name type
          && baseName != ".dart_tool"
          && baseName != ".pub-cache"
          && baseName != "pubspec.lock";
      };

  # The mark a successful analyze+test run leaves behind.
  successMarker = "nitori: analyze + test passed\n";

  # Runner script for analyze + test. Shared by the sandbox check and `nix run`.
  #
  # `sandboxed` switches on the fixed-output derivation trick: normal builds in
  # this repository's Nix sandbox have no network, and `dart pub get` needs
  # pub.dev, so the check has to be a fixed-output derivation to keep access.
  mkCheckScript =
    {
      pkgs,
      sandboxed ? false,
    }:
    let
      body = ''
        set -euo pipefail
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

        mkdir -p "$PUB_CACHE"
        work=$(mktemp -d)
        cp -r ${src}/. "$work"
        cd "$work"

        for pkg in ${lib.concatStringsSep " " packages}; do
          echo "==> pkgs/$pkg: dart pub get"
          (cd "pkgs/$pkg" && dart pub get)
          echo "==> pkgs/$pkg: dart analyze --fatal-infos ."
          (cd "pkgs/$pkg" && dart analyze --fatal-infos .)
          echo "==> pkgs/$pkg: dart test"
          (cd "pkgs/$pkg" && dart test)
        done

        echo "${lib.replaceStrings [ "\n" ] [ "" ] successMarker}"
      '';
    in
    if sandboxed then
      pkgs.writeShellApplication {
        name = "nitori-check-sandboxed";
        runtimeInputs = [ pkgs.dart ];
        text = ''
          export HOME=/tmp
          export PUB_CACHE=/tmp/nitori-pub-cache
          ${body}
        '';
      }
    else
      pkgs.writeShellApplication {
        name = "nitori-check";
        runtimeInputs = [ pkgs.dart ];
        text = body;
      };
}

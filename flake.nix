{
  description = "Nitori - a Dart implementation of the Satori Protocol (monorepo)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # Lets `nix fmt` format both Dart and Nix files with one command.
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        ./nix/modules
      ];

      # The dart SDK is only built for these systems in nixpkgs
      # (see dart's meta.platforms); x86_64-darwin is not included.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = _: {
        treefmt = {
          projectRootFile = "flake.nix";
          flakeCheck = false;
          programs = {
            dart-format.enable = true;
            nixfmt.enable = true;
          };
        };
      };
    };
}

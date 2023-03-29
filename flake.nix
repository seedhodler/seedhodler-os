{
  description = "Secure OS for using seedhodler offline";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # nixos-19.09
    nixpkgs-iso.url = "nixpkgs/e6391b4389e10a52358bd94b3031238648818b0a";
    nixpkgs-iso.flake = false;

    seedhodler.url = "github:seedhodler/seedhodler/ci";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        ./nix/modules/flake-parts/all-modules.nix
      ];
    };
}

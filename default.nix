let
  nixpkgs = import ./nixpkgs-src.nix;
  configuration = ./configuration.nix;
  format-config = ./iso.nix;
  system = "x86_64-linux";
  final = import "${toString nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      #compression-config
      format-config
      configuration
    ];
  };
in
final.config.system.build.isoImage

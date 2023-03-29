{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    iso-eval = import "${inputs.nixpkgs-iso}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        (self + /nix/modules/nixos/configuration.nix)
        (self + /nix/modules/nixos/iso.nix)
      ];
      specialArgs = {
        inherit inputs;
      };
    };

    iso-image = iso-eval.config.system.build.isoImage;
    vm = iso-eval.config.system.build.vm;
  in {
    packages = {
      inherit
        iso-image
        vm
        ;
      inherit (inputs'.seedhodler.packages) seedhodler;
    };
  };
}

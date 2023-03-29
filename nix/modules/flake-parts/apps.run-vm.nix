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
    run-vm = pkgs.writeScript "run-vm.sh" ''
      ${pkgs.qemu}/bin/qemu-kvm -cpu max -m 4000 -smp 2 -cdrom ${self'.packages.iso-image}/iso/nixos.iso
    '';

    mkApp = program: {
      type = "app";
      program = toString program;
    };
  in {
    apps = lib.mapAttrs (_: mkApp) {
      inherit run-vm;
    };
  };
}

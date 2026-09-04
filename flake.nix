{
  description = "Seedhodler OS: an offline, amnesiac live system for running Seedhodler securely.";

  inputs = {
    # One pinned nixpkgs for the whole system (via flake.lock). Bump deliberately.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # The exact signed Seedhodler release, embedded by hash. This is the whole
      # point of the OS/app split: the HTML baked into the image is byte-for-byte
      # the audited, minisign-signed file published at the release below, so the
      # image can be verified against the app release (same SHA-256).
      # The offline build variant, which hides every print option (this OS has no
      # printing; blank forms are printed on a normal printer instead).
      appVersion = "v1.0.3";
      seedhodlerHtml = pkgs.fetchurl {
        url = "https://github.com/seedhodler/seedhodler/releases/download/${appVersion}/seedhodler-${appVersion}-offline.html";
        hash = "sha256-a6BVsBqa6ssjdxHjEBBh57lJ71hlDSbk6kJCfRg0Ds4=";
      };

      nixosSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit seedhodlerHtml appVersion; };
        modules = [
          # An amnesiac live system out of the box: store on squashfs, / on tmpfs,
          # nothing written to the internal disk. We only trim and lock it down.
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./modules/configuration.nix
        ];
      };
    in
    {
      nixosConfigurations.seedhodler-os = nixosSystem;

      packages.${system} = {
        default = nixosSystem.config.system.build.isoImage;
        iso = nixosSystem.config.system.build.isoImage;
        # The embedded app on its own, so its hash can be checked against the release.
        seedhodler-html = seedhodlerHtml;
      };

      # `nix run .#vm` boots the built ISO in a throwaway qemu VM for testing.
      # It needs a few GB of RAM: copytoram loads the whole image into RAM, and
      # Chromium wants headroom on top. virtio-gpu gives cage a KMS device.
      apps.${system}.vm = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "seedhodler-os-vm" ''
            exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
              -enable-kvm -m 6144 -smp 4 -vga virtio \
              -cdrom ${self.packages.${system}.iso}/iso/*.iso
          ''
        );
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}

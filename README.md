# Seedhodler OS

An offline, amnesiac live system whose only job is to run [Seedhodler](https://github.com/seedhodler/seedhodler)
securely: boot it on a spare machine with no network, generate or restore your
seed shares, print the blank forms, and shut down. Nothing is written to disk and
nothing can leave the machine.

> Status: rebuild in progress. This is a clean, modern NixOS rebuild of the old
> 2023 image. It has not been built end to end yet; expect a few iterations to
> get a first bootable image.

## What it is

- **NixOS live ISO**, declaratively defined and pinned (`flake.lock`), so the
  image can be reproduced and audited from source.
- **The exact signed app, embedded by hash.** The Seedhodler HTML baked into the
  image is byte-for-byte the minisign-signed release
  (`seedhodler-vX.Y.Z.html`); the version and hash live in `flake.nix`. You can
  verify the embedded file against the app release:
  `nix build .#seedhodler-html && sha256sum result`.
- **Amnesiac.** Runs from RAM (squashfs store, tmpfs root, `copytoram`); a reboot
  erases everything.
- **Air-gapped.** No networking is brought up at all (no NetworkManager, no
  Wi-Fi, no DHCP); only loopback exists, for the local app server.
- **Does not touch your disks.** No auto-mounting of internal drives.
- **Minimal.** No desktop: a single fullscreen browser (Chromium under the `cage`
  Wayland kiosk) pointed at the app on `http://127.0.0.1`. Unprivileged user, no
  sudo, no SSH.
- **Prints offline.** CUPS with generic drivers, for a USB printer.

## Build

Needs [Nix](https://nixos.org/download) with flakes enabled.

```bash
nix build .#iso
# the image lands at ./result/iso/seedhodler-os-<version>.iso
```

## Test in a VM

```bash
nix run .#vm
```

## Write to a USB stick

```bash
sudo dd if=./result/iso/seedhodler-os-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
# replace /dev/sdX with your USB device. This erases the stick.
```

Then boot the target machine from the USB stick (disable Secure Boot if needed),
with no network connected.

## Verify the embedded app matches the release

```bash
nix build .#seedhodler-html
sha256sum result
# must equal the SHA-256 published in the app release's SHA256SUMS.txt
```

## Updating to a new app release

Bump `appVersion` and the `hash` in `flake.nix` to the new signed release, then
rebuild. The hash is the SRI form of the release's SHA-256
(`nix hash to-sri --type sha256 <hex>`).

## Layout

```
seedhodler-os/
├── flake.nix                 inputs, the app-by-hash, and the ISO/vm outputs
├── modules/configuration.nix the system: kiosk, printing, air-gap, hardening
├── gfx/                      logos and boot artwork
└── grub2-installer/          GRUB boot theme (not wired in yet)
```

# Seedhodler OS

A small, offline, amnesiac live system with one job: run
[Seedhodler](https://github.com/seedhodler/seedhodler) safely on a spare machine
with no network. Boot it, generate or restore your seed shares, print the blank
forms, shut down. Nothing is written to disk, and nothing can leave the machine.

It is a clean NixOS build: declarative, pinned, and reproducible. The Seedhodler
app baked into the image is the exact, minisign-signed release, embedded by hash,
so the image can be audited against the published app.

## Status

Builds and boots straight to the app. A `nix build .#iso` produces a bootable
ISO, and it has been verified end to end in a VM: the machine comes up, serves
the embedded app on loopback, and opens it fullscreen in the kiosk browser.

Not yet exercised on real hardware: booting on physical machines (UEFI/BIOS,
varied GPUs) and printing to a real USB printer. Those are the next things to
try on a spare box.

## What it is

- **A NixOS live ISO**, defined declaratively and pinned with `flake.lock`, so
  the whole image can be reproduced and audited from source.
- **The exact signed app, embedded by hash.** The Seedhodler HTML in the image
  is byte-for-byte the minisign-signed release (`seedhodler-vX.Y.Z.html`); the
  version and its SHA-256 live in `flake.nix`. You can rebuild just the embedded
  file and check its hash against the app release (see below).
- **Amnesiac.** The root is a tmpfs and the store is read-only on the medium;
  nothing is written to the machine's disk, and a reboot erases everything. The
  default boot leaves the USB stick in, so it runs on low-RAM and older machines.
  The `(copytoram)` boot-menu entry instead loads the whole image into RAM so the
  stick can be pulled, at the cost of needing a couple of GB of RAM.
- **Air-gapped by construction.** No network is brought up at all: no
  NetworkManager, no Wi-Fi, no DHCP. Only loopback exists, for the local app
  server. This is stronger than a firewall, because there is no interface to
  send from.
- **Leaves your disks alone.** No auto-mounting of internal drives; the live
  system never touches them.
- **Minimal, single-purpose UI.** No desktop. One fullscreen Chromium under the
  `cage` Wayland kiosk, pointed at the app on `http://127.0.0.1`. Software
  rendering, so it does not depend on a GPU driver that varies by machine.
  Chrome's telemetry, component updates, and on-device ML are turned off (they
  assume a network and a GPU this box does not have).
- **Prints offline.** CUPS with generic drivers, for a locally attached USB
  printer. No network printing, no sharing.
- **Locked down.** An unprivileged user with no password, no `sudo`, no SSH.

## How a session goes

1. Flash the ISO to a USB stick and boot a spare machine from it, with no
   network connected.
2. The system comes up amnesiac and air-gapped, and opens Seedhodler fullscreen.
3. Generate a new seed or restore one from shares; print the blank forms and
   write your shares down.
4. Shut down (or just pull the power). Nothing was written anywhere.

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

This boots the built ISO in a throwaway qemu VM (KVM, virtio-gpu, a few GB of
RAM). Handy for a quick look without flashing a stick.

## Write to a USB stick

```bash
sudo dd if=./result/iso/seedhodler-os-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
# replace /dev/sdX with your USB device. This erases the stick.
```

Then boot the target machine from the stick (disable Secure Boot if needed),
with no network connected.

## Verify the embedded app matches the release

The image is meant to carry the audited, signed app unchanged. To check that:

```bash
nix build .#seedhodler-html
sha256sum result
# must equal the SHA-256 published in the app release's SHA256SUMS.txt
```

The app release itself is signed with minisign and carries a build provenance
attestation; verify those against the app repository's published key before
trusting a given release.

## Update to a new app release

Bump `appVersion` and its `hash` in `flake.nix` to the new signed release, then
rebuild. The `hash` is the SRI form of the release's published SHA-256:

```bash
nix hash to-sri --type sha256 <hex-from-SHA256SUMS>
```

## Repository layout

```
seedhodler-os/
├── flake.nix                 inputs, the app-by-hash, and the iso/vm outputs
├── flake.lock                pinned nixpkgs, for a reproducible build
├── modules/configuration.nix the system: kiosk, printing, air-gap, hardening
├── gfx/                      logos and boot artwork
└── grub2-installer/          GRUB boot theme (not wired in yet)
```

## License

See [LICENSE](LICENSE).

# Seedhodler OS

A small, offline, amnesiac live system with one job: run
[Seedhodler](https://github.com/seedhodler/seedhodler) safely on a spare machine
with no network. Boot it, generate or restore your seed shares, write them down,
shut down. Nothing is written to disk, and nothing can leave the machine.

It is a clean NixOS build: declarative, pinned, and reproducible. The Seedhodler
app baked into the image is the exact, minisign-signed release, embedded by hash,
so the image can be audited against the published app.

## Status

Released and working. `nix build .#iso` produces a bootable ISO, and signed
images are published on the
[releases page](https://github.com/seedhodler/seedhodler-os/releases). It has
been verified end to end: booting on real hardware (a Lenovo laptop over UEFI)
and in VMs (UEFI and BIOS), coming up air-gapped, serving the embedded app on
loopback, and opening it fullscreen in the kiosk browser.

## What it is

- **A NixOS live ISO**, defined declaratively and pinned with `flake.lock`, so
  the whole image can be reproduced and audited from source.
- **The exact signed app, embedded by hash.** The Seedhodler HTML in the image
  is byte-for-byte the minisign-signed **offline** release
  (`seedhodler-vX.Y.Z-offline.html`); the version and its SHA-256 live in
  `flake.nix`. You can rebuild just the embedded file and check its hash against
  the app release (see below).
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
  `sway` Wayland kiosk, pointed at the app on `http://127.0.0.1`. Software
  rendering, so it does not depend on a GPU driver that varies by machine.
  Chrome's telemetry, component updates, and on-device ML are turned off (they
  assume a network and a GPU this box does not have).
- **No printing, by design.** Offline printing to arbitrary USB printers is a
  driver lottery, and the blank forms carry no secret, so print them on a normal
  printer instead. The embedded app is the offline build: its print buttons open
  a short note pointing to seedhodler.io rather than a print dialog.
- **Locked down.** An unprivileged user with no password, no `sudo`, no SSH.

## How a session goes

1. Flash the ISO to a USB stick and boot a spare machine from it, with no
   network connected.
2. The system comes up amnesiac and air-gapped, and opens Seedhodler fullscreen.
3. Generate a new seed or restore one from shares, and write your shares down by
   hand. (Print blank forms beforehand on a normal printer if you want them.)
4. Shut down, or just pull the power. Nothing was written anywhere.

## Download a signed ISO

Prebuilt images are on the
[releases page](https://github.com/seedhodler/seedhodler-os/releases), each
checksummed and signed. Before you trust one:

```bash
# checksum
sha256sum -c SHA256SUMS.txt

# minisign signature (public key: minisign.pub in this repo)
minisign -Vm seedhodler-os-vX.Y.Z.iso -p minisign.pub

# GitHub build provenance
gh attestation verify seedhodler-os-vX.Y.Z.iso --repo seedhodler/seedhodler-os
```

Or reproduce the image yourself from source (see Build) and compare.

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
# must equal the SHA-256 of the -offline.html asset in the app release's
# SHA256SUMS.txt
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
├── modules/configuration.nix the system: kiosk, air-gap, hardening
├── gfx/logo.svg              logo used for the boot splash and GRUB theme
├── minisign.pub              public key for verifying released ISOs
└── .github/workflows/        signed ISO release CI (tag a version to publish)
```

## License

See [LICENSE](LICENSE).

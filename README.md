# Seedhodler OS - BETA
!!! This software is in beta and considered unstable! Use it at your own risk! We are not responsible for any damage/harm/loss resulting through using this software !!!

It is the corresponding image for https://github.com/seedhodler/seedhodler-beta
A corresponding image for the current up to date project https://github.com/seedhodler/seedhodler will be released in the future
## Build on Linux (and macOS?)

Building on macOS might be possible by activating cross compiling support in nix after installing it. I didn't test this so far since i don't own a mac. In case you have the chance, please test it and edit the readme.

### 1. Install the nix package manager on your system
Execute as normal user:
```bash
curl https://nixos.org/nix/install | sh
```
More information: https://nixos.org/nix/download.html

### 2. Build SeedhodlerOS iso image with nix:
```bash
nix-build
```
Find the image at `./result/iso/nix.iso`

## Build using Docker (MacOS / Windows + Docker Machine)
(Untested on Windows. If you get the chance to test, please extend readme)
### 1. Install Docker on your system
Follow the instructions on https://docs.docker.com/get-docker/ on how to install Docker on your system.

### 2. Build Seedhodler OS iso image:
```bash
docker run --rm -it \
    -v "$(pwd)/docker-result:/result" \
    -v "$(pwd):/project" \
    nixos/nix sh -c "
        nix-env -i git && 
        nix-build /project --out-link /iso-out &&
        cp /iso-out/iso/nixos.iso /result/nixos.iso"
```
Find the image at `./result/iso/nixos.iso` (outside the container)



## Test Seedhodler OS
### There are several possibilities how to test the iso image:
1. Boot the iso using a virtual machine on your computer.
2. Use dd or etcher to flash the image onto a usb drive, then boot your computer from the usb drive (Even though Seedhodler OS is designed to not touch any existing data on your computer, it's ALPHA, therefore do this at your own Risk! )

## Project Structure
```
seedhosler-os/
├--configuration.nix    OS configuration and applications
├--default.nix          Used by nix-build command to initialize build
├--iso.nix              Defines the output format (ISO image + bootloader config)
├--nixpkgs-src.nix      pinning of nixpkgs verison to allow reproducible building
├--test_in_vm.sh        script to build iso image and test in virtualbox. (requires setup)
├--grub2-installer/     Bootloader Theme
├--gfx/                 Contains Graphics and logos used inside the OS
```

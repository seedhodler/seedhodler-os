#!/usr/bin/env bash

### Builds an iso image for the current configuration and runs it in a virtualbox.
### For debugging purposes. Needs setup. First create a new empty VM called 'test-isos'


set -e
ISO=`nixos-generate --format-path iso.nix -c configuration.nix --cores 16 -I nixpkgs=/home/grmpf/synced/projects/github/nixpkgs | tail -n 1`

VBoxManage controlvm "test-isos" poweroff || true
echo "detaching old iso"
VBoxManage storageattach "test-isos" --storagectl IDE --port 0 --device 0 --medium "none" || true
echo "attaching new iso"
VBoxManage storageattach "test-isos" --storagectl IDE --port 0 --device 0 --type dvddrive --medium "$ISO"

VBoxManage startvm "test-isos" --type headless
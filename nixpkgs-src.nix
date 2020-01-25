with import <nixpkgs> {};
pkgs.fetchgit {
  name = "nixos-19.09";
  url = https://github.com/nixos/nixpkgs-channels/;
  # `git ls-remote https://github.com/nixos/nixpkgs-channels nixos-19.09`
  branchName = "nixos-19.09";
  rev = "e6391b4389e10a52358bd94b3031238648818b0a";
  sha256 = "07nkaihks0k60krghd900x8zhfrsxmvdchlf5fzqmhgmfw5x6krv";
}

# builtins.fetchTarball {
#   name = "nixos-19.09";
#   # Commit hash for nixos-19.09 
#   url = https://github.com/nixos/nixpkgs/archive/e6391b4389e10a52358bd94b3031238648818b0a.tar.gz;
#   # Hash obtained using `nix-prefetch-url --unpack <url>`
#   sha256 = "07nkaihks0k60krghd900x8zhfrsxmvdchlf5fzqmhgmfw5x6krv";
# }

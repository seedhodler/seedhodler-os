{ config, pkgs, lib, modulesPath, inputs, ... }:
with config;
let

  # standalone version of bip39
  bip39 = with pkgs; fetchurl {
    url = "https://github.com/iancoleman/bip39/releases/download/0.4.0/bip39-standalone.html";
    sha256 = "bd207d5bebb499dd57f79ae8c8c8b5da58d17cdd3168f6d4b8b8827a7ab00d86";
  };

  # chromium for hodlers
  hodlium = with pkgs; runCommand "hodlium" {
    buildInputs = [ chromium ];
      inherit bip39 chromium;
    } ''
    mkdir -p $out/bin
    cp $bip39 $out/bip39.html
    echo "$chromium/bin/chromium http://localhost:80 $out/bip39.html" > $out/bin/hodlium
    chmod +x $out/bin/hodlium
    mkdir -p $out/share/applications
    #cat $chromium/share/applications/chromium-browser.desktop | sed 's/Exec=chromium/Exec=hodlium/g' > $out/share/applications/hodlium.desktop
  '';

in
{
  system.nixos.label = "Seedhodler-OS_ALPHA";

  # use efficient zstd compression to decrease build time
  system.build.squashfsStore = pkgs.callPackage "${toString modulesPath}/../../nixos/lib/make-squashfs.nix" {
    storeContents = config.isoImage.storeContents;
    comp = "zstd -Xcompression-level 1";
  };

  # Bootloader Theme
  isoImage.splashImage = ../../../gfx/bloom-blossom-cleaning-dandelion-434163.png;
  isoImage.efiSplashImage = ../../../gfx/bloom-blossom-cleaning-dandelion-434163.png;
  isoImage.grubTheme = ../../../grub2-installer;

  # Applicaitons
  environment.systemPackages = with pkgs; [
    hodlium
    chromium  # add chromium for debugging puposes
  ];

  # Desktop environment
  services.xserver.enable = true;
  services.xserver.layout = "us";
  services.xserver.displayManager.sddm = {
    enable = true;
    autoLogin.enable = true;
    autoLogin.user = "hodler";
  };
  services.xserver.desktopManager.plasma5.enable = true;

  # Autostart Hodlium Browser
  systemd.services.hodlium = {
    script = ''
      sleep 1 && DISPLAY=:0 ${hodlium}/bin/hodlium
    '';
    serviceConfig = {
      User = "hodler";
    };
    wantedBy = [ "graphical.target" ];
    after = [ "graphical.target display-manager.target docker-seedhodler_container.service" ];
  };

  # Serve Seedhodler Web App
  services.nginx.enable = true;
  services.nginx.virtualHosts."localhost" = {
      root = inputs.seedhodler.packages.${pkgs.system}.seedhodler;
  };

  # Hodler user
  users.users.hodler = {
    isNormalUser = true;
    password = "hodl";
    extraGroups = [ "wheel" ];  # adds user to sudoers for debugging purposes
  };

  # Disable IPv6
  networking.enableIPv6 = false;
  boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = 1;

  # Disable all IPv4 traffic except localhost traffic
  networking.firewall.extraCommands = ''
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
  '';
}

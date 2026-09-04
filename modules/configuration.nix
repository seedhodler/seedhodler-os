{
  config,
  lib,
  pkgs,
  modulesPath,
  seedhodlerHtml,
  appVersion,
  ...
}:

let
  # The app is served from a directory (as index.html) so the browser gets a
  # clean http://127.0.0.1 origin: a normal secure context for clipboard and
  # printing, without file:// quirks.
  appRoot = pkgs.runCommand "seedhodler-www" { } ''
    mkdir -p $out
    cp ${seedhodlerHtml} $out/index.html
  '';
in
{
  system.stateVersion = "24.11";

  # -------------------------------------------------------------------------
  # Identity and boot medium
  # -------------------------------------------------------------------------
  networking.hostName = "seedhodler";
  isoImage.isoName = lib.mkForce "seedhodler-os-${appVersion}.iso";
  isoImage.volumeID = lib.mkForce "SEEDHODLER_OS";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  # Light, low-memory squashfs compression so the image assembles comfortably on
  # a small builder; the image is a bit larger but builds fast and does not OOM.
  isoImage.squashfsCompression = lib.mkForce "zstd -Xcompression-level 3";
  # Run entirely from RAM so the USB stick can be pulled after boot.
  boot.kernelParams = [ "copytoram" ];

  # -------------------------------------------------------------------------
  # Air-gap: bring up no network at all; only loopback exists.
  # Stronger than a firewall alone, because there is no interface to send from.
  # -------------------------------------------------------------------------
  networking.networkmanager.enable = false;
  networking.wireless.enable = false;
  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  networking.firewall.enable = true; # deny by default; nothing routes out regardless

  # -------------------------------------------------------------------------
  # Do not touch the machine's disks. The live system is amnesiac; the user's
  # existing drives and data must stay untouched.
  # -------------------------------------------------------------------------
  services.udisks2.enable = false; # no auto-mounting of internal drives

  # -------------------------------------------------------------------------
  # Hardening: unprivileged, no escalation, no remote access.
  # -------------------------------------------------------------------------
  security.sudo.enable = lib.mkForce false;
  # The installation-device profile enables sshd for remote installs; not here.
  services.openssh.enable = lib.mkForce false;
  users.mutableUsers = false;
  users.users.hodler = {
    isNormalUser = true;
    # No password: nothing to protect on an amnesiac offline box, and it avoids a
    # login prompt in front of the kiosk.
    hashedPassword = "";
  };

  # -------------------------------------------------------------------------
  # The app: a loopback-only static server, opened in a single fullscreen
  # browser (cage is a minimal Wayland kiosk; no desktop environment).
  # -------------------------------------------------------------------------
  systemd.services.seedhodler-www = {
    description = "Serve the Seedhodler app on 127.0.0.1";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${appRoot} --addr 127.0.0.1 --port 8080 --no-listing";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  services.cage = {
    enable = true;
    user = "hodler";
    # cage forces fullscreen, so we do not use chromium --kiosk (which would
    # suppress the print dialog the blank-forms flow needs).
    program = "${pkgs.chromium}/bin/chromium --ozone-platform=wayland --incognito --no-first-run --disable-sync http://127.0.0.1:8080/";
  };

  # -------------------------------------------------------------------------
  # Printing: a locally attached (USB) printer, offline. The blank-forms flow
  # needs this. No network printing, no sharing.
  # -------------------------------------------------------------------------
  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint ]; # generic drivers covering most inkjet/laser printers
    browsing = false;
    webInterface = false;
  };

  # -------------------------------------------------------------------------
  # Trim the closure.
  # -------------------------------------------------------------------------
  documentation.enable = false;
  documentation.nixos.enable = false;
  # No X11; cage runs on Wayland directly.
  services.xserver.enable = false;
}

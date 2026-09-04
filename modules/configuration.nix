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

  # The kiosk waits for the local server to accept connections before launching
  # the browser. Without this, a cold boot races: Chromium can start before
  # darkhttpd is listening and land on its connection-error page instead of the
  # app (only a manual reload recovers it).
  kiosk = pkgs.writeShellScript "seedhodler-kiosk" ''
    until (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null; do sleep 0.2; done
    exec ${pkgs.chromium}/bin/chromium \
      `# fullscreen without browser chrome. --start-fullscreen (not --kiosk):`  \
      `# --kiosk would suppress the print dialog the blank-forms flow needs.`   \
      --start-fullscreen                                                       \
      `# software rendering: no hardware GL to depend on across unknown boot`  \
      `# hardware or in a VM (a plain form needs none)`                        \
      --ozone-platform=wayland --disable-gpu                                   \
      `# disable Chrome's on-device ML / Optimization Guide: it probes for a`  \
      `# GPU that is not there and takes the page renderer down with it`       \
      `# ("Aw, Snap!"), and it wants the network this box does not have`       \
      --disable-features=OptimizationGuideOnDeviceModel,OptimizationHints,OptimizationGuideModelDownloading,Translate,MediaRouter \
      --disable-background-networking --disable-component-update              \
      --incognito --no-first-run --no-default-browser-check --disable-sync    \
      http://127.0.0.1:8080/
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
    # The kiosk wrapper (see `kiosk` above) waits for the server, then launches
    # Chromium fullscreen without its chrome. cage keeps it the only window.
    program = kiosk;
  };
  # Order the kiosk after the app server so darkhttpd is up first; the wrapper's
  # port-wait then closes the remaining race. The XCURSOR_* vars give cage
  # (wlroots draws the pointer) a clean modern cursor instead of the dated X11
  # core cursor the base image would otherwise use.
  systemd.services.cage-tty1 = {
    after = [ "seedhodler-www.service" ];
    wants = [ "seedhodler-www.service" ];
    environment = {
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
    };
  };
  # Cursor theme, found by cage via the system icon path.
  environment.systemPackages = [ pkgs.adwaita-icon-theme ];

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
  # Fonts. The installation-cd minimal profile disables fontconfig to slim the
  # image, which leaves no /etc/fonts at all: Chromium then finds no font, and
  # loading the app's embedded @font-face fonts trips a renderer NOTREACHED that
  # crashes the page ("Aw, Snap!"). Force fontconfig back on and ship real
  # fonts (DejaVu + Liberation cover sans/serif/mono).
  # -------------------------------------------------------------------------
  fonts.fontconfig.enable = lib.mkForce true;
  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
  ];

  # -------------------------------------------------------------------------
  # Trim the closure.
  # -------------------------------------------------------------------------
  documentation.enable = false;
  documentation.nixos.enable = false;
  # No X11; cage runs on Wayland directly.
  services.xserver.enable = false;
}

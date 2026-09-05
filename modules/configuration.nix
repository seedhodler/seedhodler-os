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

  # A quiet boot splash: the Seedhodler emblem on a clean light ground, in place
  # of the NixOS artwork. The bootloader draws the menu text over this.
  splash = pkgs.runCommand "seedhodler-splash.png" {
    nativeBuildInputs = [ pkgs.librsvg pkgs.imagemagick ];
  } ''
    rsvg-convert -w 480 ${../gfx/logo.svg} -o logo.png
    magick -size 800x600 xc:'#f6f7f9' logo.png -gravity center -geometry +0+20 -composite png32:$out
  '';

  # GRUB theme for the EFI menu. Without a theme GRUB draws a menu border out of
  # box-drawing glyphs its built-in font lacks, which shows as garbled tofu. A
  # theme renders the menu without that border (and carries its own font). Light
  # ground with the wordmark, to match the BIOS splash.
  grubThemeTxt = pkgs.writeText "theme.txt" ''
    title-text: ""
    desktop-image: "background.png"
    terminal-font: "DejaVu Regular"

    + image {
      file = "logo.png"
      top = 58%
      left = 50%-200
      width = 400
      height = 76
    }

    + boot_menu {
      left = 4%
      top = 7%
      width = 92%
      height = 42%
      item_font = "DejaVu Regular"
      item_color = "#3a3a3a"
      selected_item_color = "#4526a6"
      item_height = 28
      item_spacing = 3
    }

    + label {
      id = "__timeout__"
      top = 88%
      left = 0
      width = 100%
      align = "center"
      font = "DejaVu Regular"
      color = "#8a8a8a"
      text = "Booting in %d s"
    }
  '';
  grubTheme = pkgs.runCommand "seedhodler-grub-theme" {
    nativeBuildInputs = [ pkgs.librsvg pkgs.imagemagick ];
  } ''
    mkdir -p $out
    cp ${pkgs.nixos-grub2-theme}/dejavu.pf2 $out/dejavu.pf2
    # GRUB's PNG loader only accepts 8/16-bit truecolor, not palette/low-depth,
    # so force 8-bit RGB(A) on both images.
    magick -size 32x32 xc:'#f6f7f9' -depth 8 PNG24:$out/background.png
    rsvg-convert -w 400 ${../gfx/logo.svg} -o logo-raw.png
    magick logo-raw.png -depth 8 PNG32:$out/logo.png
    cp ${grubThemeTxt} $out/theme.txt
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

  # sway runs the kiosk instead of cage: unlike cage it can configure the
  # touchpad. tap-to-click is off by default in libinput and a bare compositor
  # never turns it on, so a laptop clickpad produced only motion and hold
  # gestures, never a click. This config enables it.
  swayConfig = pkgs.writeText "sway-kiosk.conf" ''
    # No desktop chrome: no borders, no gaps, no status bar.
    default_border none
    default_floating_border none
    gaps inner 0
    gaps outer 0
    bar {
      mode invisible
    }

    # The touchpad fix: tap-to-click, and clickfinger so a one-finger physical
    # press also left-clicks.
    input "type:touchpad" {
      tap enabled
      click_method clickfinger
      natural_scroll enabled
      dwt enabled
    }

    # A clean cursor theme for the whole seat.
    seat seat0 {
      xcursor_theme Adwaita 24
    }

    # Launch the app; the wrapper waits for the server and starts Chromium
    # fullscreen. Force any window borderless and fullscreen as a safety net.
    exec ${kiosk}
    for_window [app_id=".*"] fullscreen enable, border none
    for_window [class=".*"] fullscreen enable, border none
  '';
in
{
  system.stateVersion = "24.11";

  # -------------------------------------------------------------------------
  # Identity and boot medium
  # -------------------------------------------------------------------------
  networking.hostName = "seedhodler";

  # Boot-menu branding: this is an appliance, not the NixOS installer. The menu
  # label is built as "<distroName> <label><appendToMenuLabel>", so this reads
  # "Seedhodler OS v1.0.0" instead of "NixOS 24.11.<hash> Installer".
  system.nixos.distroName = "Seedhodler OS";
  system.nixos.label = lib.mkForce appVersion;
  isoImage.appendToMenuLabel = lib.mkForce "";
  # A short, visible menu so a user on old hardware can still pick a fallback.
  boot.loader.timeout = lib.mkForce 8;
  # Quiet boot splash with the project emblem, for both BIOS (isolinux) and EFI
  # (grub). grubTheme is forced off so the emblem shows as the grub background.
  isoImage.splashImage = splash; # BIOS (isolinux) background
  isoImage.grubTheme = grubTheme; # EFI (grub) menu theme

  isoImage.isoName = lib.mkForce "seedhodler-os-${appVersion}.iso";
  isoImage.volumeID = lib.mkForce "SEEDHODLER_OS";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  # Light, low-memory squashfs compression so the image assembles comfortably on
  # a small builder; the image is a bit larger but builds fast and does not OOM.
  isoImage.squashfsCompression = lib.mkForce "zstd -Xcompression-level 19";
  # No copytoram in the default boot: copying the whole image into RAM (2 GB+) is
  # exactly what fails on low-RAM/old machines. The default boots on weak hardware
  # with the stick left in; the "(copytoram)" boot-menu entry still runs fully
  # from RAM for anyone who wants to pull the stick. Amnesiac either way: root is
  # tmpfs, the store is read-only on the medium, nothing is written to the disk.
  boot.loader.grub.memtest86.enable = lib.mkForce false;

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

  # Autologin straight into the sway kiosk session as the unprivileged user.
  # sway execs the kiosk wrapper (which waits for the server, then launches
  # Chromium fullscreen). Using sway rather than cage so the touchpad can be
  # configured (see swayConfig above).
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.sway}/bin/sway --config ${swayConfig}";
      user = "hodler";
    };
  };

  # No printing. Offline printing to arbitrary USB printers is a driver lottery
  # (host-based "winprinters" need proprietary firmware uploads, there is no
  # printer-setup UI on a kiosk, and so on), and the blank forms carry no secret:
  # they are printed on a normal printer instead, and the embedded app is the
  # offline build with every print option hidden. So no CUPS here.

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
  # Trim the closure. The image is built on the installer profiles, which carry
  # a lot we do not need for a single-purpose offline kiosk.
  # -------------------------------------------------------------------------
  documentation.enable = false;
  documentation.nixos.enable = false;
  # No X11; sway runs on Wayland directly.
  services.xserver.enable = false;

  # A graphical session pulls in speech-dispatcher for accessibility by default,
  # which drags in ~380 MB of TTS voices (mbrola/flite/freepats). Not needed.
  services.speechd.enable = lib.mkForce false;

  # No audio at all: this is a seed tool. Drops the pipewire/pulse stack.
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;

  # The amnesiac live system never mounts the user's disks, so we only need vfat
  # (the EFI system partition). Drops cifs (samba ~80 MB), btrfs, ntfs, xfs, f2fs
  # and zfs tooling that the installer profile would otherwise include.
  boot.supportedFilesystems = lib.mkForce [ "vfat" ];

  # We never install or build from this live system, so drop the installer's
  # offline machinery: the bundled Nixpkgs channel (~190 MB) and the stdenv
  # toolchain (~300 MB of gcc/binutils/make) kept only for offline builds.
  system.installer.channel.enable = false;
  system.extraDependencies = lib.mkForce [ ];
  # The flake pins its Nixpkgs into /etc/nix/registry.json, which keeps a ~190 MB
  # copy of the Nixpkgs source in the image. A kiosk never runs nix, so drop it.
  nix.registry = lib.mkForce { };

  # Cursor theme, found by sway via the system icon path. (We do not mkForce the
  # whole systemPackages list to strip the installer's repair tools: that also
  # removes packages other modules add for the graphical session, e.g. dbus,
  # which greetd/sway need to start at all.)
  environment.systemPackages = [ pkgs.adwaita-icon-theme ];
}

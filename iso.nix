{ config, lib, pkgs, modulesPath, ... }:
with lib;
let 

    seedHodlerLabel = "SeedHodler OS";
    bootloaderTimeout = 10;
    targetArch = "x64";

    grubPkgs = if config.boot.loader.grub.forcei686 then pkgs.pkgsi686Linux else pkgs;

    menuBuilderGrub2 =
    defaults: options: lib.concatStrings
        (
        map
        (option: ''
            menuentry '${defaults.name} ${
            # Name appended to menuentry defaults to params if no specific name given.
            option.name or (if option ? params then "(${option.params})" else "")
            }' ${if option ? class then " --class ${option.class}" else ""} {
            linux ${defaults.image} \''${isoboot} ${defaults.params} ${
                option.params or ""
            }
            initrd ${defaults.initrd}
            }
        '')
        options
        )
    ;

    buildMenuAdditionalParamsGrub2 = config: additional:
    let
        finalCfg = {
        # name = "NixOS ${config.system.nixos.label}${config.isoImage.appendToMenuLabel}";
        name = "SeedHodler OS";
        params = "init=${config.system.build.toplevel}/init ${additional} ${toString config.boot.kernelParams}";
        image = "/boot/${config.system.boot.loader.kernelFile}";
        initrd = "/boot/initrd";
        };
    in
        menuBuilderGrub2
        finalCfg
        [
        { class = "installer"; }
        ]
    ;

    buildMenuGrub2 = config:
        buildMenuAdditionalParamsGrub2 config ""
    ;

    grubMenuCfg = ''
        #
        # Menu configuration
        #
        insmod gfxterm
        insmod png
        set gfxpayload=keep
        # Fonts can be loaded?  
        # (This font is assumed to always be provided as a fallback by NixOS)
        if loadfont (hd0)/EFI/boot/unicode.pf2; then
        # Use graphical term, it can be either with background image or a theme.
        # input is "console", while output is "gfxterm".
        # This enables "serial" input and output only when possible.
        # Otherwise the failure mode is to not even enable gfxterm.
        if test "\$with_serial" == "yes"; then
            terminal_output gfxterm serial
            terminal_input  console serial
        else
            terminal_output gfxterm
            terminal_input  console
        fi
        else
        # Sets colors for the non-graphical term.
        set menu_color_normal=cyan/blue
        set menu_color_highlight=white/blue
        fi
        ${ # When there is a theme configured, use it, otherwise use the background image.
        if config.isoImage.grubTheme != null then ''
        # Sets theme.
        set theme=(hd0)/EFI/boot/grub-theme/theme.txt
        # Load theme fonts
        $(find ${config.isoImage.grubTheme} -iname '*.pf2' -printf "loadfont (hd0)/EFI/boot/grub-theme/%P\n")
        '' else ''
        if background_image (hd0)/EFI/boot/efi-background.png; then
            # Black background means transparent background when there
            # is a background image set... This seems undocumented :(
            set color_normal=black/black
            set color_highlight=white/blue
        else
            # Falls back again to proper colors.
            set menu_color_normal=cyan/blue
            set menu_color_highlight=white/blue
        fi
        ''}
    '';

    efiDir = pkgs.runCommand "efi-directory" {} ''
        mkdir -p $out/EFI/boot/
        # ALWAYS required modules.
        MODULES="fat iso9660 part_gpt part_msdos \
                normal boot linux configfile loopback chain halt \
                efifwsetup efi_gop \
                ls search search_label search_fs_uuid search_fs_file \
                gfxmenu gfxterm gfxterm_background gfxterm_menu test all_video loadenv \
                exfat ext2 ntfs btrfs hfsplus udf \
                videoinfo png \
                echo serial \
                "
        echo "Building GRUB with modules:"
        for mod in $MODULES; do
        echo " - $mod"
        done
        # Modules that may or may not be available per-platform.
        echo "Adding additional modules:"
        for mod in efi_uga; do
        if [ -f ${grubPkgs.grub2_efi}/lib/grub/${grubPkgs.grub2_efi.grubTarget}/$mod.mod ]; then
            echo " - $mod"
            MODULES+=" $mod"
        fi
        done
        # Make our own efi program, we can't rely on "grub-install" since it seems to
        # probe for devices, even with --skip-fs-probe.
        ${grubPkgs.grub2_efi}/bin/grub-mkimage -o $out/EFI/boot/boot${targetArch}.efi -p /EFI/boot -O ${grubPkgs.grub2_efi.grubTarget} \
        $MODULES
        cp ${grubPkgs.grub2_efi}/share/grub/unicode.pf2 $out/EFI/boot/
        cat <<EOF > $out/EFI/boot/grub.cfg
        # If you want to use serial for "terminal_*" commands, you need to set one up:
        #   Example manual configuration:
        #    → serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
        # This uses the defaults, and makes the serial terminal available.
        set with_serial=no
        if serial; then set with_serial=yes ;fi
        export with_serial
        clear
        set timeout=${builtins.toString bootloaderTimeout}
        ${grubMenuCfg}
        # If the parameter iso_path is set, append the findiso parameter to the kernel
        # line. We need this to allow the nixos iso to be booted from grub directly.
        if [ \''${iso_path} ] ; then
        set isoboot="findiso=\''${iso_path}"
        fi
        #
        # Menu entries
        #
        ${buildMenuGrub2 config}
        EOF
    '';
    efiImg = pkgs.runCommand "efi-image_eltorito" { buildInputs = [ pkgs.mtools pkgs.libfaketime ]; }
        # Be careful about determinism: du --apparent-size,
        #   dates (cp -p, touch, mcopy -m, faketime for label), IDs (mkfs.vfat -i)
        ''
        mkdir ./contents && cd ./contents
        cp -rp "${efiDir}"/EFI .
        mkdir ./boot
        cp -p "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}" \
            "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}" ./boot/
        touch --date=@0 ./EFI ./boot
        usage_size=$(du -sb --apparent-size . | tr -cd '[:digit:]')
        # Make the image 110% as big as the files need to make up for FAT overhead
        image_size=$(( ($usage_size * 110) / 100 ))
        # Make the image fit blocks of 1M
        block_size=$((1024*1024))
        image_size=$(( ($image_size / $block_size + 1) * $block_size ))
        echo "Usage size: $usage_size"
        echo "Image size: $image_size"
        truncate --size=$image_size "$out"
        ${pkgs.libfaketime}/bin/faketime "2000-01-01 00:00:00" ${pkgs.dosfstools}/sbin/mkfs.vfat -i 12345678 -n EFIBOOT "$out"
        mcopy -psvm -i "$out" ./EFI ./boot ::
        # Verify the FAT partition.
        ${pkgs.dosfstools}/sbin/fsck.vfat -vn "$out"
        '';
    baseIsolinuxCfg = ''
        SERIAL 0 115200
        TIMEOUT ${builtins.toString bootloaderTimeout}
        UI vesamenu.c32
        MENU TITLE NixOS
        MENU BACKGROUND /isolinux/background.png
        MENU RESOLUTION 800 600
        MENU CLEAR
        MENU ROWS 6
        MENU CMDLINEROW -4
        MENU TIMEOUTROW -3
        MENU TABMSGROW  -2
        MENU HELPMSGROW -1
        MENU HELPMSGENDROW -1
        MENU MARGIN 0
        #                                FG:AARRGGBB  BG:AARRGGBB   shadow
        MENU COLOR BORDER       30;44      #00000000    #00000000   none
        MENU COLOR SCREEN       37;40      #FF000000    #00E2E8FF   none
        MENU COLOR TABMSG       31;40      #80000000    #00000000   none
        MENU COLOR TIMEOUT      1;37;40    #FF000000    #00000000   none
        MENU COLOR TIMEOUT_MSG  37;40      #FF000000    #00000000   none
        MENU COLOR CMDMARK      1;36;40    #FF000000    #00000000   none
        MENU COLOR CMDLINE      37;40      #FF000000    #00000000   none
        MENU COLOR TITLE        1;36;44    #00000000    #00000000   none
        MENU COLOR UNSEL        37;44      #FF000000    #00000000   none
        MENU COLOR SEL          7;37;40    #FFFFFFFF    #FF5277C3   std
        DEFAULT boot
        LABEL boot
        #MENU LABEL NixOS ${config.system.nixos.label}${config.isoImage.appendToMenuLabel}
        MENU LABEL Seedhodler Secure OS
        LINUX /boot/${config.system.boot.loader.kernelFile}
        APPEND init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
        INITRD /boot/${config.system.boot.loader.initrdFile}
    '';
    isolinuxCfg = concatStringsSep "\n"
    [ baseIsolinuxCfg ];
    canx86BiosBoot = pkgs.stdenv.isi686 || pkgs.stdenv.isx86_64;
in
{
  imports = [
    "${toString modulesPath}/installer/cd-dvd/iso-image.nix"
  ];

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  isoImage.contents =
  [
    { source = config.boot.kernelPackages.kernel + "/" + config.system.boot.loader.kernelFile;
      target = "/boot/" + config.system.boot.loader.kernelFile;
    }
    { source = config.system.build.initialRamdisk + "/" + config.system.boot.loader.initrdFile;
      target = "/boot/" + config.system.boot.loader.initrdFile;
    }
    { source = config.system.build.squashfsStore;
      target = "/nix-store.squashfs";
    }
    { source = config.isoImage.efiSplashImage;
      target = "/EFI/boot/efi-background.png";
    }
    { source = config.isoImage.splashImage;
      target = "/isolinux/background.png";
    }
    { source = pkgs.writeText "version" config.system.nixos.label;
      target = "/version.txt";
    }
  ] ++ optionals canx86BiosBoot [
    { source = pkgs.substituteAll  {
        name = "isolinux.cfg";
        src = pkgs.writeText "isolinux.cfg-in" isolinuxCfg;
        bootRoot = "/boot";
      };
      target = "/isolinux/isolinux.cfg";
    }
    { source = "${pkgs.syslinux}/share/syslinux";
      target = "/isolinux";
    }
  ] ++ optionals config.isoImage.makeEfiBootable [
    { source = efiImg;
      target = "/boot/efi.img";
    }
    { source = "${efiDir}/EFI";
      target = "/EFI";
    }
    { source = pkgs.writeText "loopback.cfg" "source /EFI/boot/grub.cfg";
      target = "/boot/grub/loopback.cfg";
    }
  ] ++ optionals (config.isoImage.grubTheme != null) [
    { source = config.isoImage.grubTheme;
      target = "/EFI/boot/grub-theme";
    }
  ];
}

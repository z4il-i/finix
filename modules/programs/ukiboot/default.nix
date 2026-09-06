{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.programs.ukiboot;

  archInfo =
    {
      x86_64-linux = {
        bootFileName = "BOOTX64.EFI";
        kernelOutput = "bzImage";
      };
      i686-linux = {
        bootFileName = "BOOTIA32.EFI";
        kernelOutput = "bzImage";
      };
      aarch64-linux = {
        bootFileName = "BOOTAA64.EFI";
        kernelOutput = "Image";
      };
      riscv64-linux = {
        bootFileName = "BOOTRISCV64.EFI";
        kernelOutput = "Image";
      };
    }
    .${pkgs.stdenv.hostPlatform.system} or (throw "programs.ukiboot: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  uncompressedInitrd = pkgs.makeInitrdNG {
    name = "ukiboot-initrd";
    inherit (config.boot.initrd) contents prepend;
    compressor = _: lib.getExe' config.programs.coreutils.package "cat";
    compressorArgs = [ ];
  };

  kconfigKernel = config.boot.kernelPackages.kernel.override {
    structuredExtraConfig = with lib.kernel; {
      CMDLINE_BOOL = yes;
      CMDLINE = freeform (toString config.boot.kernelParams);
      CMDLINE_OVERRIDE = yes;
      INITRAMFS_SOURCE = freeform "${uncompressedInitrd}";
      KERNEL_XZ = yes;
      RD_XZ = yes;
    };
  };

  ukibootInstallHook = pkgs.writeScript "ukiboot-install" ''
    #!${config.environment.binsh}
    set -eu

    ESP_BOOT_DIR="${cfg.efiMountPoint}/EFI/BOOT"
    ${lib.getExe' config.programs.coreutils.package "mkdir"} -p "$ESP_BOOT_DIR"

    UKI_TMP=$(${lib.getExe' config.programs.coreutils.package "mktemp"} -p "$ESP_BOOT_DIR" .uki-XXXXXX)
    trap '${lib.getExe' config.programs.coreutils.package "rm"} -f "$UKI_TMP"' EXIT HUP INT TERM

    ${lib.getExe' config.programs.coreutils.package "cp"} -f "${kconfigKernel}/${archInfo.kernelOutput}" "$UKI_TMP"

    if [ "${lib.boolToString cfg.secureBoot.enable}" = "true" ] && [ -d ${cfg.secureBoot.keyLocation} ]; then
      echo "==> sbctl: signing kernel"
      ${lib.getExe' cfg.secureBoot.sbctl "sbctl"} sign "$UKI_TMP" || \
        echo "WARNING: sbctl signing failed, but continuing (Secure Boot may not work)"
    fi

    ${lib.getExe' config.programs.coreutils.package "mv"} -f "$UKI_TMP" "$ESP_BOOT_DIR/${cfg.bootFileName}"
    trap - EXIT HUP INT TERM
  '';
in
{
  options.programs.ukiboot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable ukiboot or not
        '';
      };

    efiMountPoint = lib.mkOption {
      type = lib.types.str;
      default = config.boot.loader.efi.efiSysMountPoint;
      description = ''
        Where the EFI System Partition is mounted
      '';
    };

    bootFileName = lib.mkOption {
      type = lib.types.str;
      default = archInfo.bootFileName;
    };

    secureBoot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          ukiboot secure boot
        '';
      };
      keyLocation = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sbctl/keys";
        description = ''
          Location of sbctl keys
        '';
      };
      sbctl = lib.mkOption {
        type = lib.types.package;
        default = pkgs.sbctl;
        description = ''
          Package to use for secure boot signing
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.script = {
      enable = true;
      installHook = ukibootInstallHook;
    };
  };
}

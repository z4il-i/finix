{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.xdg.filePicker;
in
{
  options.xdg.filePicker = {
    enable = lib.mkEnableOption "desktop file picker integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xdg-desktop-portal-termfilechooser;
      defaultText = lib.literalExpression "pkgs.cosmic-files";
      description = "Package providing the file picker and file manager.";
    };

    desktopFile = lib.mkOption {
      type = lib.types.str;
      default = "sff.desktop";
      description = "Desktop file to use as the default file manager.";
    };

    portals = lib.mkOption {
      type = with lib.types; listOf package;
      default = builtins.attrValues {
        inherit (pkgs)
          xdg-desktop-portal-gnome
          ;
      };
      defaultText = lib.literalExpression ''
        builtins.attrValues {
          inherit (pkgs) xdg-desktop-portal-gnome;
        }
      '';
      description = "Portal backend packages to install alongside xdg-desktop-portal.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];

    xdg = {
      mime = {
        enable = lib.mkDefault true;
        defaultApplications."inode/directory" = lib.mkDefault cfg.desktopFile;
      };

      portal = {
        enable = lib.mkDefault true;
        portals = cfg.portals;
      };
    };
  };
}

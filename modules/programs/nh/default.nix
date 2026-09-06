{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nh;
in
{
  options.programs.nh = {
    enable = lib.mkEnableOption "nh, yet another Nix CLI helper";

    package = lib.mkPackageOption pkgs "nh" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf (lib.types.nullOr (lib.types.oneOf [
          lib.types.str
          lib.types.int
          lib.types.bool
          lib.types.path
        ]));

        options = {
          NH_FLAKE = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''                
              The string that will be used for the `NH_FLAKE` environment variable.

              `NH_FLAKE` is used by nh as the default flake for performing actions, such as
              `nh os switch`. This behaviour can be overriden per-command with environment
              variables that will take priority.

              - `NH_OS_FLAKE`: will take priority for `nh os` commands.
              - `NH_HOME_FLAKE`: will take priority for `nh home` commands.
              - `NH_DARWIN_FLAKE`: will take priority for `nh darwin` commands.

              The formerly valid `FLAKE` is now deprecated by nh, and will cause hard errors
              in future releases if `NH_FLAKE` is not set.

              `NH_FLAKE` can point to either a folder containing a flake, or to an outside repository containing the flake.
            '';
          };
          NH_FILE = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''                
              The string that will be used for the `NH_FILE` environment variable.

              `NH_FILE` is used by nh as the default configuration file for performing actions, such as
              `nh os switch`. This behaviour can be overriden per-command with environment variables
              that will take priority
            '';
          };
          NH_ATTRP = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''                
              The string that will be used for the `NH_ATTRP` environment variable.

              `NH_ATTRP` is used by nh as the default attribute for performing actions, such as
              `nh os switch`. This behaviour can be overriden per-command with environment variables
              that will take priority
            '';
          };
        };
      };
      default = { };
      description = "Settings passed to nh as environment variables.";
    };
  };
  config = {
    assertions = [
      {
        assertion = (cfg.settings.NH_FLAKE != null) -> !(lib.hasSuffix ".nix" cfg.flake);
        message = "nh.flake must be a directory, or valid repository, not a nix file.";
      }
      {
        assertion = !(cfg.settings.NH_FLAKE != null && cfg.settings.NH_FILE != null);
        message = "nh.file and nh.flake can not be set at the same time, they are opposite components";
      }
    ];

    environment = lib.mkIf cfg.enable {
      systemPackages = [ cfg.package ];
      variables =
      lib.mapAttrs
        (_: v: if builtins.isBool v then (if v then "1" else "0") else toString v)
        (lib.filterAttrs (_: v: v != null) cfg.settings);
    };
  };
}

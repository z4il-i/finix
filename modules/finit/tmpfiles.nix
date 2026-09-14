{
  config,
  lib,
  ...
}:
{
  options.finit.tmpfiles = {
    rules = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "d /tmp 1777 root root 10d" ];
      description = ''
        Rules for creation, deletion and cleaning of volatile and temporary files
        automatically. See {manpage}`tmpfiles.d(5)` for the exact format.
      '';
    };
    clean = {
      enable = lib.mkEnableOption "Whether to enable automatic tmpfile cleaning which relies on `providers.scheduler.backend` to be set`";
      interval = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "daily";
        description = ''
          How often cleanup is performed. Passed to `providers.scheduler`
        '';
      };
    };
  };

  config = {
    environment.etc."tmpfiles.d/finix.conf".text = ''
      # This file is created automatically and should not be modified.
      # Please change the option ‘finit.tmpfiles.rules’ instead.

      ${lib.concatStringsSep "\n" config.finit.tmpfiles.rules}
    '';

    environment.etc."finit.d/tmpfiles-setup.conf".text = lib.mkAfter ''

      # force a restart on configuration change
      # ${config.environment.etc."tmpfiles.d/finix.conf".source}
    '';

    finit.tasks.tmpfiles-setup.command = "${config.finit.package}/libexec/finit/tmpfiles --create";

    providers.scheduler.tasks.tmpfiles-clean = lib.mkIf config.finit.tmpfiles.clean.enable {
      interval = config.finit.tmpfiles.clean.interval;
      command = "${config.finit.package}/libexec/finit/tmpfiles --clean";
    };
  };
  # needed for finit tmpfiles Z implementation: pkgs.policycoreutils
  # TODO: make this an optional dependency, fixup Z behaviour in general
}

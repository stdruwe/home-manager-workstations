{
  lib,
  pkgs,
  profileName,
  ...
}:

let
  userName = builtins.getEnv "USER";
  homeDirectory = builtins.getEnv "HOME";
  absotui = pkgs.callPackage ../packages/absotui.nix { };
in
{
  assertions = [
    {
      assertion = userName != "";
      message = "Home Manager requires USER; evaluate the flake with --impure.";
    }
    {
      assertion = homeDirectory != "" && lib.hasPrefix "/" homeDirectory;
      message = "Home Manager requires an absolute HOME; evaluate the flake with --impure.";
    }
  ];

  home.username = userName;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Use the same GTK interface font for Zen Browser, Firefox, Thunderbird and
  # other GTK applications. The font files are installed system-wide by the
  # NixOS font module and are not packaged a second time here.
  gtk = {
    enable = true;
    font = {
      name = "SF Pro";
      size = 10;
    };
  };

  programs.git = {
    enable = true;
    settings.include.path = "${homeDirectory}/.config/git/user.inc";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    # Keep normal GitHub repository URLs while routing SSH through GitHub's
    # documented HTTPS port. This avoids unreliable connections to port 22 on
    # networks where SSH is filtered or degraded.
    settings."github.com" = {
      HostName = "ssh.github.com";
      Port = 443;
      User = "git";
    };
  };

  xdg.desktopEntries.absotui = {
    name = "Absotui";
    genericName = "Audiobookshelf client";
    exec = "${pkgs.kitty}/bin/kitty --class absotui --title Absotui ${absotui}/bin/absotui";
    icon = "absotui";
    categories = [
      "AudioVideo"
      "Audio"
    ];
    terminal = false;
  };

  programs.bash = {
    enable = true;

    # A plain ~/.config/home-manager flake reference is auto-detected by Nix
    # as git+file when the directory is a Git checkout. That excludes the
    # ignored machine-local flake.lock. Use an explicit path: flake and the
    # hardware profile by default for every interactive Home Manager command.
    # An explicitly supplied --flake still takes precedence.
    initExtra = ''
      home-manager() {
        local hm_arg

        for hm_arg in "$@"; do
          if [[ "$hm_arg" == "--flake" ]]; then
            command home-manager --impure "$@"
            return
          fi
        done

        command home-manager \
          --impure \
          --flake "path:$HOME/.config/home-manager#${profileName}" \
          "$@"
      }

      # NixOS updates are handled by the guarded pre-command from the NixOS
      # configuration. Keep Topgrade's built-in system step disabled even if
      # configuration merging would otherwise re-enable it.
      topgrade() {
        command topgrade --disable system "$@"
      }
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = false;
  };

  # Zen Browser is the default browser on all Home Manager profiles. The
  # browser itself is installed system-wide by the NixOS repository. Set only
  # the targeted associations with xdg-mime instead of letting xdg.mimeApps
  # manage the complete mimeapps.list file.
  home.activation.ensureZenDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH=${pkgs.qt6.qtbase}/bin:$PATH

    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop text/html
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/xhtml+xml
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop x-scheme-handler/http
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop x-scheme-handler/https
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop x-scheme-handler/chrome
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/x-extension-htm
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/x-extension-html
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/x-extension-shtml
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/x-extension-xhtml
    ${pkgs.xdg-utils}/bin/xdg-mime default zen-beta.desktop application/x-extension-xht
  '';

  home.sessionVariables.BROWSER = "zen-beta";

  home.packages = [
    absotui
    pkgs.playerctl
  ];
}

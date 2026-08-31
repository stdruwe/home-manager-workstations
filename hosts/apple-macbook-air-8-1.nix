{ config, ... }:

let
  cosmicFont = family: ''
    (
        family: "${family}",
        weight: Normal,
        stretch: Normal,
        style: Normal,
    )
  '';
in
{
  imports = [
    ../modules/common.nix
  ];

  # Bitwarden is the SSH agent on this host. The NixOS profile disables the
  # competing GCR SSH agent, while OpenSSH pins the Bitwarden socket explicitly
  # so Git/SSH remain independent of the desktop session.
  programs.ssh.settings."*".IdentityAgent = "~/.bitwarden-ssh-agent.sock";

  home.sessionVariables.SSH_AUTH_SOCK =
    "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";

  # COSMIC exposes native toolkit settings for interface and monospace fonts,
  # but no separate serif-font setting. Keep SF Pro for interface text and
  # SF Mono for fixed-width text; generic serif requests resolve system-wide
  # through NixOS Fontconfig to New York at Medium weight.
  xdg.configFile."cosmic/com.system76.CosmicTk/v1/interface_font".text =
    cosmicFont "SF Pro";

  xdg.configFile."cosmic/com.system76.CosmicTk/v1/monospace_font".text =
    cosmicFont "SF Mono";
}

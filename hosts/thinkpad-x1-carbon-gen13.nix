{
  lib,
  pkgs,
  ...
}:

let
  kscreenDoctor = "/run/current-system/sw/bin/kscreen-doctor";
  kwriteconfig6 = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  setRefresh60 = pkgs.writeShellScript "thinkpad-refresh-60" ''
    exec ${kscreenDoctor} output.eDP-1.mode.2880x1800@60
  '';

  setRefresh120 = pkgs.writeShellScript "thinkpad-refresh-120" ''
    exec ${kscreenDoctor} output.eDP-1.mode.2880x1800@120
  '';
in
{
  imports = [
    ../modules/common.nix
    ../modules/desktops/plasma.nix
    ../modules/hermes.nix
  ];

  # When switching between AC and battery power, PowerDevil adjusts both the
  # display refresh rate and the power-profiles-daemon profile:
  # AC = 120 Hz + Performance, battery = 60 Hz + Balanced.
  # The existing Adaptive Sync setting (VRR Automatic) remains untouched.
  # Deliberately use kscreen-doctor from the running NixOS system so the client
  # and KWin/Plasma use the same libkscreen version.
  home.activation.configureThinkPadPowerState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config"

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group AC \
      --group RunScript \
      --key ProfileLoadCommand \
      "${setRefresh120}"

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group AC \
      --group Performance \
      --key PowerProfile \
      performance

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group Battery \
      --group RunScript \
      --key ProfileLoadCommand \
      "${setRefresh60}"

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group Battery \
      --group Performance \
      --key PowerProfile \
      balanced

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group LowBattery \
      --group RunScript \
      --key ProfileLoadCommand \
      "${setRefresh60}"

    ${kwriteconfig6} \
      --file "$HOME/.config/powerdevilrc" \
      --group LowBattery \
      --group Performance \
      --key PowerProfile \
      balanced
  '';
}

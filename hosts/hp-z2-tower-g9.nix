{ lib, pkgs, ... }:

let
  kwriteconfig6 = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  panelScript = pkgs.writeText "hp-z2-panels.js" ''
    (function () {
      const POWER_ITEM = "org.kde.plasma.battery";
      const PANEL_HEIGHT = 48;

      function appendCsv(value, item) {
        const parts = String(value || "")
          .split(",")
          .filter(function (entry) { return entry.length > 0; });
        if (parts.indexOf(item) < 0) {
          parts.push(item);
        }
        return parts.join(",");
      }

      function removeCsv(value, item) {
        return String(value || "")
          .split(",")
          .filter(function (entry) { return entry.length > 0 && entry !== item; })
          .join(",");
      }

      function configurePowerItem(tray) {
        tray.currentConfigGroup = ["General"];
        tray.writeConfig("extraItems", appendCsv(tray.readConfig("extraItems"), POWER_ITEM));
        tray.writeConfig("shownItems", appendCsv(tray.readConfig("shownItems"), POWER_ITEM));
        tray.writeConfig("hiddenItems", removeCsv(tray.readConfig("hiddenItems"), POWER_ITEM));
        tray.reloadConfig();
      }

      const existingPanels = panels();
      if (screenCount < 2 || existingPanels.length === 0) {
        return "retry";
      }

      if (existingPanels.length >= 2) {
        return "done";
      }

      const primaryPanel = existingPanels[0];
      if (primaryPanel.screen < 0) {
        return "retry";
      }

      primaryPanel.location = "bottom";
      primaryPanel.height = PANEL_HEIGHT;

      const primaryWidgets = primaryPanel.widgets();
      for (let i = 0; i < primaryWidgets.length; ++i) {
        if (primaryWidgets[i].type === "org.kde.plasma.systemtray") {
          configurePowerItem(primaryWidgets[i]);
        }
      }

      let secondaryScreen = -1;
      for (let screen = 0; screen < screenCount; ++screen) {
        if (screen !== primaryPanel.screen) {
          secondaryScreen = screen;
          break;
        }
      }

      if (secondaryScreen < 0) {
        return "retry";
      }

      const secondaryPanel = new Panel;
      secondaryPanel.screen = secondaryScreen;
      secondaryPanel.location = "bottom";
      secondaryPanel.height = PANEL_HEIGHT;
      secondaryPanel.alignment = primaryPanel.alignment;
      secondaryPanel.offset = primaryPanel.offset;
      secondaryPanel.lengthMode = primaryPanel.lengthMode;
      secondaryPanel.minimumLength = primaryPanel.minimumLength;
      secondaryPanel.maximumLength = primaryPanel.maximumLength;
      secondaryPanel.hiding = primaryPanel.hiding;
      secondaryPanel.floating = primaryPanel.floating;
      secondaryPanel.floatingApplets = primaryPanel.floatingApplets;
      secondaryPanel.opacity = primaryPanel.opacity;

      secondaryPanel.addWidget("org.kde.plasma.kickoff");
      secondaryPanel.addWidget("org.kde.plasma.pager");
      secondaryPanel.addWidget("org.kde.plasma.icontasks");
      secondaryPanel.addWidget("org.kde.plasma.marginsseparator");
      const secondaryTray = secondaryPanel.addWidget("org.kde.plasma.systemtray");
      configurePowerItem(secondaryTray);
      secondaryPanel.addWidget("org.kde.plasma.digitalclock");
      secondaryPanel.addWidget("org.kde.plasma.showdesktop");

      return "done";
    })();
  '';

  bootstrapPanels = pkgs.writeShellScript "bootstrap-hp-z2-panels" ''
    set -u

    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos"
    marker="$state_dir/hp-z2-second-panel-initialized"

    [ -e "$marker" ] && exit 0

    # The paired NixOS HP profile intentionally waits 30 seconds after login
    # before applying the final two-monitor KScreen layout. That settling
    # period prevents Plasma from creating/migrating multiple application bars
    # while the output topology is still changing. Wait five seconds longer so
    # this one-time second-panel bootstrap runs only after that layout has
    # settled. The 30 s / 35 s ordering is deliberate; do not change either
    # delay independently without reviewing both repositories together.
    ${pkgs.coreutils}/bin/sleep 35

    script="$(${pkgs.coreutils}/bin/cat ${panelScript})"

    for _ in $(${pkgs.coreutils}/bin/seq 1 25); do
      if reply="$(${pkgs.dbus}/bin/dbus-send \
        --session \
        --type=method_call \
        --print-reply \
        --dest=org.kde.plasmashell \
        /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        string:"$script" \
        2>/dev/null)"
      then
        case "$reply" in
          *'string "done"'*)
            ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
            ${pkgs.coreutils}/bin/touch "$marker"
            exit 0
            ;;
        esac
      fi

      ${pkgs.coreutils}/bin/sleep 0.2
    done

    exit 0
  '';

  markExistingPanels = pkgs.writeShellScript "mark-existing-hp-z2-panels" ''
    set -u

    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos"
    marker="$state_dir/hp-z2-second-panel-initialized"
    panel_config="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    [ -e "$marker" ] && exit 0
    [ -f "$panel_config" ] || exit 0

    panel_count="$(${pkgs.python3}/bin/python3 - "$panel_config" <<'PYTHON'
import re
import sys

path = sys.argv[1]
section = None
count = 0
pattern = re.compile(r'^\[Containments\]\[(\d+)\]$')

with open(path, encoding='utf-8') as f:
    for raw in f:
        line = raw.strip()
        if line.startswith('['):
            section = bool(pattern.fullmatch(line))
            continue
        if section and line == 'plugin=org.kde.panel':
            count += 1
            section = False

print(count)
PYTHON
    )"

    if [ "$panel_count" -ge 2 ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
      ${pkgs.coreutils}/bin/touch "$marker"
    fi
  '';
in
{
  imports = [
    ../modules/common.nix
    ../modules/desktops/plasma.nix
  ];

  home.activation.configureHpZ2Plasma = lib.hm.dag.entryAfter [ "configurePlasmaDefaults" ] ''
    mkdir -p "$HOME/.config"

    ${kwriteconfig6} \
      --file "$HOME/.config/kcminputrc" \
      --group Keyboard \
      --key NumLock \
      0

    ${kwriteconfig6} \
      --file "$HOME/.config/kwinrc" \
      --group EdgeBarrier \
      --key EdgeBarrier \
      0

    ${kwriteconfig6} \
      --file "$HOME/.config/kwinrc" \
      --group EdgeBarrier \
      --key CornerBarrier \
      --type bool \
      false

    ${markExistingPanels}
  '';

  # The HP profile applies its tray defaults during the one-time panel
  # bootstrap. Disable the common login autostart so Plasma is never stopped
  # and restarted at login merely for tray post-processing.
  xdg.configFile."autostart/nixos-plasma-tray-defaults.desktop".enable = lib.mkForce false;

  systemd.user.services.hp-z2-panel-bootstrap = {
    Unit = {
      Description = "Initialize HP Z2 second Plasma panel once";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.local/state/nixos/hp-z2-second-panel-initialized";
    };

    Service = {
      Type = "oneshot";
      ExecStart = bootstrapPanels;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}

{
  lib,
  pkgs,
  ...
}:

let
  kreadconfig6 = "${pkgs.kdePackages.kconfig}/bin/kreadconfig6";
  kwriteconfig6 = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  configurePlasmaTray = pkgs.writeShellScript "configure-plasma-tray" ''
    set -u

    tray_config="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    [ -f "$tray_config" ] || exit 0

    # Since Plasma 6, the system tray is no longer a separate top-level
    # containment. Find all system-tray applets directly in their panel
    # containments.
    tray_locations="$(${pkgs.python3}/bin/python3 - "$tray_config" <<'PYTHON'
import re
import sys

path = sys.argv[1]
section = None
pattern = re.compile(r'^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]$')

with open(path, encoding='utf-8') as f:
    for raw in f:
        line = raw.strip()
        if line.startswith('['):
            match = pattern.fullmatch(line)
            section = match.groups() if match else None
            continue

        if section and line == 'plugin=org.kde.plasma.systemtray':
            print(section[0], section[1])
PYTHON
    )"

    [ -n "$tray_locations" ] || exit 0

    read_key() {
      panel_id="$1"
      applet_id="$2"
      key="$3"

      ${kreadconfig6} \
        --file "$tray_config" \
        --group Containments \
        --group "$panel_id" \
        --group Applets \
        --group "$applet_id" \
        --group General \
        --key "$key" 2>/dev/null || true
    }

    write_key() {
      panel_id="$1"
      applet_id="$2"
      key="$3"
      value="$4"

      ${kwriteconfig6} \
        --file "$tray_config" \
        --group Containments \
        --group "$panel_id" \
        --group Applets \
        --group "$applet_id" \
        --group General \
        --key "$key" \
        "$value"
    }

    append_item() {
      value="$1"
      item="$2"

      if [ -z "$value" ]; then
        printf '%s' "$item"
        return
      fi

      case ",$value," in
        *,$item,*) printf '%s' "$value" ;;
        *) printf '%s,%s' "$value" "$item" ;;
      esac
    }

    remove_item() {
      value="$1"
      item="$2"
      printf '%s' "$value" \
        | ${pkgs.coreutils}/bin/tr ',' '\n' \
        | ${pkgs.gnugrep}/bin/grep -vxF "$item" \
        | ${pkgs.coreutils}/bin/paste -sd, - \
        || true
    }

    battery="org.kde.plasma.battery"
    needs_change=false

    while read -r panel_id applet_id; do
      [ -n "$panel_id" ] && [ -n "$applet_id" ] || continue

      old_extra="$(read_key "$panel_id" "$applet_id" extraItems)"
      old_shown="$(read_key "$panel_id" "$applet_id" shownItems)"
      old_hidden="$(read_key "$panel_id" "$applet_id" hiddenItems)"

      extra="$(append_item "$old_extra" "$battery")"
      shown="$(append_item "$old_shown" "$battery")"
      hidden="$(remove_item "$old_hidden" "$battery")"

      if [ "$old_extra" != "$extra" ] \
        || [ "$old_shown" != "$shown" ] \
        || [ "$old_hidden" != "$hidden" ]; then
        needs_change=true
        break
      fi
    done <<< "$tray_locations"

    [ "$needs_change" = true ] || exit 0

    plasma_was_active=false
    if ${pkgs.systemd}/bin/systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
      ${pkgs.systemd}/bin/systemctl --user stop plasma-plasmashell.service || exit 0
      plasma_was_active=true
    fi

    restart_plasma() {
      if [ "$plasma_was_active" = true ]; then
        ${pkgs.systemd}/bin/systemctl --user start plasma-plasmashell.service || true
      fi
    }
    trap restart_plasma EXIT

    while read -r panel_id applet_id; do
      [ -n "$panel_id" ] && [ -n "$applet_id" ] || continue

      old_extra="$(read_key "$panel_id" "$applet_id" extraItems)"
      old_shown="$(read_key "$panel_id" "$applet_id" shownItems)"
      old_hidden="$(read_key "$panel_id" "$applet_id" hiddenItems)"

      extra="$(append_item "$old_extra" "$battery")"
      shown="$(append_item "$old_shown" "$battery")"
      hidden="$(remove_item "$old_hidden" "$battery")"

      write_key "$panel_id" "$applet_id" extraItems "$extra"
      write_key "$panel_id" "$applet_id" shownItems "$shown"
      write_key "$panel_id" "$applet_id" hiddenItems "$hidden"
    done <<< "$tray_locations"
  '';
in
{
  home.activation.configurePlasmaDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config"

    ${kwriteconfig6} \
      --file "$HOME/.config/ksmserverrc" \
      --group General \
      --key confirmLogout \
      --type bool \
      false

    ${kwriteconfig6} \
      --file "$HOME/.config/ksmserverrc" \
      --group General \
      --key loginMode \
      emptySession

    ${kwriteconfig6} \
      --file "$HOME/.config/kcminputrc" \
      --group Keyboard \
      --key RepeatDelay \
      250

    ${kwriteconfig6} \
      --file "$HOME/.config/kcminputrc" \
      --group Keyboard \
      --key RepeatRate \
      75

    ${kwriteconfig6} \
      --file "$HOME/.config/kcminputrc" \
      --group Mouse \
      --key cursorSize \
      36

    ${configurePlasmaTray}
  '';

  xdg.configFile."autostart/nixos-plasma-tray-defaults.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NixOS Plasma Tray Defaults
    Exec=${configurePlasmaTray}
    OnlyShowIn=KDE;
    NoDisplay=true
  '';
}

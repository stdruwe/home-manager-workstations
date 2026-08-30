{ lib, pkgs, ... }:

let
  packageNames = pkgs.writeText "nixshell-package-names" (
    lib.concatStringsSep "\n" (builtins.attrNames pkgs) + "\n"
  );

  nixshell = pkgs.writeShellApplication {
    name = "nixshell";

    runtimeInputs = [ pkgs.nix ];

    text = ''
      if [ "$#" -eq 0 ]; then
        echo "Usage: nixshell <package> [package ...]" >&2
        exit 2
      fi

      args=()
      for pkg in "$@"; do
        args+=("nixpkgs#$pkg")
      done

      exec nix shell "''${args[@]}"
    '';
  };
in
{
  home.packages = [ nixshell ];

  # Fast Bash completion for nixshell. The package-name list is generated once
  # from the same nixpkgs package set Home Manager is currently evaluating, so
  # pressing Tab never has to run `nix search` or evaluate nixpkgs again.
  programs.bash.initExtra = lib.mkAfter ''
    _nixshell_complete() {
      local cur
      cur="''${COMP_WORDS[COMP_CWORD]}"
      COMPREPLY=()

      mapfile -t COMPREPLY < <(
        ${pkgs.gawk}/bin/awk -v prefix="$cur" '
          index($0, prefix) == 1 {
            print
            count++
            if (count >= 200) exit
          }
        ' ${packageNames}
      )
    }

    complete -F _nixshell_complete nixshell
  '';
}

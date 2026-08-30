{ ... }:

{
  programs.starship.settings.nix_shell = {
    heuristic = true;
    format = "[$symbol]($style) ";
    symbol = "❄ ";
  };
}

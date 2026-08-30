{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Latest pre-built Home Assistant Builder CLI for x86_64 Linux.
    # flake.lock pins the downloaded binary; `nix flake update hab` refreshes it.
    hab = {
      url = "file+https://github.com/balloob/home-assistant-build-cli/releases/latest/download/hab-linux-amd64";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-index-database,
      hermes-agent,
      hab,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      mkHome =
        {
          profileName,
          profile,
          withHermes ? false,
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit hermes-agent hab profileName;
          };

          modules =
            [
              nix-index-database.homeModules.default
              ./modules/nixshell.nix
              ./modules/starship.nix
            ]
            ++ (if withHermes then [ hermes-agent.homeManagerModules.default ] else [ ])
            ++ [ profile ];
        };
    in
    {
      homeConfigurations = {
        "thinkpad-x1-carbon-gen13" = mkHome {
          profileName = "thinkpad-x1-carbon-gen13";
          profile = ./hosts/thinkpad-x1-carbon-gen13.nix;
          withHermes = true;
        };

        "hp-z2-tower-g9" = mkHome {
          profileName = "hp-z2-tower-g9";
          profile = ./hosts/hp-z2-tower-g9.nix;
        };

        "apple-macbook-air-8-1" = mkHome {
          profileName = "apple-macbook-air-8-1";
          profile = ./hosts/apple-macbook-air-8-1.nix;
        };
      };
    };
}

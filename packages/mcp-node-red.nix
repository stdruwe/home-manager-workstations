{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "mcp-node-red";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "fx";
    repo = "mcp-node-red";
    rev = "082c0d43cfcd9600a1a046e2d4ff4f3c47eb0940";
    hash = "sha256-R44JEhioXE0vH+YJVAfvk+C9DkfPO/OYLJWpY6NMla4=";
  };

  npmDepsHash = "sha256-rFqLAncgDyjd6+Vt9WCT0qPaqH4lOa3ByadmWnb2e8w=";

  # Upstream has a Husky prepare hook for development checkouts. It is not
  # needed for the packaged runtime and would be inappropriate in the Nix build.
  npmInstallFlags = [ "--ignore-scripts" ];

  meta = {
    description = "MCP server for Node-RED workflow management";
    homepage = "https://github.com/fx/mcp-node-red";
    license = lib.licenses.mit;
    mainProgram = "mcp-node-red";
    platforms = lib.platforms.linux;
  };
}

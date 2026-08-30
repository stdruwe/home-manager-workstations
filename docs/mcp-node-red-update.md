# mcp-node-red update workflow

Last updated: 2026-08-29

The standard Node-RED MCP used by Hermes is packaged declaratively in `packages/mcp-node-red.nix`.

It must not be started through `npx`, because that would make runtime behavior depend on the npm registry/cache and could silently change the MCP version outside this repository.

## Current package model

`packages/mcp-node-red.nix` pins four values:

- upstream version
- exact release commit
- `fetchFromGitHub` source hash
- `npmDepsHash` derived from the release commit's `package-lock.json`

`modules/hermes.nix` keeps the package in both `home.packages` and Hermes `extraPackages`. `home.packages` roots the package in the active Home Manager profile even when no Hermes gateway/backend service is enabled; `extraPackages` also makes it available on the PATH of Hermes-managed services if those are enabled later. The Node-RED MCP configuration uses the package's absolute Nix store executable path.

## Updating to a new release

1. Inspect the latest upstream release and determine its exact target commit. Do not assume a tag naming convention; upstream has used both `v1.x.x` and `mcp-node-red-v1.x.x` tags.
2. Set `REV` to that exact release commit and determine the two Nix hashes:

```bash
REV=<release-commit>

nix run nixpkgs#nix-prefetch-github -- \
  fx mcp-node-red \
  --rev "$REV" \
  --json

tmp="$(mktemp)"
curl -fsSL \
  "https://raw.githubusercontent.com/fx/mcp-node-red/$REV/package-lock.json" \
  -o "$tmp"

nix run nixpkgs#prefetch-npm-deps -- "$tmp"
rm -f "$tmp"
```

3. Update `version`, `rev`, `hash`, and `npmDepsHash` in `packages/mcp-node-red.nix`.
4. Build the ThinkPad technical profile before activation:

```bash
cd "$HOME/.config/home-manager"
home-manager build --impure --flake '.#thinkpad-x1-carbon-gen13'
```

5. Because this package is used only by the ThinkPad/Hermes profile, that profile is the required package-level validation. Repository CI still evaluates all three supported Home Manager profiles after the commit.
6. After a successful build, activate it on the ThinkPad system:

```bash
home-manager switch --impure --flake '.#thinkpad-x1-carbon-gen13'
```

7. Verify the normal Node-RED MCP from Hermes. The file-based Node-RED MCP is a separate local implementation and is not changed by this package update.

Do not automate activation of a newly discovered upstream release without first building and testing it. MCP releases can change tool schemas or Node-RED API behavior even when packaging still succeeds.

There are no username-, hostname- or fixed-home-path profile aliases in the current repository. Evaluation uses the technical hardware profile and `--impure` local user identity.

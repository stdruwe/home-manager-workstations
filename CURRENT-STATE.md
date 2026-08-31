# Current State

Last updated: 2026-08-31

This file is the durable operational baseline for the Home Manager repository. Read it before persistent changes and update it when profiles, shared modules, desktop behavior, Hermes integration or update responsibilities change. Do not record transient debugging experiments here.

## Repository role

- intended public repository: `stdruwe/home-manager-workstations`
- matching public NixOS repository: `stdruwe/nixos-workstations`
- standalone Home Manager flake
- public version history starts at `v0.1.0`
- user-level configuration remains separate from the NixOS system repository
- configuration remains declarative
- no username or hostname is encoded in supported flake output names
- local identity is obtained from `USER` and `HOME`, therefore evaluation intentionally uses `--impure`
- `flake.lock.bootstrap` is the tracked clean-checkout/install baseline
- `flake.lock` is ignored machine-local dependency state after installation

The repository path itself is not part of the configuration contract. Modules use Home Manager's current user/home data rather than fixed `/home/<name>` paths.

System-level NixOS configuration lives in the paired public NixOS repository and is installed at `/etc/nixos`.

Documentation uses technical profile names, hardware descriptions and generic placeholders rather than deployment-specific hostnames or personal usernames.

## Managed hardware profiles

`flake.nix` defines exactly three supported outputs:

- `thinkpad-x1-carbon-gen13`
- `hp-z2-tower-g9`
- `apple-macbook-air-8-1`

There is no generic username compatibility alias and no root `home.nix` compatibility entrypoint.

Build examples for an installed checkout with a live local lock:

```bash
home-manager build --impure --flake 'path:.#thinkpad-x1-carbon-gen13'
home-manager build --impure --flake 'path:.#hp-z2-tower-g9'
home-manager build --impure --flake 'path:.#apple-macbook-air-8-1'
```

A newly cloned clean checkout seeds `flake.lock` from `flake.lock.bootstrap` before building. Package/input versions are then pinned per machine by the ignored live `flake.lock`; `--impure` is used only to supply local user identity and optional deployment data from the NixOS checkout.

## Desktop layering

Desktop-neutral user configuration lives in `modules/common.nix`.

Plasma-specific user behavior lives in:

```text
modules/desktops/plasma.nix
```

ThinkPad and HP import the Plasma module explicitly. The MacBook profile does **not** import Plasma; its COSMIC desktop is configured system-wide in the NixOS repository. Home Manager adds shared user configuration plus the Mac-specific SSH-agent and COSMIC toolkit font choices.

Do not move Plasma-specific KConfig or tray handling back into `modules/common.nix`.

## Fonts

The Apple font files are installed system-wide by the NixOS repository on all three machines. Home Manager uses those existing families rather than packaging another copy.

The shared system policy is:

- `SF Pro` — sans-serif/interface
- `SF Mono` — monospace
- Apple's `New York` family at Medium weight (`wght=500`) — normal serif

The paired NixOS configuration exposes `New York Medium` as a semantic Fontconfig alias. Normal serif requests resolve through that alias to the New York variable family at Medium weight; explicit stronger weights are not forced back to Medium. Firefox, Zen Browser and Thunderbird receive the same system-owned generic font defaults from NixOS.

Home Manager must not introduce a parallel Fontconfig or Gecko font policy. Shared `modules/common.nix` only enables GTK font configuration with `SF Pro 10`.

The `apple-macbook-air-8-1` profile additionally manages COSMIC's native toolkit font entries under `~/.config/cosmic/com.system76.CosmicTk/v1/`:

- `interface_font` → `SF Pro`
- `monospace_font` → `SF Mono`

COSMIC exposes no separate native serif setting. Generic serif requests therefore inherit the system-wide New York Medium mapping from NixOS Fontconfig.

## Hardware-specific user behavior

### `thinkpad-x1-carbon-gen13`

- common + Plasma user configuration
- Hermes Agent/Desktop integration enabled
- HAB and Node-RED MCP integrations
- socket-activated Chromium CDP backend
- PowerDevil/internal-display refresh handling

### `hp-z2-tower-g9`

- common + Plasma user configuration
- no Hermes integration
- one-time dual-monitor Plasma panel bootstrap
- recurring tray bootstrap disabled after successful initialization

### `apple-macbook-air-8-1`

- common desktop-neutral configuration
- no Plasma module
- no Hermes module
- COSMIC interface font is SF Pro; COSMIC monospace font is SF Mono
- generic serif requests inherit New York Medium from system Fontconfig
- Bitwarden SSH agent socket is explicitly selected for OpenSSH and `SSH_AUTH_SOCK`
- shared GitHub SSH routing is inherited from common configuration for authenticated development use

## Shared SSH / Git

GitHub SSH is routed through:

```text
HostName ssh.github.com
Port 443
User git
```

This applies to authenticated GitHub development access. Installed-system repository reads use the public HTTPS origin configured by the NixOS installer.

The MacBook profile additionally pins the Bitwarden agent socket so COSMIC/GCR cannot silently redirect Git/SSH to a different empty agent.

Personal Git commit identity is not stored in the repository. The managed Git configuration includes the optional unmanaged file `~/.config/git/user.inc`; a local deployment may define `user.name` and `user.email` there. A missing local include is valid.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`.

The evaluation matrix covers all three profiles. CI copies tracked `flake.lock.bootstrap` to the ignored live `flake.lock` before evaluation, supplies an arbitrary writable test `USER`/`HOME`, and evaluates with `--impure --no-write-lock-file`.

This verifies both the clean-checkout bootstrap path and independence from a real workstation username or hostname. Optional `/etc/nixos/deployment.json` data is not required for CI evaluation.

A separate static-check job compiles `packages/node-red-file-mcp.py` and runs the Node-RED file-MCP safety tests. CI also validates the GitHub Actions workflow with actionlint.

## Default browser

Zen Browser is the intended default browser on all managed systems. Home Manager owns targeted MIME/default-browser associations rather than globally taking over the entire user `mimeapps.list`.

Current defaults include HTML/XHTML and HTTP/HTTPS handlers plus `BROWSER=zen-beta`. Firefox remains available system-wide as fallback where installed by NixOS.

## Shell environment

### Bash / Starship

- Bash is the shared shell environment
- Starship is enabled with Bash integration
- the prompt indicates Nix shell environments

### nix-index / nixshell

- nix-index with Bash integration is enabled
- Fish integration is intentionally disabled
- `nixshell` maps package names to `nixpkgs#<package>` and has declarative Bash completion

## Common applications

Shared Home Manager configuration includes Absotui, playerctl, Starship, nix-index, nixshell and targeted Zen Browser defaults.

Absotui remains deliberately pinned and does not silently track upstream through Topgrade.

## Plasma defaults

`modules/desktops/plasma.nix` owns shared Plasma behavior including logout/session/input/cursor/tray defaults. The HP profile disables recurring tray-login adjustment because its one-time panel bootstrap owns initial panel setup.

Home Manager does not own `~/.gtkrc-2.0`; Plasma writes that GTK2 file itself. GTK3/GTK4 configuration remains managed by Home Manager.

No Plasma-specific setting leaks into the MacBook profile through `modules/common.nix`.

## Hermes

Hermes integration belongs exclusively to `thinkpad-x1-carbon-gen13`.

The current upstream Home Manager module separates package installation from service/configuration state:

```nix
programs.hermes-agent = {
  enable = true;
  desktop.enable = true;
};

services.hermes-agent = {
  enable = true;
  # state, settings, environment, MCP and daemons
};
```

Hermes rules:

- preserve existing configuration unless a requested change targets it
- never commit API keys, tokens, passwords, private hostnames or deployment-specific service endpoints
- secret environment file: current user's `~/.config/hermes/hermes.env`
- deployment-specific non-secret HAB/Ollama endpoints: optional `/etc/nixos/deployment.json` keys `hermes.habUrl` and `hermes.ollamaBaseUrl`
- helper paths derive from `home.homeDirectory`
- when no local Hermes deployment endpoints are present, the Home Manager profile still evaluates and local HAB/Ollama integration is simply omitted

### Node-RED MCP

The normal Node-RED MCP is packaged declaratively as `packages/mcp-node-red.nix` and executed directly from the Nix store. It does not fall back to runtime `npx`.

The separate local file-based server `packages/node-red-file-mcp.py` is used only for validated whole-flow updates.

Whole-flow safety model:

1. stage the complete flow JSON in `$XDG_RUNTIME_DIR/hermes-node-red/`;
2. run `validate_flow_file`;
3. reject duplicate IDs and path traversal;
4. require staged flow ID to exactly match the requested target;
5. deploy only with `update_flow_file` after successful validation;
6. never fall back to a partial-flow deployment.

## Chromium CDP for Hermes

The ThinkPad profile retains the socket-activated local Chromium CDP setup:

- front socket: `127.0.0.1:9222`
- backend Chromium: `127.0.0.1:9223`
- socket proxy exits after the configured idle period

This infrastructure is absent from HP and MacBook profiles.

## Update workflow

Topgrade is configured and owned by the NixOS repository.

Every machine pulls its configured NixOS and Home Manager upstream repositories with fast-forward-only semantics. Normal clients never commit or push Home Manager dependency updates back to this repository.

The live `flake.lock` belongs to the installed machine. When machine-local managed dependency updates are enabled, Topgrade:

1. ensures a live `flake.lock` exists, seeding it from `flake.lock.bootstrap` when necessary;
2. creates a temporary candidate lock from current upstream inputs;
3. validates only the current machine's `homeConfigurations.<profile>.activationPackage` against that exact candidate;
4. replaces the ignored live `flake.lock` only after successful validation;
5. leaves the previous local lock intact if update or validation fails.

The NixOS-side optional `deployment.json` setting `topgrade.updateManagedDependencies` defaults to `true`. Setting it to `false` freezes machine-local managed dependency advancement while preserving repository synchronization and normal activation.

There is no publisher role, shared update transaction, automatic dependency commit, or automatic dependency push. Different installed machines may intentionally use different input revisions while sharing the same Home Manager configuration source.

The later normal Home Manager step in Topgrade activates only the profile of the current machine.

## Fresh-install integration

Fresh NixOS installations use the combined version-matched release package produced by the paired NixOS repository. The archive contains the exact NixOS release plus the matching Home Manager release as a local `home-manager.bundle`.

The NixOS installer:

1. verifies the bundle and requires `refs/heads/main` before destructive actions;
2. clones the bundle for preflight evaluation;
3. seeds ignored live `flake.lock` from tracked `flake.lock.bootstrap` when necessary;
4. evaluates the selected hardware profile using the newly entered `USER` and target `HOME`;
5. after `nixos-install`, clones the bundle to the target user's `~/.config/home-manager`;
6. sets `origin` to `https://github.com/stdruwe/home-manager-workstations.git`;
7. seeds the target checkout's local `flake.lock` from the bootstrap lock;
8. builds the selected `activationPackage` directly into the target `/mnt/nix` store;
9. records that store path for one-time activation during the first real boot.

The NixOS service `home-manager-initial-activation.service` is required by and ordered before `display-manager.service`. It activates the already built package as the normal user and removes its pending marker only after success. Plasma/COSMIC therefore cannot present the first graphical login until Home Manager has been applied, and the first boot does not need GitHub access for this activation.

Normal later pulls use public HTTPS and require neither a GitHub account nor an SSH key.

The implementation and recovery procedure are documented in the paired NixOS repository under `docs/install-package.md` and `docs/home-manager-install-bundle.md`.

## Public release model

The public repository pair starts at `v0.1.0`. Both repositories carry the same release tag.

Public history starts from one clean initial public baseline rather than importing private development history. Installed systems use the public HTTPS repositories as their regular upstreams.

## Activation/testing

ThinkPad:

```bash
home-manager switch --impure --flake 'path:.#thinkpad-x1-carbon-gen13'
```

HP Z2:

```bash
home-manager switch --impure --flake 'path:.#hp-z2-tower-g9'
```

MacBook:

```bash
home-manager switch --impure --flake 'path:.#apple-macbook-air-8-1'
```

Normal day-to-day updates are expected to flow through Topgrade.

## Conventions

- Do not recreate `home.nix`.
- Do not recreate username- or hostname-based profile aliases.
- Keep desktop-neutral shared configuration in shared modules.
- Keep Plasma-specific behavior under `modules/desktops/plasma.nix`.
- Keep hardware-specific behavior under `hosts/`.
- Use Home Manager's local user/home data instead of fixed `/home/<name>` paths.
- Keep secrets, deployment-specific endpoints and personal Git identity outside the repository.
- Use `--impure` whenever evaluating these hardware profiles.
- Use explicit `path:.#<profile>` references for manual builds/switches against an installed checkout with the ignored live lock.
- Keep `flake.lock.bootstrap` tracked as the clean-checkout/install baseline; keep the live `flake.lock` ignored and machine-local.
- Do not add automatic Topgrade dependency commits or pushes back to the upstream repository.
- Keep this document synchronized with durable changes.

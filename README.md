# Home Manager – hardware-based profiles

Standalone Home Manager configuration for three NixOS hardware profiles. Hostname and username are explicitly **not** part of the profile ID. Desktop-specific user configuration is selected by the hardware profiles.

## Public repository and releases

The intended public repository is:

```text
https://github.com/stdruwe/home-manager-workstations.git
```

It is paired with:

```text
https://github.com/stdruwe/nixos-workstations.git
```

The public history starts at `v0.1.0`. Stable releases use the same semantic-version tag in both repositories.

## Profiles

```text
thinkpad-x1-carbon-gen13  -> common + Plasma + Hermes
hp-z2-tower-g9            -> common + Plasma without Hermes
apple-macbook-air-8-1     -> common for COSMIC
```

Local user identity is derived from `USER` and `HOME`. Flake evaluation therefore intentionally uses `--impure`.

Dependency state is machine-local after installation. `flake.lock.bootstrap` is the tracked installation/clean-checkout baseline; the live `flake.lock` is ignored and belongs to the installed machine. This lets each machine advance its own inputs without committing or pushing dependency updates to this repository.

## Layout

```text
flake.nix
flake.lock.bootstrap       # tracked initial dependency state
flake.lock                 # local, ignored live dependency state

modules/
├── common.nix
├── desktops/
│   └── plasma.nix
├── hermes.nix
├── nixshell.nix
└── starship.nix

hosts/
├── thinkpad-x1-carbon-gen13.nix
├── hp-z2-tower-g9.nix
└── apple-macbook-air-8-1.nix

packages/
├── absotui.nix
├── mcp-node-red.nix
└── node-red-file-mcp.py
```

## Shared configuration

`modules/common.nix` contains desktop-neutral user configuration including Bash, Starship, nix-index, the `nixshell` wrapper, Absotui, playerctl, shared SSH/Git defaults and Zen Browser as the default browser.

Personal Git commit identity is deliberately local. The managed Git configuration includes the optional unmanaged file `~/.config/git/user.inc`, where a deployment may define `user.name` and `user.email` without storing them in this repository. A missing local include is valid.

Plasma-specific KConfig and tray settings live separately in `modules/desktops/plasma.nix`. ThinkPad and HP import that module explicitly. The `apple-macbook-air-8-1` profile does **not** import it; COSMIC is managed at the NixOS system level.

Username and home directory are not fixed in the repository. Changing the local Unix user therefore does not require renaming a Home Manager profile.

## Font ownership

Apple font files, Fontconfig defaults and Gecko font defaults are owned by the paired NixOS repository. Home Manager does not duplicate that policy.

The system-wide defaults are SF Pro for sans-serif, SF Mono for monospace and Apple's New York family at Medium weight (`wght=500`) for normal serif requests. COSMIC has no separate native serif setting, so generic serif requests resolve through the NixOS Fontconfig `New York Medium` semantic alias.

## ThinkPad X1 Carbon Gen 13

`hosts/thinkpad-x1-carbon-gen13.nix` additionally enables:

- Plasma user settings
- Hermes Agent/Desktop
- HAB
- Node-RED MCP
- the validated file-based Node-RED whole-flow updater
- Chromium CDP socket/proxy
- Hermes Bash completion
- AC/battery-dependent display and PowerDevil behavior

Hermes follows the current upstream split: CLI/Desktop installation is configured through `programs.hermes-agent`, while state, settings, MCP and services remain under `services.hermes-agent`.

Deployment-specific Hermes endpoints are not tracked in this repository. `modules/hermes.nix` optionally reads `/etc/nixos/deployment.json` and uses `hermes.habUrl` and `hermes.ollamaBaseUrl` when present. The module remains evaluable when that file or those keys are absent. API keys and tokens remain in the current user's `~/.config/hermes/hermes.env`.

## HP Z2 Tower G9

`hosts/hp-z2-tower-g9.nix` uses the shared configuration plus Plasma without Hermes and contains the one-time Plasma panel initialization for the dual-monitor setup.

## Apple MacBook Air 8,1

`hosts/apple-macbook-air-8-1.nix` uses the shared desktop-neutral configuration without Plasma and without Hermes. It additionally selects the Bitwarden SSH agent explicitly so Git/SSH under COSMIC cannot be redirected to a competing empty agent socket.

Shared SSH configuration routes GitHub through `ssh.github.com:443` for authenticated development access. Installed-system repository reads use the public HTTPS origin configured by the NixOS installer.

## Build

A normal installed checkout already has its ignored machine-local `flake.lock`:

```bash
home-manager build --impure --flake 'path:.#thinkpad-x1-carbon-gen13'
home-manager build --impure --flake 'path:.#hp-z2-tower-g9'
home-manager build --impure --flake 'path:.#apple-macbook-air-8-1'
```

For a newly cloned clean checkout, seed the live lock once from the tracked baseline before building:

```bash
cp flake.lock.bootstrap flake.lock
```

## Activate

```bash
home-manager switch --impure --flake 'path:.#thinkpad-x1-carbon-gen13'
home-manager switch --impure --flake 'path:.#hp-z2-tower-g9'
home-manager switch --impure --flake 'path:.#apple-macbook-air-8-1'
```

## Fresh-install integration

Fresh installations transport Home Manager through the combined version-matched package attached to the NixOS release. The package contains the matching Home Manager release as a local Git bundle, so GitHub access is not required for initial activation.

The installer copies `flake.lock.bootstrap` to the ignored live `flake.lock`. The activation package for the selected technical hardware profile is built into the target Nix store during NixOS installation and activated once before the first graphical login.

After installation the Home Manager checkout uses the public read remote:

```text
https://github.com/stdruwe/home-manager-workstations.git
```

Normal updates therefore require neither a GitHub account nor an SSH key.

## Updates

Topgrade is configured by the NixOS repository and selects the matching technical hardware profile automatically.

Normal clients only pull their configured repository upstream. Topgrade never commits or pushes Home Manager dependency updates back to this repository. Instead it creates a temporary candidate lock, validates the current machine's Home Manager profile against that candidate, and replaces the ignored local `flake.lock` only after successful validation.

The NixOS deployment setting `topgrade.updateManagedDependencies` controls whether Topgrade advances machine-local managed dependencies. It defaults to `true`; when set to `false`, repository synchronization and normal activation continue but the local Home Manager lock is not updated.

As a result, different installed machines may intentionally run different Home Manager input revisions while sharing the same configuration source. Repository releases describe configuration/installer versions rather than every dependency refresh.

For the durable operational baseline, read [`CURRENT-STATE.md`](CURRENT-STATE.md).

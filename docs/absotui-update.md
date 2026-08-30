# Updating Absotui

Last updated: 2026-08-29

Absotui is maintained as a pinned Rust package in `packages/absotui.nix`. Topgrade does not update this pin automatically. Do not use `absotui --update` or `cargo install`, because either path bypasses the declarative Home Manager installation.

## 1. Check upstream state

```bash
cd "$HOME/.config/home-manager"
gh api repos/pdwaldrop/Absotui/branches/stable --jq '.commit.sha'
gh api repos/pdwaldrop/Absotui/releases/latest --jq '{tag_name, published_at, html_url}'
```

Upstream recommends the `stable` branch; `main` may be unstable. Before updating, also inspect current upstream issues and `known_bugs.md`. The release version in `Cargo.toml` must match `version` in `packages/absotui.nix`.

## 2. Update the pin and source hash

```bash
rev='<new-stable-commit>'
nix store prefetch-file --json --unpack \
  "https://github.com/pdwaldrop/Absotui/archive/${rev}.tar.gz"
```

Change only the relevant pinned values in `packages/absotui.nix`:

- `version`
- `src.rev`
- `src.hash`

## 3. Refresh the Cargo hash

Temporarily set:

```nix
cargoHash = lib.fakeHash;
```

Then build one explicit technical hardware profile, for example:

```bash
home-manager build --impure --flake '.#thinkpad-x1-carbon-gen13'
```

The hash mismatch reports the required `cargoHash` as `got:`. Copy that exact SRI hash and remove `lib` from the package argument list again if it is no longer used.

## 4. Format and validate all supported profiles

```bash
nixfmt packages/absotui.nix
git diff --check

home-manager build --impure --flake '.#thinkpad-x1-carbon-gen13'
home-manager build --impure --flake '.#hp-z2-tower-g9'
home-manager build --impure --flake '.#apple-macbook-air-8-1'
```

All three supported profiles must evaluate successfully before the pin is published.

## 5. Activate on the current machine

Activate only the technical profile matching the current machine, for example:

```bash
home-manager switch --impure --flake '.#thinkpad-x1-carbon-gen13'
```

Then verify:

```bash
absotui --version
playerctl --version
```

## 6. Commit the update

After successful builds and runtime validation:

```bash
git add packages/absotui.nix
git diff --cached --check
git commit -m "chore: update Absotui"
git push
```

## Notes

- There are no username- or hostname-based Home Manager profile aliases. Always use one of the three technical hardware profiles.
- Profile evaluation and activation require `--impure` because local user/home identity is supplied through `USER` and `HOME`.
- `playerctl` and VLC are provided independently through existing Home Manager/NixOS configuration.
- User configuration under `~/.config/absotui` remains unchanged by package updates.
- If a build fails, do not replace the declarative package with an imperative installer. Correct the source/Cargo hashes from the build output instead.

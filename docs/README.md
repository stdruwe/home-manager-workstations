# Documentation index

The Markdown files in this directory document Home Manager-specific integrations and update procedures. Repository-wide behavior and durable assumptions are described in [`../CURRENT-STATE.md`](../CURRENT-STATE.md).

## Home Manager-specific documentation

- [`absotui-update.md`](absotui-update.md) — procedure for updating the pinned Absotui package.
- [`mcp-node-red-update.md`](mcp-node-red-update.md) — procedure and safety model for updating the Node-RED MCP integration.

## Paired release contract

Home Manager and the paired NixOS repository use the same semantic-version tag. **Home Manager must be published first.** Publishing the NixOS GitHub release immediately starts the combined install-package workflow, which checks out this repository at the matching tag; the tag therefore has to exist already.

The canonical pre-release, publication and verification checklist is maintained in:

- `stdruwe/nixos-workstations/docs/release-process.md`

Before publishing a Home Manager release, run the `Refresh Home Manager release lock` workflow, allow any resulting `flake.lock.bootstrap` commit to reach `main`, and require the follow-up Home Manager CI to be green. After the Home Manager release/tag is verified, publish the matching NixOS release. Published tags are treated as immutable; repair a bad release with a new version rather than moving an existing tag.

## Cross-repository operational rationale

System-level hardware workarounds and cross-repository startup ordering are owned by the paired NixOS repository. Before changing fixed delays, one-time markers, service ordering or other non-obvious Home Manager behavior that interacts with NixOS, read:

- `stdruwe/nixos-workstations/docs/operational-invariants.md`

The HP Z2 35-second one-time panel bootstrap is one such invariant: it intentionally follows the NixOS 30-second KScreen layout application. The two values must be reviewed and tested together.

If an unusual value has no verified historical rationale, preserve it while investigating rather than inventing a reason or optimizing it away.

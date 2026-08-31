# Documentation index

The Markdown files in this directory document Home Manager-specific integrations and update procedures. Repository-wide behavior and durable assumptions are described in [`../CURRENT-STATE.md`](../CURRENT-STATE.md).

## Home Manager-specific documentation

- [`absotui-update.md`](absotui-update.md) — procedure for updating the pinned Absotui package.
- [`mcp-node-red-update.md`](mcp-node-red-update.md) — procedure and safety model for updating the Node-RED MCP integration.

## Cross-repository operational rationale

System-level hardware workarounds and cross-repository startup ordering are owned by the paired NixOS repository. Before changing fixed delays, one-time markers, service ordering or other non-obvious Home Manager behavior that interacts with NixOS, read:

- `stdruwe/nixos-workstations/docs/operational-invariants.md`

The HP Z2 35-second one-time panel bootstrap is one such invariant: it intentionally follows the NixOS 30-second KScreen layout application. The two values must be reviewed and tested together.

If an unusual value has no verified historical rationale, preserve it while investigating rather than inventing a reason or optimizing it away.

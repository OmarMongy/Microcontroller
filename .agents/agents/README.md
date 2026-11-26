# Agent definitions

These role files define project-specific responsibilities for Antigravity custom agents.

- `architect.md`: architecture and interface-contract role.
- `rtl-designer.md`: implementation role.
- `verification-engineer.md`: independent verification role.

The main orchestrator remains responsible for coordination and enforcing `AGENTS.md`.

Before relying on custom subagents, confirm the installed Antigravity version supports the intended custom-agent discovery and delegation workflow. Agent role files are instructions, not a hard security boundary; use Git review and isolated workspaces for protection.

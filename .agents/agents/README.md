# Agent Roles

The Main Orchestrator coordinates these specialist roles. The Orchestrator is responsible for explicit report handoffs; saving a report does not automatically notify another agent.

- `architect.md`: architecture proposals, address regions and interface contracts (no RTL).
- `rtl-designer.md`: approved RTL implementation only.
- `verification-engineer.md`: independent verification, including verification test firmware, testbench, SVA, reference models and coverage.

## Communication rule
All agent-to-agent handoffs go through the Orchestrator unless the human explicitly authorizes otherwise. Include report ID/path, relevant evidence, spec/interface revision, and requested action in each delegation.

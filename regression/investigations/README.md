# Failure Investigations

Create one directory or Markdown report per investigation. Never overwrite an earlier failure report. Use `docs/templates/FAILURE_REPORT.md`.

The Orchestrator owns report routing:
1. Verification Engineer -> Orchestrator.
2. Orchestrator -> Human review.
3. Only after human approval: Orchestrator -> RTL Designer.
4. RTL Designer -> Orchestrator with change proposal.
5. Human approves/rejects patch.
6. Orchestrator requests rerun against the frozen verification baseline.

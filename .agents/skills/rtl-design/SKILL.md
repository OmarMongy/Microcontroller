---
name: rtl-design
description: "Guidelines for implementing synthesizable RTL from approved specifications and interface contracts."
---

# RTL Design Skill

- Read the approved specification and interface contract before coding.
- Confirm all required behavior is defined; list questions rather than guessing.
- Use synthesizable SystemVerilog and clear sequential/combinational separation.
- Define reset behavior and default assignments explicitly.
- Avoid latches, unintended multiple drivers, inferred memories outside approved intent, and unsized constants where they create ambiguity.
- Keep modules small and interfaces stable.
- Do not touch verification-owned files.
- Report changed files, design choices, lint/compile commands, results, and unresolved issues.

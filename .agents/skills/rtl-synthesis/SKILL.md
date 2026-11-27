---
name: rtl-synthesis
description: "Guidelines for running and reporting RTL synthesis as an implementation-quality check."
---

# RTL Synthesis Skill

- Synthesis is an implementation-quality check, not proof of functional correctness.
- Record tool/version, target library/device, constraints, exact command, and source revision.
- Report inferred latches, memories, cell counts, warnings, and unsupported constructs.
- Do not claim physical timing closure or area from generic synthesis statistics.
- Do not modify RTL to optimize area/timing without a task assignment and reviewable diff.

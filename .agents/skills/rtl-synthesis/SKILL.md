# Skill: RTL Synthesis and Structural Analysis

## Purpose
Run a reproducible synthesis flow and interpret its results without overstating what generic synthesis proves.

## Required inputs
- Approved RTL source list.
- Top module and parameter values.
- Constraints, if the selected flow uses them.
- Target technology/library, if technology mapping is intended.
- Approved synthesis script or flow definition.

## Workflow
1. Confirm top module, source files, parameters, and tool version.
2. Run syntax/elaboration and hierarchy checks.
3. Run synthesis using a version-controlled script.
4. Run structural checks and inspect inferred latches, memories, and unresolved cells.
5. Save logs and reports with the regression/run identifier.
6. Compare results against previous runs only when configurations are comparable.
7. Report warnings and limitations.

## Interpretation rules
- Generic cell counts are abstract logic statistics, not physical area.
- Generic synthesis does not establish ASIC timing closure.
- Generic synthesis does not provide FPGA LUT/FF utilization unless an FPGA-specific mapping flow is used.
- Technology mapping requires the correct target library and flow.
- Physical area, placement, routing, parasitics, and sign-off timing require appropriate downstream tools and constraints.
- Never claim timing closure without an actual timing analysis under documented constraints.

## Required output
- Tool and version.
- Top module and parameter values.
- Source list and script path.
- Exact command and exit code.
- Cell statistics and structural-check result.
- Latch/memory/unmapped-cell findings.
- Warnings and limitations.
- Report/log paths and suggested commit message.

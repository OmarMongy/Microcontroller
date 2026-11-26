# Skill: RTL Design

## Purpose
Guide the design agent in producing readable, synthesizable, maintainable SystemVerilog from approved specifications and interface contracts.

## Required inputs
- Human-approved specification and requirement IDs.
- Approved architecture and interface contracts.
- Clock/reset assumptions.
- Target tool constraints and coding subset, if specified.

If any essential behavior is missing or contradictory, stop and raise a question. Do not invent protocol behavior.

## Design workflow
1. Read only the relevant specification sections and contracts.
2. Extract inputs, outputs, state, reset behavior, timing, parameterization, and corner cases.
3. Propose module decomposition and state/datapath architecture when not already approved.
4. Wait for required human approval.
5. Implement synthesizable SystemVerilog.
6. Run permitted compile/lint checks.
7. Review inferred latches, widths, signedness, reset behavior, FSM completeness, and parameter edge cases.
8. Report exact files and evidence.

## Coding practices
- Use `logic` for signals and `always_ff` / `always_comb` for sequential/combinational intent where supported.
- Use nonblocking assignments in sequential logic and blocking assignments in combinational logic.
- Use explicit widths and signedness; avoid unsized constants where they can cause ambiguity.
- Assign defaults in combinational blocks to avoid inferred latches.
- Keep reset behavior consistent with the specification.
- Avoid multiple procedural drivers.
- Separate control and datapath when it improves clarity.
- Avoid unnecessary complexity and premature optimization.
- Do not add behavior not required by the specification.
- Do not silently change module interfaces.

## Verification boundary
- Do not create or edit protected testbench, SVA, scoreboard, reference-model, expected-result, or coverage files.
- Do not weaken checks to make RTL pass.
- A failing test is evidence to investigate, not authority to modify verification.
- If a test appears incorrect, document the evidence and request a verification review and human approval.

## Debugging
For each failure:
1. Capture the failing test, assertion, cycle, signals, and relevant log excerpt.
2. Determine the expected behavior from the approved specification.
3. Explain the RTL discrepancy.
4. Propose the smallest RTL correction.
5. Do not edit verification artifacts.
6. Rerun only after authorization under the current gate.
7. Report before/after results and commit context.

## Required output
- Files changed.
- Requirements implemented.
- Design decisions and assumptions.
- Compile/lint results and exact commands.
- Known limitations.
- Suggested commit message.

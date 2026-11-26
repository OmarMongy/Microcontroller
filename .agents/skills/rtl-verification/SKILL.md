# Skill: Independent RTL Verification

## Purpose
Develop an independent, specification-driven verification environment that evaluates RTL behavior without adopting the implementation as the behavioral oracle.

## Required inputs
- Approved specification and requirement IDs.
- Approved interface contracts.
- Clock/reset and protocol timing requirements.
- Verification plan scope.

Do not use implementation details or internal RTL state as the source of expected behavior.

## Independence rules
- Derive expected behavior from the specification and interface contracts.
- Prefer externally observable behavior and protocol-level checks.
- Do not assume the RTL FSM encoding, internal counters, or implementation structure.
- Do not copy RTL algorithms into the reference model without an independent derivation.
- If the specification is ambiguous, record the ambiguity and request a human decision.
- Develop tests before inspecting implementation details whenever practical.
- Later RTL inspection is permitted for interface integration, not to redefine expected behavior.

## Verification workflow
1. Build a requirement-to-test matrix.
2. Identify normal, boundary, corner, reset, error, and recovery scenarios.
3. Define an independent reference model or scoreboard where appropriate.
4. Develop self-checking tests.
5. Define functional coverage goals and measurable completion criteria.
6. Coordinate compile/interface integration without changing expected behavior.
7. Run verification only through approved execution stages.
8. Review failures and classify them before proposing changes.

## Verification freeze
After human review, assign a baseline ID (for example `SOC_VB_001`) and record the exact Git commit.

A frozen baseline includes testbench, scoreboards, reference models, vectors, expected results, coverage, assertions, and the verification plan.

Any change after freeze requires:
- Failure evidence and reason.
- Proposed diff.
- Explanation of expected impact.
- Human approval.
- New baseline ID and Git commit.
- Regression rerun with old/new baseline identifiers recorded.

Never modify expected results solely to match the DUT.

## Failure classification
Classify each issue as one of:
- RTL defect.
- Verification defect.
- Specification ambiguity / misunderstanding.
- Tool or infrastructure error.
- Inconclusive / needs human investigation.

Do not label an RTL defect until the expected behavior is supported by an approved requirement.

## Required output
- Requirement-to-test mapping.
- Scenarios and coverage goals.
- Files created/modified.
- Verification assumptions and limitations.
- Compile/run results, if actually executed.
- Suspected issues requiring human review.
- Proposed verification baseline ID and commit message.

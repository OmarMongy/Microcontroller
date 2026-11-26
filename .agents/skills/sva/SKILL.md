# Skill: SystemVerilog Assertions (SVA)

## Purpose
Create assertions and cover properties that check approved protocol and functional requirements independently of the RTL implementation.

## Principles
- Assert externally observable requirements whenever possible.
- Use approved clocking and reset assumptions.
- Do not depend on internal FSM encodings or private implementation signals unless the verification plan explicitly requires white-box checking.
- Avoid vacuous properties: pair important assertions with cover properties or demonstrate triggering scenarios.
- Ensure disable conditions and reset behavior are intentional.
- Do not use assertions to encode assumptions that are absent from the specification.

## Workflow
1. Identify requirement IDs suitable for temporal checking.
2. Define sampling clock and reset/disable semantics.
3. Write one property per clear behavior where practical.
4. Review implication operators, delays, repetition, `$past`, `$stable`, and sampled-value semantics carefully.
5. Check that properties can trigger under the test scenarios.
6. Compile assertions with the selected simulator and report unsupported constructs.
7. Review failures against the specification before attributing them to RTL.

## Review checklist
- Correct clock and reset polarity.
- No unintended assertion firing during reset.
- No accidental vacuity.
- No incorrect cycle offset.
- No unsupported or tool-specific syntax hidden from the report.
- Assertions do not assume implementation-specific latency unless specified.
- Coverage properties demonstrate important scenarios.

## Protection
After the verification baseline is frozen, SVA files are protected. Any correction requires documented evidence, human approval, a new baseline identifier, and a regression rerun.

## Required output
- Requirement IDs checked.
- Assertion and cover-property list.
- Sampling/reset assumptions.
- Tool compile status.
- Known limitations and any unverified properties.

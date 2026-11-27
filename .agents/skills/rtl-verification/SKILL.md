---
name: rtl-verification
description: "Guidelines for independent RTL verification, test planning, assertions, and verification firmware."
---

# RTL Verification Skill

- Treat approved specifications and frozen interface contracts as the source of truth.
- Derive tests and expected results independently of RTL implementation.
- Define test intent and expected outcomes before inspecting RTL wherever practical.
- Author assembly/C verification firmware where useful; assign stable test IDs and map each test to requirements.
- Keep verification firmware separate from demo/application firmware and protect it from RTL Designer edits.
- Record toolchain/compiler versions, flags, linker script, image-conversion commands, and generated image identity/hash.
- If memory layout, register behavior, or expected semantics are unspecified, raise a specification question rather than guessing.
- Use directed tests first, then constrained/randomized tests only where useful.
- Cover reset, boundaries, faults, APB wait states, peripheral behavior, and back-to-back transactions as specified.
- Preserve deterministic seeds and reproducible commands.
- Never alter expected behavior just to make implementation pass.
- Record failures with test IDs, timestamps, expected/actual values, logs, and waveforms.

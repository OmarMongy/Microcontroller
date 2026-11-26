# Regression Tracker

## Current status

| Latest run | Status | RTL commit | Verification commit | Spec commit | Baseline |
|---|---|---|---|---|---|
| Not run | NOT_STARTED | — | — | — | — |

## Status definitions

- `PASS`: all required checks completed and passed.
- `FAIL`: one or more functional checks or assertions failed.
- `BLOCKED`: workflow or agent could not proceed; not a design failure.
- `INFRA_ERROR`: tool, environment, installation, or script failure.
- `REVIEW_REQUIRED`: suspected specification or verification issue awaits human decision.
- `NOT_RUN`: no regression has been executed yet.

## Required record for each run

- Run ID and date/time.
- Overall status.
- RTL, verification, and specification Git commit hashes.
- Verification baseline ID.
- Tool versions and exact commands.
- Passed, failed, skipped, and not-run test counts.
- Assertion results.
- Lint warnings/errors.
- Synthesis status and relevant statistics, if run.
- Log/report paths.
- Investigation ID and concise notes.

## Failure investigation procedure

1. Preserve the original failing log and waveform.
2. Record the exact commit and baseline identifiers.
3. Classify as RTL defect, verification defect, specification ambiguity, infrastructure error, or inconclusive.
4. Document evidence and proposed action.
5. Obtain human approval before modifying a frozen verification baseline or approved specification.
6. Record the fix in Git and run a new regression.
7. Never overwrite historical run records silently.

## Append-only history

Add one row per meaningful regression run to `regression_history.csv`. If a record needs correction, append a correction note; do not silently rewrite history.

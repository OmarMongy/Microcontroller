# Regression Tracker

Each run must be recorded in `regression_history.csv` and have a detailed report under `regression/runs/`.

## Status vocabulary
- `PASS`: all required checks passed.
- `FAIL`: one or more design/verification checks failed.
- `BLOCKED`: work cannot proceed because a dependency or decision is missing.
- `INFRA_ERROR`: tool, script, or environment failure.
- `REVIEW_REQUIRED`: evidence suggests a spec or verification issue requiring human review.
- `NOT_RUN`: not executed.

## Required traceability
Record run ID, date/time, spec revision, interface revision, RTL commit, verification baseline ID, tool versions, command, test counts, assertion results, lint/synthesis results, status, report/log paths, author, and notes.

History is append-only. Never silently overwrite a previous run or erase a failure.

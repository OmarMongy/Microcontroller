# AGENTS.md — AI-Assisted RISC-V SoC Project

## 1. Project mission

Develop a small educational microcontroller SoC using a custom RV32I CPU, instruction ROM, data RAM, an APB3 peripheral subsystem, UART, GPIO, and timer.

The project is an experiment in disciplined AI-assisted digital hardware engineering. The goal is not merely to obtain passing simulations; it is to produce traceable specifications, independently developed verification, reproducible regression evidence, and reviewable RTL.

## 2. Non-negotiable engineering principles

1. **Specification is the source of truth.** RTL and verification must implement the same human-approved specification and interface contracts.
2. **Independent verification.** The RTL implementation agent must not author or silently modify the verification environment used to judge its implementation.
3. **Verification protection.** Once a verification baseline is approved, changes to testbench, assertions, reference models, expected results, or coverage require a documented reason and explicit human approval.
4. **Human-in-the-Loop (HITL).** The human engineer owns architecture decisions, specification interpretation, approval gates, debugging direction, manual edits, and final sign-off.
5. **Evidence over claims.** Never claim a test, lint, synthesis, or timing result unless the relevant command actually ran and its output was inspected.
6. **Traceability.** Every meaningful RTL, verification, or specification change must be traceable to a Git commit and, where applicable, a regression run.
7. **Controlled parallelism.** Parallel agents must have explicit task boundaries, file ownership, interface contracts, and integration points.
8. **Token efficiency.** Give agents only the relevant specification sections and files. Prefer concise reports, avoid rereading the entire repository unnecessarily, and do not spawn agents for trivial sequential work.
9. **No fabricated sign-off.** Generic synthesis statistics are not physical area, FPGA utilization, or timing closure. Report exactly what the tool measured.

## 3. Project scope

### Initial target architecture

- CPU: small RV32I processor designed from scratch.
- Initial CPU microarchitecture: single-cycle, unless the human approves a change.
- Instruction memory: ROM.
- Data memory: RAM.
- CPU memory interfaces: separate instruction and data interfaces for the initial implementation.
- Interconnect: simple address decoding / memory interface logic.
- Peripheral bus: APB3.
- Peripherals:
  - UART using the previously completed UART IP as a reference/reusable block, with a new APB register wrapper.
  - GPIO, initially 8-bit.
  - 32-bit timer/counter with compare functionality.
- Interrupts, pipelining, caches, operating systems, DMA, and advanced bus protocols are outside the initial milestone unless explicitly approved.

This section is a starting scope, not a substitute for a detailed approved specification. Do not invent architectural details such as exact address maps, reset vectors, interrupt semantics, or bus timing. Propose them for human approval.

## 4. Agent roles and authority

### Main agent / orchestrator
- Coordinates the workflow and delegates bounded tasks.
- Maintains project status, dependencies, and concise progress reports.
- Checks that outputs comply with specifications and file ownership.
- Does not bypass human approval gates.
- Does not treat subagent output as automatically correct.

### Architect agent
- Produces architecture proposals, module boundaries, interface contracts, memory map proposals, and verification planning inputs.
- Identifies ambiguity and contradictions.
- Does not unilaterally approve its own proposals.
- Does not silently change an approved specification.

### RTL design agent
- Implements synthesizable RTL from approved specifications and interface contracts.
- Owns only explicitly assigned RTL files.
- May inspect verification failures as diagnostic evidence.
- Must not edit protected TB, SVA, reference-model, expected-result, or coverage files.
- Must report changed files, design rationale, assumptions, and unresolved issues.

### Verification engineer agent
- Independently derives test plans, testbenches, assertions, reference models, and coverage from the approved specification and interface contracts.
- Must not use the RTL implementation as the behavioral oracle.
- May inspect RTL later for interface integration, but must not change expected behavior to match implementation behavior.
- Owns verification files only when explicitly assigned.
- Must report requirements covered, scenarios tested, limitations, and unresolved ambiguities.

### Execution / review responsibility
- Lint, simulation, synthesis, and regression execution may be performed by the orchestrator or a designated execution agent.
- Execution must use documented scripts and preserve relevant logs/reports.
- An execution agent must not modify RTL or verification merely to make a run pass.

## 5. File ownership policy

Default ownership (refine per milestone):

| Area | Primary owner | Restrictions |
|---|---|---|
| `docs/specifications/` | Architect + human | Human approval required for baseline changes |
| `docs/architecture/` | Architect | Approved architecture changes are versioned |
| `docs/interface_contracts/` | Architect + human | Shared contract; approve before parallel RTL |
| `rtl/` | RTL design agent | Verification agent does not edit RTL |
| `tb/` | Verification agent | RTL agent cannot edit after freeze |
| `sva/` | Verification agent | RTL agent cannot edit after freeze |
| `scripts/` | Orchestrator / execution owner | Changes reviewed and versioned |
| `reports/` | Execution owner | Generated reports must identify run and commit |
| `regression/` | Orchestrator + human | Historical records are append-only; corrections are documented |
| `AGENTS.md`, `.agents/` | Human / framework maintainer | Agents may propose changes, not silently rewrite rules |

Instructions and directory conventions do not provide a security boundary by themselves. Use Git review, isolated branches/worktrees where available, and human review of diffs to enforce ownership.

## 6. Nine engineering gates

### Planning
**Gate 1 — Specification & Architecture**
- Read requirements and identify ambiguity.
- Propose microarchitecture, module hierarchy, interfaces, reset/clock assumptions, memory map, and verification strategy.
- Produce specification and interface-contract drafts.
- Human reviews and approves the baseline before implementation.

### Development
**Gate 2 — RTL Implementation**
- RTL agent implements only approved behavior and interfaces.
- Verification agent works independently from the specification and contracts.
- Keep work partitioned by module and ownership.

**Gate 3 — Lint & Compilation**
- Compile/lint RTL and verification sources as appropriate.
- Record tool versions, commands, exit codes, warnings, and errors.
- Do not hide or waive warnings without documented review.

**Gate 4 — Verification Development**
- Develop self-checking tests, reference models, assertions, and coverage from requirements.
- Review requirement-to-test traceability.
- Human reviews and freezes the verification baseline before judging the RTL.

### Execution
**Gate 5 — Simulation**
- Run the approved test suite against the current RTL.
- Save logs and machine-readable summaries where practical.
- Classify failures before proposing changes.

**Gate 6 — Synthesis**
- Run the approved synthesis flow.
- Record tool/version, script, top module, parameters, warnings, cell statistics, and structural checks.
- Clearly distinguish generic synthesis from technology-mapped or physical implementation results.

**Gate 7 — Debugging & Fixes**
- Investigate whether the failure is an RTL defect, verification defect, specification ambiguity, or infrastructure problem.
- RTL defects: RTL agent proposes/fixes RTL; verification remains unchanged.
- Verification defects: document evidence and proposed correction; obtain human approval before changing protected verification.
- Specification ambiguity: architect documents alternatives; human decides; revise specification and affected artifacts under version control.
- If an agent is stuck, stop automated retries. Summarize evidence and ask the human for direction. The human may manually edit files; agents must inspect the updated state before resuming.

**Gate 8 — Rerun**
- Rerun the approved regression after authorized changes.
- Record the exact commit IDs for RTL, verification, and specification.
- Compare against the previous run and explain changed results.
- Do not call a run a pass if it was incomplete or blocked.

### Final review
**Gate 9 — Final Review**
- Check requirement coverage, regression status, lint, synthesis, unresolved issues, and documentation.
- Ensure reports are reproducible and linked to exact Git revisions.
- Human performs final sign-off.

## 7. Human-in-the-Loop approval policy

Human approval is required for:
- Baseline specification and architecture.
- Interface contracts and memory map.
- Verification baseline freeze.
- Any modification to frozen verification.
- Specification interpretation or revision.
- Significant RTL architectural changes.
- Debugging actions that alter protected artifacts.
- Integration milestones and final sign-off.

Read-only inspection, analysis, and proposals may proceed without approval. Approval of one gate does not authorize later gates.

The human can pause an agent, inspect waveforms/logs, edit RTL or documentation manually, and instruct the agent to continue from the updated files. The agent must not overwrite or revert human changes without explicit permission.

## 8. Verification freeze and exception process

After verification review, create a named baseline, for example `SOC_VB_001`.

A frozen baseline includes:
- Testbench sources.
- SVA sources.
- Reference models and scoreboards.
- Expected results and test vectors.
- Coverage definitions.
- Verification plan and requirement mapping.

When a failure occurs:
1. Preserve the failing log and exact commit identifiers.
2. Classify the issue: RTL, verification, specification, or infrastructure.
3. Gather evidence (waveform, assertion trace, minimal reproducer, protocol analysis).
4. If verification is suspected, propose a change separately.
5. Human reviews and approves or rejects the change.
6. If approved, create a new verification baseline identifier and Git commit.
7. Rerun and record both old and new baseline identifiers.

Never weaken a check solely to make the RTL pass.

## 9. Git and change-management policy

- Initialize and maintain the project as a Git repository.
- `main` is the approved, integrated project history.
- Use feature branches for independent parallel work when the human has approved the task split.
- Do not let multiple agents edit the same files concurrently.
- Before committing, inspect `git status` and `git diff`.
- Use focused commits with descriptive messages.
- Do not commit generated build products, temporary files, huge waveforms, or tool caches by default.
- Commit source, specifications, interface contracts, scripts, and curated reports.
- Keep regression history append-only; if an entry needs correction, add a correction note rather than silently rewriting history.
- Every regression record must identify the Git commit(s) used.
- Agents may prepare changes and commit proposals, but commits to `main`, merges, baseline changes, and protected-file changes require human approval.
- Never use destructive Git commands (`reset --hard`, forced checkout, force push, branch deletion) without explicit human approval.
- Do not amend or rewrite published history without explicit approval.

### Commit message convention

Use:
- `docs: define RV32I core specification`
- `rtl: implement instruction decoder`
- `verify: add RV32I arithmetic tests`
- `sva: assert APB transfer protocol`
- `fix: correct branch target calculation`
- `test: update approved reset test baseline`
- `build: add regression runner`

A commit message must describe the change, not claim that the change is correct.

## 10. Regression tracking policy

For every meaningful regression run, record:
- Unique run ID.
- Date/time.
- Overall status: `PASS`, `FAIL`, `BLOCKED`, `INFRA_ERROR`, or `REVIEW_REQUIRED`.
- Git commit hash (and separate RTL / verification / specification revisions if split).
- Verification baseline ID.
- Tool names and versions.
- Commands/scripts executed.
- Test counts: passed, failed, skipped, not run.
- Assertion results.
- Lint result and warning/error counts.
- Synthesis result and relevant statistics, if run.
- Log/report paths.
- Short notes and linked investigation ID.

A run is `BLOCKED` if an agent or workflow cannot proceed; it is not a pass or a design failure. `INFRA_ERROR` is for tool/environment/script problems. `REVIEW_REQUIRED` is for unresolved verification/specification questions.

## 11. Token and context efficiency

- Do not ask every agent to read the entire repository.
- Provide only relevant files, requirement IDs, interfaces, and task scope.
- Ask agents to inspect current state before editing.
- Avoid repeated full-file summaries; use concise change reports.
- Do not spawn agents for tasks that are trivial, tightly coupled, or sequential.
- Parallelize independent modules only after interface contracts are approved.
- Stop repeated retries when the same failure persists; escalate with evidence.

## 12. Required agent completion report

Every delegated task must return:
1. Task and requirement IDs.
2. Files read.
3. Files created/modified.
4. Summary of implementation or analysis.
5. Commands executed and actual exit codes.
6. Test/lint/synthesis results (or explicitly "not run").
7. Assumptions and unresolved questions.
8. Git status / proposed commit message.
9. Risks and recommended next action.

Do not claim files were committed unless Git confirms the commit.

## 13. Initial repository status

The project repository has been initialized but is initially empty. Do not assume any RTL, testbench, specification, or tool scripts already exist. First create the approved directory structure and project documentation, then proceed through Gate 1.

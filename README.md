# Microcontroller SoC — AI-Assisted RTL Design & Verification

This repository is the workspace for a small RV32I-based microcontroller SoC and an agentic RTL engineering workflow.

## Initial project scope

- Small RV32I CPU designed from scratch (initially single-cycle).
- Instruction ROM and data RAM.
- Simple memory interconnect/address decoder.
- APB3 peripheral subsystem.
- UART with APB register wrapper.
- GPIO.
- 32-bit timer/counter with compare functionality.

Detailed behavior, memory map, reset vector, and interface timing must be specified and approved before RTL implementation.

## Framework

Read `AGENTS.md` before performing engineering work.

Custom agent role definitions are in `.agents/agents/`.
Technical skills are in `.agents/skills/`.
Regression policy and history are in `regression/`.

## Initial status

The repository is initialized. No design baseline or regression has been created yet.

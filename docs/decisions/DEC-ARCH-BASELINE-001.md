# Human Engineering Decision — Initial Architecture Baseline

- Decision ID: `DEC-ARCH-BASELINE-001`
- Status: `APPROVED`
- Topic: Reset, fault behavior, and clock-domain assumptions

## Approved decisions

1. Reset vector is `0x0000_0000`.
2. Invalid or misaligned memory accesses set a visible fault status and halt the CPU.
3. Illegal instructions, `ECALL`, and `EBREAK` set a visible fault status and halt the CPU.
4. APB3 `PSLVERR` sets a visible bus-fault status and halts the CPU.
5. CPU, instruction ROM, data RAM, APB bridge, UART, GPIO, and timer use one shared 50 MHz clock.

## Clarification

Fault-and-halt is a simple educational platform policy. It is not a RISC-V privileged trap implementation. The exact fault encoding, capture registers/signals, and recovery behavior remain detailed architecture-contract items.

## Follow-up

Architect to propose the address regions, local memory timing/byte semantics, CPU fault interface, and APB3 cycle contract. Under the later clarification recorded in `DEC-ARCH-BASELINE-002.md`, individual UART/GPIO/timer register maps are deferred to a separate focused task.

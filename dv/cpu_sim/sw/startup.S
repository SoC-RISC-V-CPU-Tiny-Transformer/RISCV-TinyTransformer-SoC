// -----------------------------------------------------------------------------
// startup.S — Minimal CRT0 for bare-metal RV32I
// Sets up stack pointer then calls main. Halts with infinite loop on return.
// -----------------------------------------------------------------------------

    .section .text.entry, "ax"
    .global  _start

_start:
    li   sp, 0xF000         // stack top: 0xF000 (well below 64KB memory top)
    call main
_halt:
    j    _halt              // infinite loop — testbench detects PC stuck here

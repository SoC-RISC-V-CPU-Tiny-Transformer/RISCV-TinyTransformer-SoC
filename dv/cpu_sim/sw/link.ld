/* link.ld — Linker script for bare-metal RV32I, single flat memory */

ENTRY(_start)

MEMORY {
    MEM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    /* Code: startup first, then all other text */
    .text 0x00000000 : {
        *(.text.entry)
        *(.text*)
        *(.rodata*)
    } > MEM

    /* Initialised data */
    .data : {
        *(.data*)
    } > MEM

    /* Zero-initialised data */
    .bss : {
        *(.bss*)
        *(COMMON)
    } > MEM
}

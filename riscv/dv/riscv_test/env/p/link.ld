/* =============================================================================
 * link.ld  --  Linker script cho riscv-tests chay tren Advanced RISC-V 32-bit SoC
 *
 * Memory map:
 *   0x0000_0000 : .text.init (_start, RVTEST macros)
 *   0x0000_xxxx : .text, .rodata, .data
 *   0x0000_1000 : .tohost  (tohost / fromhost symbols - TB poll vao day)
 *   0x0000_F000 : stack top (SP init trong RVTEST_CODE_BEGIN)
 *
 * Gia su mem model la 64KB (0x0000 - 0xFFFF)
 * ============================================================================= */

ENTRY(_start)

SECTIONS
{
    /* --- Code bat dau tai dia chi 0 (khop voi PC_RESET_VEC cua SoC) --- */
    . = 0x00000000;

    .text.init :
    {
        *(.text.init)       /* _start phai la instruction dau tien */
    }

    .text :
    {
        *(.text)
        *(.text.*)
    }

    .rodata :
    {
        *(.rodata)
        *(.rodata.*)
    }

    /* Align truoc data section */
    . = ALIGN(4);

    .data :
    {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    }

    . = ALIGN(4);

    .bss :
    {
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
    }

    /* --- tohost / fromhost: TB poll dia chi nay de doc ket qua ---
     * Dat tai 0x1000 de tranh collision voi code (test nho < 4KB)
     * va du xa stack top (0xF000)                                    */
    . = 0x00001000;

    .tohost :
    {
        *(.tohost)
    }

    /* Phan con lai cua RAM (khong dung explicit, stack grow down tu 0xF000) */
    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}

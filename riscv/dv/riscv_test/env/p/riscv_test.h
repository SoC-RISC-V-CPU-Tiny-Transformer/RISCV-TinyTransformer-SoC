// -----------------------------------------------------------------------------
// riscv_test.h  --  Platform environment cho riscv-tests chay tren SoC nay
//
// Memory map cua SoC:
//   0x0000 - 0x0FFF : code (.text)
//   0x1000          : tohost  (TB poll dia chi nay de lay ket qua)
//   0x1004 - 0xEFFF : data / stack
//   0xF000          : stack top
//
// TOHOST protocol:
//   PASS : CPU ghi 1          vao tohost  -> TB doc duoc 1      = PASS
//   FAIL : CPU ghi TESTNUM*2+1 vao tohost -> TB doc duoc so le  = FAIL tai vector do
//
// TESTNUM = x28 (caller-saved, convention cua riscv-tests)
// -----------------------------------------------------------------------------

#ifndef _ENV_PHYSICAL_SINGLE_CORE_H
#define _ENV_PHYSICAL_SINGLE_CORE_H

// -----------------------------------------------------------------------
// Register convention
// -----------------------------------------------------------------------
#define TESTNUM x28

// -----------------------------------------------------------------------
// RVTEST_RV32U  --  khai bao day la RV32 user-mode test
// Duoc override tu RVTEST_RV64U trong rv32ui/*.S wrapper
// -----------------------------------------------------------------------
#define RVTEST_RV32U                                                    \
    .option norvc;          /* tat Compressed extension */              \
    .attribute 4, 16;       /* RISC-V ABI stack alignment = 16 */      \

// -----------------------------------------------------------------------
// RVTEST_CODE_BEGIN  --  bat dau phan code
// Dat _start de linker biet entry point; khoi tao stack pointer
// -----------------------------------------------------------------------
#define RVTEST_CODE_BEGIN                                               \
    .section .text.init;                                                \
    .global _start;                                                     \
_start:                                                                 \
    li sp, 0xF000;          /* stack top */                             \
    li TESTNUM, 0;                                                      \

// -----------------------------------------------------------------------
// RVTEST_CODE_END  --  ket thuc phan code (alignment guard)
// -----------------------------------------------------------------------
#define RVTEST_CODE_END                                                 \
    .align 4;                                                           \

// -----------------------------------------------------------------------
// RVTEST_DATA_BEGIN / RVTEST_DATA_END  --  phan data
// Chua tohost va fromhost (fromhost khong dung nhung phai ton tai)
// -----------------------------------------------------------------------
#define RVTEST_DATA_BEGIN                                               \
    .pushsection .tohost,"aw",@progbits;                                \
    .align 6;                                                           \
    .global tohost;                                                     \
tohost:   .dword 0;                                                     \
    .global fromhost;                                                   \
fromhost: .dword 0;                                                     \
    .popsection;                                                        \
    .section .data;                                                     \
    .align 4;                                                           \

#define RVTEST_DATA_END                                                 \

// -----------------------------------------------------------------------
// RVTEST_PASS  --  bao PASS: ghi 1 vao tohost roi dung lai
// -----------------------------------------------------------------------
#define RVTEST_PASS                                                     \
    li  x1, 1;                                                          \
    la  x2, tohost;                                                     \
    sw  x1, 0(x2);                                                      \
1:  j   1b;                                                             \

// -----------------------------------------------------------------------
// RVTEST_FAIL  --  bao FAIL: ghi (TESTNUM<<1)|1 vao tohost roi dung lai
// -----------------------------------------------------------------------
#define RVTEST_FAIL                                                     \
    slli x1, TESTNUM, 1;                                                \
    ori  x1, x1, 1;                                                     \
    la   x2, tohost;                                                    \
    sw   x1, 0(x2);                                                     \
1:  j    1b;                                                            \

#endif // _ENV_PHYSICAL_SINGLE_CORE_H

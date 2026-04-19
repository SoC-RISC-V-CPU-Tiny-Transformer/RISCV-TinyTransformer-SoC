// -----------------------------------------------------------------------------
// main.c — Test program for RISC-V 32-bit SoC verification
//
// Exercises: ALU arithmetic, loops (BNE/BLT), conditionals (BGE),
//            word load/store (LW/SW), stack-allocated arrays.
//
// Results written to RESULT_BASE = 0x2000 so the testbench can verify
// them by calling mem_model.read_word(addr).
//
// Expected results:
//   [0] 0x2000 = 55     sum 1..10
//   [1] 0x2004 = 55     fibonacci f(10)
//   [2] 0x2008 = 256    2^8 via doubling loop
//   [3] 0x200C = 9      max of {3,1,4,1,5,9,2,6}
// -----------------------------------------------------------------------------

#define RESULT_BASE 0x2000U

typedef volatile unsigned int vu32;

static inline void store_result(unsigned int idx, unsigned int val) {
    *((vu32 *)(RESULT_BASE + idx * 4)) = val;
}

void main(void) {
    unsigned int i, sum, a, b, tmp;

    // --- Test 0: sum of 1..10 = 55 ---
    // Exercises: ADDI, BNE loop, ADD accumulate, SW
    sum = 0;
    for (i = 1; i <= 10; i++)
        sum += i;
    store_result(0, sum);
    
    // --- Test 1: Fibonacci f(10) = 55 ---
    // Exercises: multiple ADD, register moves, BLT loop
    a = 0; b = 1;
    for (i = 2; i <= 10; i++) {
        tmp = a + b;
        a   = b;
        b   = tmp;
    }
    store_result(1, b);

    // --- Test 2: 2^8 = 256 via doubling loop ---
    // Exercises: ADD rd, rs, rs (same register), BNE
    a = 1;
    for (i = 0; i < 8; i++)
        a = a + a;
    store_result(2, a);

    // --- Test 3: max of array {3,1,4,1,5,9,2,6} = 9 ---
    // Exercises: SW/LW (stack array), BLTU/BGEU conditional branch
    unsigned int arr[8] = {3, 1, 4, 1, 5, 9, 2, 6};
    unsigned int max = 0;
    for (i = 0; i < 8; i++) {
        if (arr[i] > max)
            max = arr[i];
    }
    store_result(3, max);
}

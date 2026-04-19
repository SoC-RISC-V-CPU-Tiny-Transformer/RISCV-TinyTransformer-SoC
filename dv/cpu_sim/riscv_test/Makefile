# =============================================================================
# Makefile -- Build riscv-tests rv32ui-p suite cho Advanced RISC-V 32-bit SoC
#
# Su dung:
#   make all      -- compile tat ca tests, tao .elf va .mem
#   make clean    -- xoa thu muc build/
#   make dump     -- dump disassembly cua tat ca tests (debug)
#
# Yeu cau: riscv64-unknown-elf-gcc (Ubuntu package: gcc-riscv64-unknown-elf)
# =============================================================================

# --- Toolchain ---
GCC     := riscv64-unknown-elf-gcc
OBJCOPY := riscv64-unknown-elf-objcopy
OBJDUMP := riscv64-unknown-elf-objdump
PYTHON  := python3

# --- Paths ---
TESTS_DIR := isa/rv32ui
MACROS    := isa/macros/scalar
ENV_P     := env/p
BUILD     := build

# --- GCC flags ---
CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -static -fno-pic \
          -I$(ENV_P) -I$(MACROS) -T$(ENV_P)/link.ld

# --- Danh sach test (khop voi Makefrag) ---
TESTS := simple \
         add addi \
         and andi \
         auipc \
         beq bge bgeu blt bltu bne \
         fence_i \
         jal jalr \
         lb lbu lh lhu lw ld_st \
         lui \
         ma_data \
         or ori \
         sb sh sw st_ld \
         sll slli \
         slt slti sltiu sltu \
         sra srai \
         srl srli \
         sub \
         xor xori

# --- Skip list: cac test can CSR / misalignment exception trap ---
# fence_i can Zifencei; ma_data can misalignment exception handler (mtvec)
# -> skip o buoc nay, SoC chua co CSR
SKIP := fence_i ma_data ld_st st_ld

RUNNABLE := $(filter-out $(SKIP), $(TESTS))

# --- Target file lists ---
ELFS := $(patsubst %, $(BUILD)/rv32ui-p-%.elf, $(RUNNABLE))
MEMS := $(patsubst %, $(BUILD)/rv32ui-p-%.mem, $(RUNNABLE))

# --- Default target ---
.PHONY: all clean dump list

all: $(BUILD) $(MEMS)
	@echo ""
	@echo "=========================================="
	@echo " Build xong: $(words $(MEMS)) test(s)"
	@echo " Output: $(BUILD)/*.mem"
	@echo "=========================================="

# --- Tao thu muc build ---
$(BUILD):
	mkdir -p $(BUILD)

# --- Compile .S -> .elf ---
$(BUILD)/rv32ui-p-%.elf: $(TESTS_DIR)/%.S $(ENV_P)/riscv_test.h $(ENV_P)/link.ld
	$(GCC) $(CFLAGS) $< -o $@

# --- Convert .elf -> .bin -> .mem (Vivado $readmemh format) ---
# Moi dong = 1 word (4 bytes), hex, little-endian (LSB first)
# $readmemh doc theo dia chi tang dan, moi dong la 1 entry
$(BUILD)/rv32ui-p-%.mem: $(BUILD)/rv32ui-p-%.elf
	$(OBJCOPY) -O binary --gap-fill 0x00 $< $(BUILD)/rv32ui-p-$*.bin
	$(PYTHON) $(ENV_P)/bin2mem.py $(BUILD)/rv32ui-p-$*.bin $@

# --- Dump disassembly (debug) ---
dump: $(ELFS)
	@for f in $(ELFS); do \
	    echo "=== $$f ==="; \
	    $(OBJDUMP) -d $$f; \
	done

# --- List tests ---
list:
	@echo "RUNNABLE tests ($(words $(RUNNABLE))):"
	@echo "$(RUNNABLE)" | tr ' ' '\n' | nl

# --- Clean ---
clean:
	rm -rf $(BUILD)

CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

# -march=rv32i  : base integer ISA only (no M/A/F/D)
# -mabi=ilp32   : 32-bit int/long/pointer, no FP registers
# -O1           : light optimisation (keeps all stores, removes dead code)
# -nostdlib     : no libc / startup from newlib
# -ffreestanding: do not assume standard library exists
CFLAGS  = -march=rv32i -mabi=ilp32 -O1 -nostdlib -ffreestanding -Wall

SRCS    = startup.S main.c
TARGET  = program

all: $(TARGET).mem $(TARGET).dump
	@echo "Build complete → $(TARGET).mem ready for testbench"

$(TARGET).elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(SRCS) -o $@

# Raw binary (address 0x0 → byte 0 of file)
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Hex file for $readmemh — one byte per line
# axi_slave_model: logic [7:0] mem [0:MEM_SIZE-1]
$(TARGET).mem: $(TARGET).bin
	xxd -p -c 1 $< > $@

# Human-readable disassembly for debugging
$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -M numeric $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).mem $(TARGET).dump

.PHONY: all clean

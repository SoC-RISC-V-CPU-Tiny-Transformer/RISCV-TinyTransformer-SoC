#!/usr/bin/env python3
"""
bin2mem.py  --  Convert raw binary sang Vivado $readmemh format

axi_slave_model dung mang byte:  logic [7:0] mem [0:MEM_SIZE-1]
$readmemh voi mang byte phai co 1 byte (2 hex digit) moi dong.

Vi du: instruction lui sp,0xF = bytes [0x37, 0xF1, 0x00, 0x00] (little-endian)
  -> 4 dong:
       37
       f1
       00
       00

Byte o dia chi thap nhat duoc ghi truoc (little-endian trong memory).

Su dung:
  python3 bin2mem.py input.bin output.mem
"""

import sys

def bin2mem(infile: str, outfile: str) -> None:
    with open(infile, "rb") as f:
        data = f.read()

    with open(outfile, "w") as f:
        for byte in data:
            f.write(f"{byte:02x}\n")

    print(f"[bin2mem] {infile} -> {outfile}  ({len(data)} bytes)")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.mem>")
        sys.exit(1)
    bin2mem(sys.argv[1], sys.argv[2])

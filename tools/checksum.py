#fix SNES internal checksum
import sys

path = sys.argv[1]
rom = bytearray(open(path, "rb").read())
rom[0x7FDC:0x7FE0] = b"\xFF\xFF\x00\x00"

base = 1
while base * 2 <= len(rom):
    base *= 2
rest = rom[base:]
if rest:
    rest = rest * (base // len(rest))
total = (sum(rom[:base]) + sum(rest)) & 0xFFFF

rom[0x7FDC:0x7FDE] = (total ^ 0xFFFF).to_bytes(2, "little")
rom[0x7FDE:0x7FE0] = total.to_bytes(2, "little")
open(path, "wb").write(rom)

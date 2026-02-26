riscv32-unknown-elf-gcc -c main.c -ffreestanding -fno-builtin
riscv32-unknown-elf-ld -T ../../common/neorv32.ld \
    --just-symbols ../forensic/main.elf \
    --defsym=__neorv32_rom_base=0x1f7e8 \
    --defsym=__neorv32_ram_base=0x80006000 \
    --defsym=__neorv32_rom_size=0x3e8 \
    --defsym=__neorv32_ram_size=0x2000 \
    -o payload.elf main.o

# base ROM is 129_000, and size is 1000, because 
# the ROM in hardware has 130_000 locations

riscv32-unknown-elf-objcopy -O binary payload.elf payload.bin
riscv32-unknown-elf-objdump -sSD payload.elf > payload.dump

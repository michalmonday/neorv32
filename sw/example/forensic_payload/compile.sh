riscv32-unknown-elf-gcc -c main.c -ffreestanding -fno-builtin
riscv32-unknown-elf-ld -T ../../common/neorv32.ld \
    --just-symbols ../forensic/main.elf \
    --defsym=__neorv32_rom_base=0x30000 \
    --defsym=__neorv32_ram_base=0x80008000 \
    --defsym=__neorv32_rom_size=0x8000 \
    --defsym=__neorv32_ram_size=0x8000 \
    -o test.elf main.o
riscv32-unknown-elf-objcopy -O binary test.elf test.bin
riscv32-unknown-elf-objdump -sSD test.elf > test.dump
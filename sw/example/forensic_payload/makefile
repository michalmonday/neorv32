# Application makefile.
# Use this makefile to configure all relevant CPU / compiler options.

# Override the default CPU ISA
MARCH = rv32i_zicsr_zifencei

# Override the default RISC-V GCC prefix
#RISCV_PREFIX ?= riscv-none-elf-

# Override default optimization goal
EFFORT = -Os

# Add extended debug symbols
USER_FLAGS += -ggdb -gdwarf-3

# Adjust processor IMEM size
# USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=256k
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=8k

# Adjust processor DMEM size
# USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=128k
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=32k

# These need to be changed, the original program is 112K in size.
# So placing the second one at 192K (0xFFF50000) should be safe 
# because the binary is only 572 bytes.
USER_FLAGS += -Wl,--defsym,__neorv32_rom_base=0x30000 -Wl,--defsym,__neorv32_ram_base=0x80030000

# __neorv32_rom_base = DEFINED(__neorv32_rom_base) ? __neorv32_rom_base : 0x00000000;
# __neorv32_ram_base = DEFINED(__neorv32_ram_base) ? __neorv32_ram_base : 0x80000000;

# Adjust maximum heap size
#USER_FLAGS += -Wl,--defsym,__neorv32_heap_size=1k

# Additional sources
#APP_SRC += $(wildcard ./*.c)
#APP_INC += -I .

# Set path to NEORV32 root directory
NEORV32_HOME ?= ../../..

# Include the main NEORV32 makefile
include $(NEORV32_HOME)/sw/common/common.mk

sim-check: sim
	cat $(NEORV32_HOME)/sim/neorv32.uart0.log | grep "Hello world! :)"

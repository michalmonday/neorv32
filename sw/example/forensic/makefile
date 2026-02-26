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
# USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=190k
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=120k

# Adjust processor DMEM size
# USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=256k
# USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=32k
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=24k

USER_FLAGS += -Wl,-u,neorv32_spi_available -Wl,-u,neorv32_spi_setup -Wl,-u,neorv32_spi_disable -Wl,-u,neorv32_spi_cs_en -Wl,-u,neorv32_spi_transfer

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

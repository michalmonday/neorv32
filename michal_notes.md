
```bash
make clean_all sim GHDL_RUN_FLAGS+=" --wave=demo_blink_led.ghw --stop-time=500us" USER_FLAGS+=-DUART0_SIM_MODE

# without USER_FLAGS and with encryption
make clean_all sim GHDL_RUN_FLAGS+=" --wave=coremark.ghw --stop-time=2us" ENCRYPT_BIN_MAIN=1
```

Using USER_FLAGS from command line overrides completely the USER_FLAGS from make file (e.g. in case of coremark, so it should not be used in that case, the makefile should be modified instead to add a flag)


# Changes for instruction set randomisation
* Created `neorv32_instruction_set_randomisation.vhd` and added it in the `rtl/file_list_soc.f`
* Added `instruction_set_randomisation_key` port in `neorv32_top.vhd` and `neorv32_mem.vhd`.   
* modified neorv32_mem (isr module is implemented inside it)    
* removed "c" extension in compilation (coremark makefile)   
* added ENCRYPT_BIN_MAIN option in `sw/common/common.mk` file  
* created tools/encrypt_bin.py and `tools/key_file` (storing the key "AAAA" -> 0x41414141)   
* `neorv32_top` module component had to be modified in `neorv32_package.vhd`  
* Added `rtl/isr_related` directory with some helper modules (`io_buf_for_i2c.vhd`, `shift_register.vhd`)  
* Modified bootloader to avoid stopping when signature of uploaded binary doesn't match:  

```cpp
    // signature OK?
    if (exe_sign != EXE_SIGNATURE) {
      uart_puts("ERROR_SIGNATURE (but allowing to run because of instruction set randomisation)\n");
      // return 1;
    }
```


Example running coremark:  
```bash
cd sw/examples/coremark
make clean_all image
sudo python3 ../../../tools/upload_through_bootloader.py build/main.bin
```
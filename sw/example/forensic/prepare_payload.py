
import subprocess
import os
import sys

def execute_and_read_cmd(cmd):
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"Error executing command: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def get_func_address(func_name, elf_name='main.elf'):
    cmd = f"riscv32-unknown-elf-nm {elf_name} | grep {func_name}"
    output = execute_and_read_cmd(cmd)
    if not output:
        print(f"Function {func_name} not found in {elf_name}")
        sys.exit(1)
    return int(output.split()[0], 16)

if __name__ == "__main__":
    funcs_to_find = ["neorv32_rte_setup"]
    
    for func in funcs_to_find:
        address = get_func_address(func)
        print(f"{func}: 0x{address:X}")


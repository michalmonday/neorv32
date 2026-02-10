def generate_jal_instr(offset, rd=1):
    opcode = 0x6F  # 1101111

    if offset & 1:
        raise ValueError("JAL offset must be 2-byte aligned")

    # keep only 21 bits (two's complement for negative values)
    imm = offset & 0x1FFFFF

    imm_20    = (imm >> 20) & 0x1
    imm_10_1  = (imm >> 1)  & 0x3FF
    imm_11    = (imm >> 11) & 0x1
    imm_19_12 = (imm >> 12) & 0xFF

    jal_instr = (
        (imm_20 << 31) |
        (imm_10_1 << 21) |
        (imm_11 << 20) |
        (imm_19_12 << 12) |
        (rd << 7) |
        opcode
    )
    return jal_instr

# original call to barcode_str_to_num
# src = 0x86c 
src = 0x738 

# address of barcode_str_to_num_hooked
dst = 0x30000

offset = dst - src

jal_instruction = generate_jal_instr(offset, rd=1)
print(f"JAL instruction (hex): 0x{jal_instruction:08X}")

# result is 0x7942F0EF

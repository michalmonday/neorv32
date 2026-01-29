-- ================================================================================ --
-- NEORV32 CPU - Data Register File                                                 --
-- -------------------------------------------------------------------------------- --
-- Data register file. 32 entries (= 1024 bit) for RV32I ISA (default), 16 entries  --
-- (= 512 bit) for RV32E ISA (when RISC-V "E" extension is enabled via "RVE_EN").   --
--                                                                                  --
-- By default the register file is coded to infer block RAM (for FPGAs), that does  --
-- not provide a dedicated hardware reset. For ASIC implementation or setups that   --
-- do require a dedicated hardware reset a flip-flop-based architecture can be      --
-- enabled via "RST_EN".                                                            --
--                                                                                  --
-- [NOTE] Read-during-write behavior of the register file's memory core is          --
--        irrelevant as read and write accesses are mutually exclusive and will     --
--        never happen at the same time.                                            --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cpu_regfile is
  generic (
    RST_EN : boolean; -- implement dedicated hardware reset ("ASIC style")
    RVE_EN : boolean; -- implement embedded RF extension
    RS3_EN : boolean;  -- implement 3rd read port
    INSTRUCTION_SET_RANDOMISATION_EN : boolean := false 
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic; -- global clock, rising edge
    rstn_i : in  std_ulogic; -- global reset, low-active, async
    ctrl_i : in  ctrl_bus_t; -- main control bus
    -- operands --
    rd_i   : in  std_ulogic_vector(XLEN-1 downto 0); -- destination operand rd
    rs1_o  : out std_ulogic_vector(XLEN-1 downto 0); -- source operand rs1
    rs2_o  : out std_ulogic_vector(XLEN-1 downto 0); -- source operand rs2
    rs3_o  : out std_ulogic_vector(XLEN-1 downto 0);  -- source operand rs3
    instruction_set_randomisation_key : in  std_ulogic_vector(127 downto 0)
  );
end neorv32_cpu_regfile;

architecture neorv32_cpu_regfile_rtl of neorv32_cpu_regfile is

  -- auto-configuration --
  constant addr_bits_c : natural := cond_sel_natural_f(RVE_EN, 4, 5); -- address width

  -- register file --
  type   reg_file_t is array ((2**addr_bits_c)-1 downto 0) of std_ulogic_vector(XLEN-1 downto 0);
  signal reg_file : reg_file_t;

  -- access --
  signal rf_we    : std_ulogic; -- write enable
  signal rd_zero  : std_ulogic; -- writing to x0?
  signal opa_addr : std_ulogic_vector(4 downto 0); -- rs1/rd address
  signal rs3_addr : std_ulogic_vector(4 downto 0); -- rs3 address

  signal isr_block_i : std_ulogic_vector(127 downto 0) := (others => '0');
  signal rd_i_encrypted : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
  signal rs1_o_decrypted : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
  signal rs2_o_decrypted : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
  signal rs3_o_decrypted : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');

begin

  -- FPGA-Style Register File (BlockRAM, no hardware reset at all) --------------------------
  -- -------------------------------------------------------------------------------------------
  register_file_fpga:
  if not RST_EN generate

    -- Register zero (x0) is a "normal" physical register that is set to zero by the CPU control
    -- hardware. The register file uses synchronous read accesses and a *single* multiplexed
    -- address port for writing and reading rd/rs1 and a single read-only port for reading rs2.
    -- Therefore, the whole register file can be mapped to a single true-dual-port block RAM.

    rd_zero  <= '1' when (ctrl_i.rf_rd = "00000") else '0';
    rf_we    <= (ctrl_i.rf_wb_en and (not rd_zero)) or ctrl_i.rf_zero_we; -- never write to x0 unless explicitly forced
    opa_addr <= "00000" when (ctrl_i.rf_zero_we = '1') else -- force rd = zero
                ctrl_i.rf_rd when (ctrl_i.rf_wb_en = '1') else -- rd
                ctrl_i.rf_rs1; -- rs1

    register_file: process(clk_i)
    begin
      if rising_edge(clk_i) then
        if (rf_we = '1') then
          if (opa_addr /= "00000") then -- do not write to x0
            reg_file(to_integer(unsigned(opa_addr(addr_bits_c-1 downto 0)))) <= rd_i_encrypted;
          end if;
        end if;
        rs1_o <= reg_file(to_integer(unsigned(opa_addr(addr_bits_c-1 downto 0))));
        rs2_o <= reg_file(to_integer(unsigned(ctrl_i.rf_rs2(addr_bits_c-1 downto 0))));
      end if;
    end process register_file;

  end generate; -- /register_file_fpga


  -- ASIC-Style Register File (individual FFs, full hardware reset) -------------------------
  -- -------------------------------------------------------------------------------------------
  register_file_asic:
  if RST_EN generate

    -- individual registers --
    reg_gen:
    for i in 1 to (2**addr_bits_c)-1 generate
      register_file: process(rstn_i, clk_i)
      begin
        if (rstn_i = '0') then
          reg_file(i) <= (others => '0'); -- full hardware reset
        elsif rising_edge(clk_i) then
          if (unsigned(ctrl_i.rf_rd(addr_bits_c-1 downto 0)) = to_unsigned(i, addr_bits_c)) and (ctrl_i.rf_wb_en = '1') then
            reg_file(i) <= rd_i_encrypted;
          end if;
        end if;
      end process register_file;
    end generate;

    -- x0 is hardwired to zero --
    reg_file(0) <= (others => '0');

    -- synchronous read --
    rf_read: process(rstn_i, clk_i)
    begin
      if (rstn_i = '0') then
        rs1_o <= (others => '0');
        rs2_o <= (others => '0');
      elsif rising_edge(clk_i) then
        -- rs1_o <= reg_file(to_integer(unsigned(ctrl_i.rf_rs1(addr_bits_c-1 downto 0))));
        -- rs2_o <= reg_file(to_integer(unsigned(ctrl_i.rf_rs2(addr_bits_c-1 downto 0))));
        rs1_o <= rs1_o_decrypted;
        rs2_o <= rs2_o_decrypted;
      end if;
    end process rf_read;

  end generate; -- /register_file_asic


  -- Optional Third Read Port (rs3) ---------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  rs3_enabled:
  if RS3_EN generate
    rs3_read: process(clk_i)
    begin
      if rising_edge(clk_i) then
        rs3_o <= reg_file(to_integer(unsigned(rs3_addr(addr_bits_c-1 downto 0))));
      end if;
    end process rs3_read;
  end generate;

  rs3_disabled:
  if not RS3_EN generate
    rs3_o <= (others => '0');
  end generate;

  -- RISC-V rs3 operand --
  rs3_addr <= ctrl_i.ir_funct12(11 downto 7);

  isr_enabled_enc:
  if INSTRUCTION_SET_RANDOMISATION_EN generate
    instruction_set_randomisation_instance_enc : entity neorv32.neorv32_instruction_set_randomisation
      GENERIC MAP (
          DECRYPTION_TYPE => XOR_DEC
      )
      PORT MAP (
              clk => clk_i,
              rst_n => rstn_i, -- not reset and not instruction_set_randomisation_reset,
              instruction_set_randomisation_key => instruction_set_randomisation_key,
              i_instruction => rd_i,
              -- i_block => rom_output_block_for_ascon,
              i_block => isr_block_i,

              -- begin_decryption should be set to 1 when the instruction is ready to be decrypted
              -- for simple XOR decryption (that uses combinational logic) it can always be 1 
              -- for ascon implementation, it should be set to 1 only when module is not already busy decrypting
              -- begin_decryption => instruction_set_randimisation_begin_decryption,
              begin_decryption => '1',
              -- program counter is 32 bits, opa_addr is only 5 bits, so we need to concatinate 0s
              program_counter => "000000000000000000000000000" & opa_addr,
              o_instruction => rd_i_encrypted,
              -- decryption_done => instruction_set_randimisation_decryption_done -- if this is 0, then CPU should wait until the instruction is decrypted
              decryption_done => open -- if this is 0, then CPU should wait until the instruction is decrypted
          );
  end generate;

  isr_enabled_dec_rs1:
  if INSTRUCTION_SET_RANDOMISATION_EN generate
    rs1_o_decrypted <= reg_file(to_integer(unsigned(opa_addr(addr_bits_c-1 downto 0)))) xor instruction_set_randomisation_key(31 downto 0) xor "000000000000000000000000000" & ctrl_i.rf_rs1(4 downto 0);
  --   instruction_set_randomisation_instance_dec_rs1 : entity neorv32.neorv32_instruction_set_randomisation
  --     GENERIC MAP (
  --         DECRYPTION_TYPE => XOR_DEC
  --     )
  --     PORT MAP (
  --             clk => clk_i,
  --             rst_n => rstn_i, -- not reset and not instruction_set_randomisation_reset,
  --             instruction_set_randomisation_key => instruction_set_randomisation_key,
  --             i_instruction => reg_file(to_integer(unsigned(opa_addr(addr_bits_c-1 downto 0)))),
  --             i_block => isr_block_i,
  --             begin_decryption => '1',
  --             program_counter => "000000000000000000000000000" & ctrl_i.rf_rs1(4 downto 0),
  --             o_instruction => rs1_o_decrypted,
  --             decryption_done => open -- if this is 0, then CPU should wait until the instruction is decrypted
  --         );
  end generate;

  isr_enabled_dec_rs2:
  if INSTRUCTION_SET_RANDOMISATION_EN generate
    rs2_o_decrypted <= reg_file(to_integer(unsigned(ctrl_i.rf_rs2(addr_bits_c-1 downto 0)))) xor instruction_set_randomisation_key(63 downto 32) xor "000000000000000000000000000" & ctrl_i.rf_rs2(4 downto 0);
  --   instruction_set_randomisation_instance_dec_rs2 : entity neorv32.neorv32_instruction_set_randomisation
  --     GENERIC MAP (
  --         DECRYPTION_TYPE => XOR_DEC
  --     )
  --     PORT MAP (
  --             clk => clk_i,
  --             rst_n => rstn_i, -- not reset and not instruction_set_randomisation_reset,
  --             instruction_set_randomisation_key => instruction_set_randomisation_key,
  --             i_instruction => reg_file(to_integer(unsigned(ctrl_i.rf_rs2(addr_bits_c-1 downto 0)))),
  --             i_block => isr_block_i,
  --             begin_decryption => '1',
  --             program_counter => "000000000000000000000000000" & ctrl_i.rf_rs2(4 downto 0),
  --             o_instruction => rs2_o_decrypted,
  --             decryption_done => open -- if this is 0, then CPU should wait until the instruction is decrypted
  --         );
  end generate;

end neorv32_cpu_regfile_rtl;

-- this module will allow to use AXI GPIO (that has 2x 32 bit channels)
-- to transfer the 128-bit key from the co-processor (ARM) to the 
-- neorv32 RISC-V processor

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shift_register is
  port (
    clk       : in  std_logic;
    data_in   : in  std_logic_vector(31 downto 0);
    shift_en  : in  std_logic;
    latch     : in  std_logic;
    data_out  : out std_logic_vector(127 downto 0)
  );
end entity shift_register;

architecture behavioral of shift_register is
  signal data_out_r : std_logic_vector(127 downto 0) := (others => '0');
  signal last_shift_en : std_logic := '0';
  signal last_latch : std_logic := '0';
begin
  process(clk, latch, shift_en)
  begin
    if rising_edge(clk) then
        last_shift_en <= shift_en;
        last_latch <= latch;
        if last_shift_en = '0' and shift_en = '1' then
            data_out_r <= data_out_r(95 downto 0) & data_in;
        end if;

        if last_latch = '0' and latch = '1' then
            data_out <= data_out_r;
        end if;
    end if;
  end process;

end architecture behavioral;

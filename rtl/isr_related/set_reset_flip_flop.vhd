
library ieee;
use ieee.std_logic_1164.all;

entity set_reset_flip_flop is
  port (
    clk_i   : in  std_ulogic;  -- clock input
    resetn_i : in  std_ulogic;  -- reset input (active low)
    reset2_i : in  std_ulogic;  -- reset input (active low)
    set_i   : in  std_ulogic;  -- set input (active high)
    q_o     : out std_ulogic   -- flip-flop output
  );
end set_reset_flip_flop;

architecture rtl of set_reset_flip_flop is

  signal q_r : std_ulogic := '0';
begin
    process(clk_i, resetn_i, reset2_i)
    begin
        if (resetn_i = '0' or reset2_i = '1') then
            q_r <= '0';
            elsif rising_edge(clk_i) then
            if (set_i = '1') then
                q_r <= '1';
            end if;
        end if;
    end process;
    q_o <= q_r;
    
end rtl;
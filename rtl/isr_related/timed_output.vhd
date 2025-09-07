
-- this module is used for chameleon demo
-- it gets input from neorv32 (cfs output conduit) and passes it to the outside world 
-- (to control MOSFET driving an engine)
-- it has a timer to turn off the output if it does not get refreshed often enough

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity timed_output is
  generic (
    TIMEOUT_CYCLES : integer := 100000000 -- number of clock cycles after which the output is turned off if not refreshed
  );
  port (
    clk_i     : in  std_ulogic; -- global clock line
    sig       : in  std_ulogic; -- input signal from neorv32 (cfs output conduit)
    out_o     : out std_ulogic -- output to outside world (to control MOSFET)
  );
end entity timed_output;

architecture rtl of timed_output is

  signal counter : integer := 0;
  signal last_sig_r: std_ulogic := '0';
begin
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- detect rising edge of sig
            -- this way even if the sig is kept high (when the CPU stops working)
            -- the output will be turned off after TIMEOUT_CYCLES
            last_sig_r <= sig;
            if last_sig_r = '0' and sig = '1' then
                counter <= 0;
            else
                if counter < TIMEOUT_CYCLES then
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    out_o <= '1' when (counter < TIMEOUT_CYCLES) else '0';
    
    end architecture rtl;
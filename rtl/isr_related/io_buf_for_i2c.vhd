
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.VComponents.all;

entity io_buf_for_i2c is
  port (
    sda_o, sda_t : in std_logic;
    scl_o, scl_t : in std_logic;
    scl_i, sda_i : out std_logic;

    sda : inout std_logic;
    scl : inout std_logic
  );
end entity io_buf_for_i2c;

architecture behavioral of io_buf_for_i2c is
begin
  u0 : IOBUF port map(
            I    => sda_o,
            O    => sda_i,
            T    => sda_t,
            IO   => sda
        );

   u1 : IOBUF port map(
            I    => scl_o,
            O    => scl_i,
            T    => scl_t,
            IO   => scl
        );

    -- u0 : entity work.iobuf
    --     port map (
    --         I    => sda_i,
    --         O    => sda_o,
    --         T    => sda_t,
    --         IO   => sda
    --     );

    -- u1 : entity work.iobuf
    --     port map (
    --         I    => scl_i,
    --         O    => scl_o,
    --         T    => scl_t,
    --         IO   => scl
    --     );
end architecture behavioral;

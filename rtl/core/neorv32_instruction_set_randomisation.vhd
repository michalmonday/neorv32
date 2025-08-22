library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_instruction_set_randomisation is
    Generic (
        DECRYPTION_TYPE : isr_decryption_t := XOR_DEC -- NONE, ASCON_DEC, XOR_DEC
    );
    Port (
        clk    : in  std_ulogic;
        rst_n  : in  std_ulogic; 
        program_counter : in  std_ulogic_vector(31 downto 0); 
        instruction_set_randomisation_key : in  std_ulogic_vector(127 downto 0); 
        i_instruction : in  std_ulogic_vector(31 downto 0); 
        i_block : in std_ulogic_vector(127 downto 0); 
        begin_decryption : in std_ulogic; -- the user (parent module) will set this to 1 when the instruction is ready to be decrypted
        o_instruction : out std_ulogic_vector(31 downto 0);
        decryption_done : out std_ulogic -- the module will set this to 1 when the instruction was decrypted and is ready to be used
    );
end neorv32_instruction_set_randomisation;

architecture Behavioral of neorv32_instruction_set_randomisation is
    function scramble(input : std_ulogic_vector) return std_ulogic_vector is
        variable val : integer := to_integer(unsigned(input));
    begin
        return std_ulogic_vector(to_unsigned((val * 7901) mod 65536, 32));
    end function;

    -- signal dummy_test_counter : unsigned(3 downto 0) := (others => '0');
    -- signal ascon_input_block : std_ulogic_vector(127 downto 0) := (others => '0');
    signal ascon_output_block : std_ulogic_vector(127 downto 0);
    signal ascon_decryption_done : std_ulogic;
    signal ascon_tag_out : std_ulogic_vector(127 downto 0);
    signal ascon_output_block_valid : std_ulogic;
    signal ascon_block_address : std_ulogic_vector(31 downto 0);
    signal ascon_key : std_ulogic_vector(127 downto 0) := (others => '0');
    signal ascon_nonce : std_ulogic_vector(127 downto 0) := (others => '0');

    signal ascon_output_block_instr_index : unsigned(4 downto 0) := (others => '0');

    -- encryption_in_progress will allow to prolong the "begin_decryption" signal until the previous decryption is done
    signal encryption_in_progress : std_ulogic := '0'; 
    signal decryption_requested : std_ulogic := '0'; 
    signal begin_decryption_override, last_begin_decryption_override : std_ulogic := '0';

    signal rst_n_override : std_ulogic := '1';

    signal ascon_tag_done : std_ulogic := '0'; -- this indicates tag generation is done, the decryption of the first block is done before that
begin
    -- simple XOR decryption using combinational logic only
    gen_NONE: if DECRYPTION_TYPE = NONE generate
        o_instruction <= i_instruction;
        decryption_done <= '1';
    end generate;

    gen_XOR: if DECRYPTION_TYPE = XOR_DEC generate
        -- o_instruction <= i_instruction xor scramble(program_counter) xor scramble(instruction_set_randomisation_key);
        o_instruction <= i_instruction xor program_counter xor instruction_set_randomisation_key(31 downto 0);
        decryption_done <= '1';
        -- Testing the decryption_done signal handling by the parent module:
        -- process (clk)
        -- begin
        --     if rising_edge(clk) then
        --         dummy_test_counter <= dummy_test_counter + 1; 
        --         if dummy_test_counter = "1111" then
        --             decryption_done <= '1'; 
        --         else
        --             decryption_done <= '0'; 
        --         end if;
        --     end if;
        -- end process;
    end generate;

    -- gen_ASCON: if DECRYPTION_TYPE = ASCON_DEC generate

    --     -- o_instruction <= ascon_output_block(9 downto 0); 
    --     ascon_output_block_instr_index <= unsigned(program_counter) mod 8; -- this is the index of the instruction in the output block
    --     -- o_instruction <= ascon_output_block(ascon_output_block_instr_index * 16 downto ascon_output_block_instr_index * 16 - 16); 
    --     o_instruction <= ascon_output_block(127 downto 112) when ascon_output_block_instr_index = 7 else
    --                         ascon_output_block(111 downto 96) when ascon_output_block_instr_index = 6 else
    --                         ascon_output_block(95 downto 80) when ascon_output_block_instr_index = 5 else
    --                         ascon_output_block(79 downto 64) when ascon_output_block_instr_index = 4 else
    --                         ascon_output_block(63 downto 48) when ascon_output_block_instr_index = 3 else
    --                         ascon_output_block(47 downto 32) when ascon_output_block_instr_index = 2 else
    --                         ascon_output_block(31 downto 16) when ascon_output_block_instr_index = 1 else
    --                         ascon_output_block(15 downto 0) when ascon_output_block_instr_index = 0 else
    --                         (others => '0'); -- default value if none of the above conditions are met

    --     decryption_done <= ascon_decryption_done;

    --     -- https://github.com/michalmonday/ascon_implementation
    --     -- ascon_input_block <= (127 downto 10 => '0') & i_instruction; 
    --     ascon_decryption_done <= ascon_output_block_valid;
    --     ascon_nonce <= (127 downto 5 => '0') & std_ulogic_vector(unsigned(program_counter)/8); -- nonce is the block index

    --     ascon_u0 : entity work.ascon generic map (
    --         PERMUTATIONS_PER_CYCLE_INITIALISATION => 3,
    --         PERMUTATIONS_PER_CYCLE_MAIN => 2,
    --         PERMUTATIONS_PER_CYCLE_FINALISATION => 3
    --     ) port map (
    --         clk => clk,
    --         rst_n => rst_n or rst_n_override, 
    --         start => begin_decryption or last_begin_decryption_override, -- start current operation (encryption or decryption)
    --         operation => '1', --  0 for encryption, 1 for decryption
    --         key => ascon_key,
    --         nonce => ascon_nonce, 
    --         input_block => i_block,
    --         blocks_to_process => std_ulogic_vector(to_unsigned(1, 32)),
    --         output_block_valid => ascon_output_block_valid, 
    --         block_address => ascon_block_address,
    --         output_block => ascon_output_block, 
    --         tag_out => ascon_tag_out, 
    --         done => ascon_tag_done -- this indicates tag generation is done, the decryption of the first block is done before that
    --     ); 

    --     -- process to handle what happens when begin_decryption is triggered 
    --     -- before previous decryption (including tag generation) is fully done.
    --     -- It resets the ascon module and sets overrides the start signal on the next clock cycle
    --     -- just after the last tag generation is done.
    --     -- Does not support queueing (just a single prolonged decryption request).
    --     process(clk)
    --     begin
    --         if rising_edge(clk) then
    --             last_begin_decryption_override <= begin_decryption_override;
    --             if begin_decryption = '1' then
    --                 encryption_in_progress <= '1'; 
    --                 if encryption_in_progress = '1' then
    --                     decryption_requested <= '1'; 
    --                 else
    --                     decryption_requested <= '0'; 
    --                 end if;
    --             end if;
    --             if ascon_tag_done = '1' then
    --                 if decryption_requested = '1' then 
    --                     rst_n_override <= '0';
    --                     begin_decryption_override <= '1';
    --                     encryption_in_progress <= '1';
    --                 else 
    --                     rst_n_override <= '1';
    --                     begin_decryption_override <= '0';
    --                     encryption_in_progress <= '0';
    --                 end if;
    --             else
    --                 rst_n_override <= '1';
    --                 begin_decryption_override <= '0';
    --             end if;
    --         end if;
    --     end process;
    -- end generate;

end Behavioral;
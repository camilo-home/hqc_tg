library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poly_mul is
generic(
    WT         : integer := 3;   -- Número de elementos no nulos en el vector disperso
    WORD_COUNT : integer := 553  -- Palabras de 32 bits por vector (ej. 17669 bits / 32 ≈ 553)
);
port(
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;

    -- Memoria de posiciones (Vector disperso)
    pos_addr : out unsigned(6 downto 0);
    pos_data : in  unsigned(14 downto 0);

    -- Memoria densa
    dense_addr : out unsigned(9 downto 0);
    dense_data : in  std_logic_vector(31 downto 0);

    -- Acumulador BRAM (Espacio de memoria de 2 * WORD_COUNT palabras)
    acc_addr_a : out unsigned(10 downto 0);
    acc_addr_b : out unsigned(10 downto 0);

    acc_din_a  : out std_logic_vector(31 downto 0);
    acc_din_b  : out std_logic_vector(31 downto 0);

    acc_dout_a : in  std_logic_vector(31 downto 0);
    acc_dout_b : in  std_logic_vector(31 downto 0);

    acc_we_a   : out std_logic;
    acc_we_b   : out std_logic;

    done : out std_logic
);
end entity;

architecture rtl of poly_mul is

    type state_t is (
        IDLE,
        LOAD_POS,
        WAIT_POS,
        SET_ADDR,
        WAIT_READ,
        WRITE_BACK,
        NEXT_WORD,
        NEXT_POS,
        -- Estados de la fase de reducción (Plegado XOR)
        REDUCE_SET_ADDR,
        REDUCE_WAIT_READ,
        REDUCE_WRITE_BACK,
        REDUCE_NEXT,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal pos_cnt  : integer range 0 to WT;
    signal word_cnt : integer range 0 to WORD_COUNT;
    signal red_cnt  : integer range 0 to WORD_COUNT;

    signal current_pos : unsigned(14 downto 0);

    signal word_offset : integer range 0 to 2047;
    signal bit_offset  : integer range 0 to 31;

    signal dense_word_r : std_logic_vector(31 downto 0);


begin

    pos_addr <= to_unsigned(pos_cnt, 7);

    process(clk)
        variable lower_v : unsigned(31 downto 0);
        variable upper_v : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state    <= IDLE;
                pos_cnt  <= 0;
                word_cnt <= 0;
                red_cnt  <= 0;
                done     <= '0';
                acc_we_a <= '0';
                acc_we_b <= '0';
            else

                acc_we_a <= '0';
                acc_we_b <= '0';

                case state is

                ----------------------------------------------------------------
                -- FASE 0: INICIALIZACIÓN
                ----------------------------------------------------------------
                when IDLE =>
                    done <= '0';
                    if start = '1' then
                        pos_cnt  <= 0;
                        word_cnt <= 0;
                        red_cnt  <= 0;
                        state    <= LOAD_POS;
                    end if;

                when LOAD_POS =>
                    state    <= WAIT_POS;

                when WAIT_POS =>
                    current_pos <= pos_data;
                    word_offset <= to_integer(pos_data(14 downto 5));
                    bit_offset  <= to_integer(pos_data(4 downto 0));
                    word_cnt    <= 0;
                    state       <= SET_ADDR;

                ----------------------------------------------------------------
                -- FASE 1: MULTIPLICACIÓN LINEAL (EXTENDIDA HASTA 2*WORD_COUNT)
                ----------------------------------------------------------------
                when SET_ADDR =>
                    dense_addr <= to_unsigned(word_cnt, 10);

                    -- Asignación directa lineal sin restricciones de módulo
                    acc_addr_a <= to_unsigned(word_cnt + word_offset, 11);
                    acc_addr_b <= to_unsigned(word_cnt + word_offset + 1, 11);

                    state <= WAIT_READ;

                when WAIT_READ =>
                    dense_word_r <= dense_data;
                    state        <= WRITE_BACK;

                when WRITE_BACK =>
                    if bit_offset = 0 then
                        lower_v := unsigned(dense_word_r);
                        upper_v := (others => '0');

                        acc_din_a <= acc_dout_a xor std_logic_vector(lower_v);
                        acc_we_a  <= '1';
                        acc_we_b  <= '0';
                    else
                        lower_v := shift_left(unsigned(dense_word_r), bit_offset);
                        upper_v := shift_right(unsigned(dense_word_r), 32 - bit_offset);

                        acc_din_a <= acc_dout_a xor std_logic_vector(lower_v);
                        acc_din_b <= acc_dout_b xor std_logic_vector(upper_v);

                        acc_we_a  <= '1';
                        acc_we_b  <= '1';
                    end if;

                    state <= NEXT_WORD;

                when NEXT_WORD =>
                    if word_cnt = WORD_COUNT - 1 then
                        state <= NEXT_POS;
                    else
                        word_cnt <= word_cnt + 1;
                        state    <= SET_ADDR;
                    end if;

                when NEXT_POS =>
                    if pos_cnt = WT - 1 then
                        -- Finalizó la multiplicación lineal; inicia la reducción
                        red_cnt <= 0;
                        state   <= REDUCE_SET_ADDR;
                    else
                        pos_cnt <= pos_cnt + 1;
                        state   <= LOAD_POS;
                    end if;

                ----------------------------------------------------------------
                -- FASE 2: REDUCCIÓN / PLEGADO (XOR PARTE ALTA Y BAJA)
                ----------------------------------------------------------------
                when REDUCE_SET_ADDR =>
                    -- Puerto A lee la parte baja [0 .. WORD_COUNT - 1]
                    acc_addr_a <= to_unsigned(red_cnt, 11);
                    -- Puerto B lee la parte alta [WORD_COUNT .. 2*WORD_COUNT - 1]
                    acc_addr_b <= to_unsigned(red_cnt + WORD_COUNT, 11);

                    state <= REDUCE_WAIT_READ;

                when REDUCE_WAIT_READ =>
                    -- Latencia de lectura de la BRAM
                    state <= REDUCE_WRITE_BACK;

                when REDUCE_WRITE_BACK =>
                    -- Se combina la parte baja con la parte alta mediante XOR y se guarda en la parte baja
                    acc_din_a <= acc_dout_a xor acc_dout_b;
                    acc_we_a  <= '1';
                    acc_we_b  <= '0';

                    state <= REDUCE_NEXT;

                when REDUCE_NEXT =>
                    if red_cnt = WORD_COUNT - 1 then
                        state <= FINISHED;
                    else
                        red_cnt <= red_cnt + 1;
                        state   <= REDUCE_SET_ADDR;
                    end if;

                ----------------------------------------------------------------
                -- FASE 3: FINALIZADO
                ----------------------------------------------------------------
                when FINISHED =>
                    done <= '1';
                    if start = '0' then
                        state <= IDLE;
                    end if;

                end case;

            end if;

        end if;
    end process;

end architecture;
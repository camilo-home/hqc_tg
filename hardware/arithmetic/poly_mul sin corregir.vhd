library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poly_mul is
generic(
    WT         : integer; -- generic map 66 y 75 dependiendo del muestreo de vector
    WORD_COUNT : integer -- generic map 553, bytes necesarios para el vector denso de 17669 bits 
);
port(
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;

    -- Position memory
    pos_addr : out unsigned(6 downto 0);
    pos_data : in  unsigned(14 downto 0);

    -- Dense memory
    dense_addr : out unsigned(9 downto 0);
    dense_data : in  std_logic_vector(31 downto 0);

    -- Accumulator BRAM
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
        PIPE_LOOP,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal pos_cnt  : integer range 0 to WT;
    -- pipe_cnt cuenta hasta WORD_COUNT + 1 para vaciar el pipeline al final
    signal pipe_cnt : integer range 0 to WORD_COUNT + 1; 

    signal word_offset : integer range 0 to 2047;
    signal bit_offset  : integer range 0 to 31;
    
    -- Registro para el pipeline matemático que evita el riesgo estructural
    signal saved_upper : unsigned(31 downto 0);

begin

    -- El puerto A del acumulador ahora es estrictamente de lectura
    acc_we_a  <= '0';
    acc_din_a <= (others => '0');

    process(clk)
        variable k : integer;
        variable lower_v, upper_v, combined : unsigned(31 downto 0);
        variable shifted_64 : unsigned(63 downto 0);
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state <= IDLE;
                pos_cnt  <= 0;
                pipe_cnt <= 0;
                done <= '0';
                acc_we_b <= '0';
                saved_upper <= (others => '0');
            else
                
                acc_we_b <= '0';

                case state is

                when IDLE =>
                    done <= '0';
                    if start = '1' then
                        pos_cnt  <= 0;
                        state <= LOAD_POS;
                    end if;

                when LOAD_POS =>
                    pos_addr <= to_unsigned(pos_cnt, 7);
                    state <= WAIT_POS;

                when WAIT_POS =>
                    word_offset <= to_integer(pos_data(14 downto 5));
                    bit_offset  <= to_integer(pos_data(4 downto 0));
                    
                    pipe_cnt <= 0;
                    saved_upper <= (others => '0');
                    state <= PIPE_LOOP;

                when PIPE_LOOP =>
                    -- ETAPA 1 (Ciclo T): Generación de direcciones
                    if pipe_cnt <= WORD_COUNT then
                        if pipe_cnt < WORD_COUNT then
                            dense_addr <= to_unsigned(pipe_cnt, 10);
                        end if;
                        acc_addr_a <= to_unsigned(word_offset + pipe_cnt, 11);
                    end if;

                    -- ETAPA 3 (Ciclo T+1): Procesamiento y Escritura
                    -- (La memoria se lee en T y entrega el dato en T+1 de forma síncrona)
                    if pipe_cnt >= 1 then
                        k := pipe_cnt - 1;

                        if k < WORD_COUNT then
                            -- Único desplazador de barril de 64 bits para optimizar área
                            shifted_64 := shift_left(resize(unsigned(dense_data), 64), bit_offset);
                            lower_v := shifted_64(31 downto 0);
                            upper_v := shifted_64(63 downto 32);
                        else
                            -- Ciclo extra para escribir el acarreo final (upper_v del último dato)
                            lower_v := (others => '0');
                            upper_v := (others => '0');
                        end if;

                        -- Resolver colisión de memoria: combinar acarreo viejo con parte baja nueva
                        combined := lower_v xor saved_upper;
                        saved_upper <= upper_v;

                        -- Escribir directamente en el puerto B
                        acc_din_b  <= acc_dout_a xor std_logic_vector(combined);
                        acc_addr_b <= to_unsigned(word_offset + k, 11);
                        acc_we_b   <= '1';
                    end if;

                    -- Control del loop
                    if pipe_cnt = WORD_COUNT + 1 then
                        if pos_cnt = WT - 1 then
                            state <= FINISHED;
                        else
                            pos_cnt <= pos_cnt + 1;
                            state <= LOAD_POS;
                        end if;
                    else
                        pipe_cnt <= pipe_cnt + 1;
                    end if;

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

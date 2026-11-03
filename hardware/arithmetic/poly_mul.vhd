library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poly_mul is
generic(
    WT         : integer;            -- Número de posiciones (ej. 66 o 75)
    WORD_COUNT : integer;            -- Número de palabras de 32 bits (ej. 553 para 17669 bits)
    N_BITS     : integer := 17669    -- Tamaño exacto del anillo en bits
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
    signal pipe_cnt : integer range 0 to WORD_COUNT + 1; 

    signal word_offset : integer range 0 to 2047;
    signal bit_offset  : integer range 0 to 31;
    
    -- Cantidad de bits válidos en la última palabra parcial (residuo de N_BITS / 32)
    constant LAST_WORD_BITS : integer := N_BITS mod 32;

begin

    acc_we_a  <= '0';
    acc_din_a <= (others => '0');

    process(clk)
        variable k : integer;
        variable lower_v, upper_v, combined : unsigned(31 downto 0);
        variable shifted_64 : unsigned(63 downto 0);
        variable masked_dense : std_logic_vector(31 downto 0);
        variable mask : std_logic_vector(31 downto 0);
        variable saved_upper : unsigned(31 downto 0) := (others => '0');
        variable zeros_32 : unsigned(31 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state <= IDLE;
                pos_cnt  <= 0;
                pipe_cnt <= 0;
                done <= '0';
                acc_we_b <= '0';
                saved_upper := (others => '0');
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
                    saved_upper := (others => '0');
                    state <= PIPE_LOOP;

                when PIPE_LOOP =>
                    -- ETAPA 1 (Ciclo T): Petición síncrona a memorias con direccionamiento circular
                    if pipe_cnt <= WORD_COUNT then
                        if pipe_cnt < WORD_COUNT then
                            dense_addr <= to_unsigned(pipe_cnt, 10);
                        end if;
                        acc_addr_a <= to_unsigned((word_offset + pipe_cnt) mod WORD_COUNT, 11);
                    end if;

                    -- ETAPA 3 (Ciclo T+1): Procesamiento, Enmascaramiento y Escritura
                    if pipe_cnt >= 1 then
                        k := pipe_cnt - 1;

                        if k < WORD_COUNT then
                            -- Generar máscara dinámica para la última palabra si no es múltiplo de 32
                            if LAST_WORD_BITS = 0 or LAST_WORD_BITS = 32 then
                                mask := (others => '1');
                            else
                                mask := std_logic_vector(shift_left(to_unsigned(1, 32), LAST_WORD_BITS) - 1);
                            end if;

                            -- Aplicar máscara de padding solo en la última palabra del vector denso
                            if k = (WORD_COUNT - 1) then
                                masked_dense := dense_data and mask;
                            else
                                masked_dense := dense_data;
                            end if;

                            -- Desplazamiento de barril de 64 bits
                            shifted_64 := shift_left(resize(unsigned(masked_dense), 64), bit_offset);
                            lower_v := shifted_64(31 downto 0);
                            upper_v := shifted_64(63 downto 32);
                            
                            -- Combinación con el acarreo previo (saved_upper)
                            combined := lower_v xor saved_upper;
                            saved_upper := upper_v;

                            -- Escritura acumulativa en puerto B con envoltura circular del anillo
                            acc_din_b  <= acc_dout_a xor std_logic_vector(combined);
                            acc_addr_b <= to_unsigned((word_offset + k) mod WORD_COUNT, 11);
                            acc_we_b   <= '1';
                        else
                            -- Ciclo extra: vaciar el último acarreo remanente (si es distinto de 0)
                            if unsigned(saved_upper) /= 0 then
                                -- Usamos una variable con tamaño definido (zeros_32) para evitar el error (vcom-1389)
                                combined := zeros_32 xor saved_upper;
                                
                                acc_din_b  <= acc_dout_a xor std_logic_vector(combined);
                                acc_addr_b <= to_unsigned((word_offset + k) mod WORD_COUNT, 11);
                                acc_we_b   <= '1';
                            else
                                acc_we_b <= '0';
                            end if;
                            
                            saved_upper := (others => '0');
                        end if;
                    end if;

                    -- Control del bucle del pipeline
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
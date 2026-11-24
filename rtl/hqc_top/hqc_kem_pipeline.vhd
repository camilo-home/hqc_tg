-- ============================================================================
-- hqc_kem_pipeline : keygen -> encaps -> decaps encadenados, todo en el dominio clk
--
--   entradas (estaticas mientras corre): seed_kem (32 B), m (16 B), salt (16 B). Palabra i en los bits 64*i+63..64*i,
--   byte 0 en los bits [7:0] (igual que los modulos). start = pulso, solo con pipeline_ready = '1'.
--
--   1) hqc_keygen(seed_kem)            -> dk_ram : 291 palabras = ek (281) | seed_dk (4) | sigma (2) | seed_kem (4)
--   2) hqc_encaps(ek, m, salt)         -> ss_encaps (4 palabras) y ct_ram : 555 palabras = u (277) | v (276) | salt (2)
--        el top reproduce ek desde dk_ram y a continuacion m y salt (285 palabras, el formato de key_* de encaps)
--   3) hqc_decaps(dk, ct)              -> ss_decaps = K (4 palabras)
--        dk y ct se reproducen desde las RAM; ct puede corromperse (1 bit) para probar el rechazo implicito
--   pipeline_done = pulso al terminar. result_k = K (ss de decaps). result_k_equal = (ss_encaps == ss_decaps).
--
--   Lectura de las RAM (depuracion / verificacion contra el KAT): pulso mem_read_request con select ('0' dk_ram,
--   '1' ct_ram) y address; al cabo de unos ciclos mem_read_valid = pulso y mem_read_data conserva la palabra.
--
--   Los generics de los tres modulos se dejan en sus valores por defecto (los de tu proyecto).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hqc_kem_pipeline is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start          : in  std_logic;     -- pulso, solo con pipeline_ready = '1'
    pipeline_ready : out std_logic;
    pipeline_done  : out std_logic;     -- pulso al terminar los tres pasos

    -- entradas (estables desde start hasta pipeline_done)
    seed_kem_words     : in  std_logic_vector(255 downto 0);
    m_words            : in  std_logic_vector(127 downto 0);
    salt_words         : in  std_logic_vector(127 downto 0);
    corrupt_enable     : in  std_logic;                     -- invierte 1 bit del ct que recibe decaps
    corrupt_word_index : in  unsigned(9 downto 0);          -- palabra del ct (0 .. 554)
    corrupt_bit_index  : in  unsigned(5 downto 0);          -- bit dentro de la palabra (0 .. 63)

    -- resultados (estables desde pipeline_done hasta el siguiente start)
    result_k_words         : out std_logic_vector(255 downto 0);   -- ss de decaps
    result_ss_encaps_words : out std_logic_vector(255 downto 0);   -- ss de encaps
    decaps_reenc_match           : out std_logic;                        -- decaps: el re-cifrado coincidio
    result_k_equal         : out std_logic;                        -- ss_encaps == ss_decaps
    result_error           : out std_logic;                        -- error de encaps o de protocolo (conteo de palabras)
    result_decaps_error    : out std_logic;                        -- err de decaps (esperable con un ct corrupto)
    cycles_keygen          : out unsigned(31 downto 0);            -- tal como los reporta cada modulo
    cycles_encaps          : out unsigned(31 downto 0);
    cycles_decaps          : out unsigned(31 downto 0);
    cycles_total           : out unsigned(31 downto 0);            -- start -> pipeline_done
    state_code             : out std_logic_vector(7 downto 0);     -- [3:0] estado del pipeline, [7:4] dbg_state del modulo activo

    -- lectura de las RAM
    mem_read_request : in  std_logic;
    mem_read_select  : in  std_logic;
    mem_read_address : in  unsigned(9 downto 0);
    mem_read_valid   : out std_logic;
    mem_read_data    : out std_logic_vector(63 downto 0)
  );
end entity;

architecture rtl of hqc_kem_pipeline is

  constant DK_WORD_COUNT         : integer := 291;
  constant DK_EK_WORD_COUNT      : integer := 281;
  constant CT_WORD_COUNT         : integer := 555;
  constant ENCAPS_LAST_KEY_INDEX : integer := 284;     -- ek (281) + m (2) + salt (2) = 285 palabras
  constant DECAPS_LAST_DK_INDEX  : integer := 290;
  constant DECAPS_LAST_CT_INDEX  : integer := 554;
  constant ZERO_WORD             : std_logic_vector(63 downto 0) := (others => '0');

  type pipeline_state_t is (PIPE_IDLE, PIPE_KEYGEN_RUN, PIPE_ENCAPS_LAUNCH, PIPE_ENCAPS_RUN,
                            PIPE_DECAPS_LAUNCH, PIPE_DECAPS_RUN, PIPE_FINISH);
  type word_reader_state_t is (READER_IDLE, READER_ADDRESS, READER_SEND);
  type mem_read_state_t    is (MEMREAD_IDLE, MEMREAD_ADDRESS, MEMREAD_LATCH);
  type words4_t is array (0 to 3) of std_logic_vector(63 downto 0);

  signal pipeline_state  : pipeline_state_t := PIPE_IDLE;
  signal dk_reader_state : word_reader_state_t := READER_IDLE;
  signal ct_reader_state : word_reader_state_t := READER_IDLE;
  signal mem_read_state  : mem_read_state_t := MEMREAD_IDLE;

  signal ss_encaps_words : words4_t := (others => (others => '0'));
  signal ss_decaps_words : words4_t := (others => (others => '0'));

  -- contadores
  signal seed_word_index    : integer range 0 to 4 := 0;
  signal dk_write_index     : integer range 0 to DK_WORD_COUNT := 0;
  signal ct_write_index     : integer range 0 to CT_WORD_COUNT := 0;
  signal encaps_ss_count    : integer range 0 to 4 := 0;
  signal decaps_ss_count    : integer range 0 to 4 := 0;
  signal dk_reader_index    : integer range 0 to DECAPS_LAST_DK_INDEX := 0;
  signal dk_reader_last_index : integer range 0 to DECAPS_LAST_DK_INDEX := 0;
  signal ct_reader_index    : integer range 0 to DECAPS_LAST_CT_INDEX := 0;

  -- pulsos de un ciclo
  signal keygen_start, encaps_start, decaps_start, dk_reader_go, ct_reader_go : std_logic := '0';

  signal cycle_counter_running : std_logic := '0';
  signal cycle_counter         : unsigned(31 downto 0) := (others => '0');
  signal cycles_keygen_register, cycles_encaps_register, cycles_decaps_register, cycles_total_register : unsigned(31 downto 0) := (others => '0');

  signal reenc_match_register, result_k_equal_register, result_decaps_error_register, protocol_error_sticky : std_logic := '0';
  signal pipeline_ready_internal : std_logic;

  -- keygen
  signal keygen_ready, keygen_done, keygen_seed_valid, keygen_seed_ready : std_logic;
  signal keygen_seed_data, keygen_out_data : std_logic_vector(63 downto 0);
  signal keygen_out_valid, keygen_out_ready, keygen_out_last, keygen_out_part : std_logic;
  signal keygen_cycles_reported : unsigned(31 downto 0);
  signal keygen_debug_state : std_logic_vector(3 downto 0);

  -- encaps
  signal encaps_ready, encaps_done, encaps_key_valid, encaps_key_ready, encaps_error : std_logic;
  signal encaps_key_data, encaps_out_data : std_logic_vector(63 downto 0);
  signal encaps_out_valid, encaps_out_ready, encaps_out_last : std_logic;
  signal encaps_out_part : std_logic_vector(1 downto 0);
  signal encaps_cycles_reported : unsigned(31 downto 0);
  signal encaps_debug_state : std_logic_vector(3 downto 0);

  -- decaps
  signal decaps_ready, decaps_done, decaps_dk_valid, decaps_dk_ready, decaps_ct_valid, decaps_ct_ready : std_logic;
  signal decaps_dk_data, decaps_ct_data, decaps_out_data : std_logic_vector(63 downto 0);
  signal decaps_out_valid, decaps_out_ready, decaps_out_last, reenc_match, decaps_error : std_logic;
  signal decaps_cycles_reported : unsigned(31 downto 0);
  signal decaps_debug_state : std_logic_vector(3 downto 0);

  -- RAM dk (291 palabras) y RAM ct (555 palabras)
  signal dk_ram_write_enable_port1 : std_logic;
  signal dk_ram_address_port1, dk_ram_address_port2 : unsigned(8 downto 0);
  signal dk_ram_data_out_port1, dk_ram_data_out_port2 : std_logic_vector(63 downto 0);
  signal ct_ram_write_enable_port1 : std_logic;
  signal ct_ram_address_port1, ct_ram_address_port2 : unsigned(9 downto 0);
  signal ct_ram_data_out_port1, ct_ram_data_out_port2 : std_logic_vector(63 downto 0);

  -- lectores (reproducen las RAM hacia encaps y decaps)
  signal dk_reader_send, ct_reader_send, dk_reader_consumer_ready : std_logic;
  signal dk_reader_data, ct_corrupt_mask : std_logic_vector(63 downto 0);

  -- lectura de RAM por el puerto 2
  signal mem_read_select_register : std_logic := '0';
  signal mem_read_address_register : unsigned(9 downto 0) := (others => '0');
  signal mem_read_data_register : std_logic_vector(63 downto 0) := (others => '0');
  signal mem_read_valid_register : std_logic := '0';

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  u_keygen : entity work.hqc_keygen
    port map (clk => clk, rst => rst, start => keygen_start, ready => keygen_ready, done => keygen_done,
              seed_valid => keygen_seed_valid, seed_ready => keygen_seed_ready, seed_data => keygen_seed_data,
              out_valid => keygen_out_valid, out_ready => keygen_out_ready, out_data => keygen_out_data,
              out_last => keygen_out_last, out_part => keygen_out_part,
              cycles => keygen_cycles_reported, dbg_state => keygen_debug_state);

  u_encaps : entity work.hqc_encaps
    port map (clk => clk, rst => rst, start => encaps_start, ready => encaps_ready, done => encaps_done,
              key_valid => encaps_key_valid, key_ready => encaps_key_ready, key_data => encaps_key_data,
              out_valid => encaps_out_valid, out_ready => encaps_out_ready, out_data => encaps_out_data,
              out_last => encaps_out_last, out_part => encaps_out_part,
              cycles => encaps_cycles_reported, cycles_core => open, err => encaps_error,
              dbg_state => encaps_debug_state);

  u_decaps : entity work.hqc_decaps
    port map (clk => clk, rst => rst, start => decaps_start, ready => decaps_ready, done => decaps_done,
              dk_valid => decaps_dk_valid, dk_ready => decaps_dk_ready, dk_data => decaps_dk_data,
              ct_valid => decaps_ct_valid, ct_ready => decaps_ct_ready, ct_data => decaps_ct_data,
              out_valid => decaps_out_valid, out_ready => decaps_out_ready, out_data => decaps_out_data,
              out_last => decaps_out_last, reenc_match => reenc_match, err => decaps_error,
              cycles => decaps_cycles_reported, cycles_core => open, dbg_state => decaps_debug_state);

  u_dk_ram : entity work.ram64_tdp
    generic map (DEPTH => 291, ADDR_W => 9)
    port map (clk => clk,
              we_1 => dk_ram_write_enable_port1, addr_1 => dk_ram_address_port1, din_1 => keygen_out_data, dout_1 => dk_ram_data_out_port1,
              we_2 => '0', addr_2 => dk_ram_address_port2, din_2 => ZERO_WORD, dout_2 => dk_ram_data_out_port2);

  u_ct_ram : entity work.ram64_tdp
    generic map (DEPTH => 555, ADDR_W => 10)
    port map (clk => clk,
              we_1 => ct_ram_write_enable_port1, addr_1 => ct_ram_address_port1, din_1 => encaps_out_data, dout_1 => ct_ram_data_out_port1,
              we_2 => '0', addr_2 => ct_ram_address_port2, din_2 => ZERO_WORD, dout_2 => ct_ram_data_out_port2);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  pipeline_ready_internal <= '1' when (pipeline_state = PIPE_IDLE and keygen_ready = '1' and
                                       encaps_ready = '1' and decaps_ready = '1') else '0';
  pipeline_ready <= pipeline_ready_internal;
  pipeline_done  <= '1' when pipeline_state = PIPE_FINISH else '0';

  result_k_words         <= std_logic_vector'(ss_decaps_words(3) & ss_decaps_words(2) & ss_decaps_words(1) & ss_decaps_words(0));
  result_ss_encaps_words <= std_logic_vector'(ss_encaps_words(3) & ss_encaps_words(2) & ss_encaps_words(1) & ss_encaps_words(0));
  decaps_reenc_match           <= reenc_match_register;
  result_k_equal         <= result_k_equal_register;
  result_error           <= protocol_error_sticky or encaps_error;
  result_decaps_error    <= result_decaps_error_register;
  cycles_keygen          <= cycles_keygen_register;
  cycles_encaps          <= cycles_encaps_register;
  cycles_decaps          <= cycles_decaps_register;
  cycles_total           <= cycles_total_register;

  state_code(3 downto 0) <= std_logic_vector(to_unsigned(pipeline_state_t'pos(pipeline_state), 4));
  state_code(7 downto 4) <= keygen_debug_state when pipeline_state = PIPE_KEYGEN_RUN else
                            encaps_debug_state when (pipeline_state = PIPE_ENCAPS_LAUNCH or pipeline_state = PIPE_ENCAPS_RUN) else
                            decaps_debug_state when (pipeline_state = PIPE_DECAPS_LAUNCH or pipeline_state = PIPE_DECAPS_RUN) else
                            "0000";

  ---------------------------------------------------------------------------
  -- Paso 1: seed_kem hacia keygen (4 palabras, valid/ready) y captura de su salida en dk_ram
  ---------------------------------------------------------------------------
  keygen_seed_valid <= '1' when (pipeline_state = PIPE_KEYGEN_RUN and seed_word_index < 4) else '0';
  keygen_seed_data  <= seed_kem_words(63 downto 0)    when seed_word_index = 0 else
                       seed_kem_words(127 downto 64)  when seed_word_index = 1 else
                       seed_kem_words(191 downto 128) when seed_word_index = 2 else
                       seed_kem_words(255 downto 192);
  keygen_out_ready  <= '1' when pipeline_state = PIPE_KEYGEN_RUN else '0';

  dk_ram_write_enable_port1 <= '1' when (pipeline_state = PIPE_KEYGEN_RUN and keygen_out_valid = '1' and
                                         dk_write_index < DK_WORD_COUNT) else '0';
  dk_ram_address_port1 <= to_unsigned(dk_write_index, 9) when pipeline_state = PIPE_KEYGEN_RUN
                          else to_unsigned(dk_reader_index, 9);

  ---------------------------------------------------------------------------
  -- Paso 2: dk_ram (ek) + m + salt hacia encaps; su salida: ss -> registros, el resto (u|v|salt) -> ct_ram
  ---------------------------------------------------------------------------
  encaps_out_ready <= '1' when pipeline_state = PIPE_ENCAPS_RUN else '0';

  ct_ram_write_enable_port1 <= '1' when (pipeline_state = PIPE_ENCAPS_RUN and encaps_out_valid = '1' and
                                         encaps_out_part /= "00" and ct_write_index < CT_WORD_COUNT) else '0';
  ct_ram_address_port1 <= to_unsigned(ct_write_index, 10) when pipeline_state = PIPE_ENCAPS_RUN
                          else to_unsigned(ct_reader_index, 10);

  ---------------------------------------------------------------------------
  -- Lector de dk_ram: ek + m + salt hacia encaps (285 palabras) y despues dk completo hacia decaps (291 palabras)
  ---------------------------------------------------------------------------
  dk_reader_send           <= '1' when dk_reader_state = READER_SEND else '0';
  dk_reader_consumer_ready <= encaps_key_ready when pipeline_state = PIPE_ENCAPS_RUN else decaps_dk_ready;
  encaps_key_valid <= dk_reader_send when pipeline_state = PIPE_ENCAPS_RUN else '0';
  decaps_dk_valid  <= dk_reader_send when pipeline_state = PIPE_DECAPS_RUN else '0';

  dk_reader_data_proc : process(pipeline_state, dk_reader_index, dk_ram_data_out_port1, m_words, salt_words)
  begin
    if pipeline_state = PIPE_ENCAPS_RUN and dk_reader_index >= DK_EK_WORD_COUNT then
      case dk_reader_index is
        when 281    => dk_reader_data <= m_words(63 downto 0);
        when 282    => dk_reader_data <= m_words(127 downto 64);
        when 283    => dk_reader_data <= salt_words(63 downto 0);
        when others => dk_reader_data <= salt_words(127 downto 64);
      end case;
    else
      dk_reader_data <= dk_ram_data_out_port1;
    end if;
  end process;
  encaps_key_data <= dk_reader_data;
  decaps_dk_data  <= dk_ram_data_out_port1;

  dk_reader_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dk_reader_state <= READER_IDLE;
        dk_reader_index <= 0;
      else
        case dk_reader_state is
          when READER_IDLE =>
            if dk_reader_go = '1' then
              dk_reader_index <= 0;
              dk_reader_state <= READER_ADDRESS;
            end if;
          when READER_ADDRESS =>                            -- la direccion lleva un ciclo presentada
            dk_reader_state <= READER_SEND;
          when READER_SEND =>                               -- valid = '1' hasta que el consumidor acepta
            if dk_reader_consumer_ready = '1' then
              if dk_reader_index = dk_reader_last_index then
                dk_reader_state <= READER_IDLE;
              else
                dk_reader_index <= dk_reader_index + 1;
                dk_reader_state <= READER_ADDRESS;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Paso 3: ct_ram hacia decaps (555 palabras) con la corrupcion opcional de 1 bit
  ---------------------------------------------------------------------------
  ct_corrupt_mask <= std_logic_vector(shift_left(to_unsigned(1, 64), to_integer(corrupt_bit_index)))
                       when (corrupt_enable = '1' and ct_reader_index = to_integer(corrupt_word_index))
                       else ZERO_WORD;
  decaps_ct_valid <= '1' when (ct_reader_state = READER_SEND and pipeline_state = PIPE_DECAPS_RUN) else '0';
  decaps_ct_data  <= ct_ram_data_out_port1 xor ct_corrupt_mask;
  decaps_out_ready <= '1' when pipeline_state = PIPE_DECAPS_RUN else '0';

  ct_reader_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ct_reader_state <= READER_IDLE;
        ct_reader_index <= 0;
      else
        case ct_reader_state is
          when READER_IDLE =>
            if ct_reader_go = '1' then
              ct_reader_index <= 0;
              ct_reader_state <= READER_ADDRESS;
            end if;
          when READER_ADDRESS =>
            ct_reader_state <= READER_SEND;
          when READER_SEND =>
            if decaps_ct_ready = '1' then
              if ct_reader_index = DECAPS_LAST_CT_INDEX then
                ct_reader_state <= READER_IDLE;
              else
                ct_reader_index <= ct_reader_index + 1;
                ct_reader_state <= READER_ADDRESS;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- FSM principal
  ---------------------------------------------------------------------------
  main_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pipeline_state        <= PIPE_IDLE;
        seed_word_index       <= 0;
        dk_write_index        <= 0;
        ct_write_index        <= 0;
        encaps_ss_count       <= 0;
        decaps_ss_count       <= 0;
        cycle_counter_running <= '0';
        keygen_start          <= '0';
        encaps_start          <= '0';
        decaps_start          <= '0';
        dk_reader_go          <= '0';
        ct_reader_go          <= '0';
        protocol_error_sticky <= '0';
      else
        keygen_start <= '0';
        encaps_start <= '0';
        decaps_start <= '0';
        dk_reader_go <= '0';
        ct_reader_go <= '0';

        if cycle_counter_running = '1' then
          cycle_counter <= cycle_counter + 1;
        end if;

        case pipeline_state is

          when PIPE_IDLE =>
            if start = '1' and pipeline_ready_internal = '1' then
              keygen_start          <= '1';
              seed_word_index       <= 0;
              dk_write_index        <= 0;
              ct_write_index        <= 0;
              encaps_ss_count       <= 0;
              decaps_ss_count       <= 0;
              protocol_error_sticky <= '0';
              cycle_counter         <= (others => '0');
              cycle_counter_running <= '1';
              ss_encaps_words <= (others => (others => '0'));
              ss_decaps_words <= (others => (others => '0'));
              pipeline_state        <= PIPE_KEYGEN_RUN;
            end if;

          when PIPE_KEYGEN_RUN =>
            if keygen_seed_valid = '1' and keygen_seed_ready = '1' then
              seed_word_index <= seed_word_index + 1;
            end if;
            if keygen_out_valid = '1' then                    -- keygen_out_ready = '1' en este estado
              if dk_write_index < DK_WORD_COUNT then
                dk_write_index <= dk_write_index + 1;
              else
                protocol_error_sticky <= '1';                 -- keygen entrego mas de 291 palabras
              end if;
            end if;
            if keygen_out_last = '1' and keygen_out_part = '1' then
              cycles_keygen_register <= keygen_cycles_reported;
              pipeline_state         <= PIPE_ENCAPS_LAUNCH;
            end if;

          when PIPE_ENCAPS_LAUNCH =>
            if dk_write_index /= DK_WORD_COUNT then
              protocol_error_sticky <= '1';                   -- keygen entrego menos de 291 palabras
            end if;
            if encaps_ready = '1' then
              encaps_start        <= '1';
              dk_reader_last_index <= ENCAPS_LAST_KEY_INDEX;
              dk_reader_go        <= '1';
              pipeline_state      <= PIPE_ENCAPS_RUN;
            end if;

          when PIPE_ENCAPS_RUN =>                             -- encaps_out_ready = '1' en este estado
            if encaps_out_valid = '1' then
              if encaps_out_part = "00" then                  -- ss
                if encaps_ss_count < 4 then
                  ss_encaps_words(encaps_ss_count) <= encaps_out_data;
                  encaps_ss_count                  <= encaps_ss_count + 1;
                else
                  protocol_error_sticky <= '1';
                end if;
              else                                            -- u | v | salt hacia ct_ram
                if ct_write_index < CT_WORD_COUNT then
                  ct_write_index <= ct_write_index + 1;
                else
                  protocol_error_sticky <= '1';
                end if;
              end if;
            end if;
            if encaps_out_last = '1' and encaps_out_part = "11" then
              cycles_encaps_register <= encaps_cycles_reported;
              pipeline_state         <= PIPE_DECAPS_LAUNCH;
            end if;

          when PIPE_DECAPS_LAUNCH =>
            if encaps_ss_count /= 4 or ct_write_index /= CT_WORD_COUNT then
              protocol_error_sticky <= '1';                   -- encaps no entrego 4 + 555 palabras
            end if;
            if decaps_ready = '1' then
              decaps_start         <= '1';
              dk_reader_last_index <= DECAPS_LAST_DK_INDEX;
              dk_reader_go         <= '1';
              ct_reader_go         <= '1';
              decaps_ss_count      <= 0;
              pipeline_state       <= PIPE_DECAPS_RUN;
            end if;

          when PIPE_DECAPS_RUN =>                             -- decaps_out_ready = '1' en este estado
            if decaps_out_valid = '1' then
              if decaps_ss_count < 4 then
                ss_decaps_words(decaps_ss_count) <= decaps_out_data;
                decaps_ss_count                  <= decaps_ss_count + 1;
              else
                protocol_error_sticky <= '1';
              end if;
            end if;
            if decaps_out_last = '1' then
              cycles_decaps_register       <= decaps_cycles_reported;
              reenc_match_register        <= reenc_match;
              result_decaps_error_register <= decaps_error;
              pipeline_state               <= PIPE_FINISH;
            end if;

          when PIPE_FINISH =>                                 -- pipeline_done = '1' (un ciclo)
            if decaps_ss_count /= 4 then
              protocol_error_sticky <= '1';
            end if;
            if ss_encaps_words = ss_decaps_words then
              result_k_equal_register <= '1';
            else
              result_k_equal_register <= '0';
            end if;
            cycle_counter_running <= '0';
            cycles_total_register <= cycle_counter;
            pipeline_state        <= PIPE_IDLE;

        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Lectura de dk_ram / ct_ram por el puerto 2 (solo lectura)
  --   mem_read_request (pulso) -> direccion presentada -> dato latcheado -> mem_read_valid (pulso)
  ---------------------------------------------------------------------------
dk_ram_address_port2 <= mem_read_address_register(8 downto 0) when mem_read_select_register = '0' else (others => '0');
ct_ram_address_port2 <= mem_read_address_register            when mem_read_select_register = '1' else (others => '0');
  mem_read_valid <= mem_read_valid_register;
  mem_read_data  <= mem_read_data_register;

  mem_read_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mem_read_state          <= MEMREAD_IDLE;
        mem_read_valid_register <= '0';
      else
        mem_read_valid_register <= '0';
        case mem_read_state is
          when MEMREAD_IDLE =>
            if mem_read_request = '1' then
              mem_read_select_register  <= mem_read_select;
              mem_read_address_register <= mem_read_address;
              mem_read_state            <= MEMREAD_ADDRESS;
            end if;
          when MEMREAD_ADDRESS =>                             -- la RAM captura la direccion al final de este ciclo
            mem_read_state <= MEMREAD_LATCH;
          when MEMREAD_LATCH =>
            if mem_read_select_register = '0' then
              mem_read_data_register <= dk_ram_data_out_port2;
            else
              mem_read_data_register <= ct_ram_data_out_port2;
            end if;
            mem_read_valid_register <= '1';
            mem_read_state          <= MEMREAD_IDLE;
        end case;
      end if;
    end if;
  end process;

end rtl;

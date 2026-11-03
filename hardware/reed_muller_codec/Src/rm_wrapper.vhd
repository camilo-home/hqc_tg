library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rm_wrapper is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        
        -- Interfaz de Encapsulación (TX)
        enc_i_data   : in  std_logic_vector(7 downto 0);   -- 1 Byte de entrada (desde tu generador)
        enc_i_valid  : in  std_logic;
        enc_o_data   : out std_logic_vector(383 downto 0); -- 384 bits de salida (128x3)
        enc_o_valid  : out std_logic;
        
        -- Interfaz de Desencapsulación (RX)
        dec_i_data   : in  std_logic_vector(383 downto 0); -- 384 bits ruidosos (desde LWE)
        dec_i_valid  : in  std_logic;
        dec_o_data   : out std_logic_vector(7 downto 0);   -- 1 Byte corregido (hacia RS Decoder)
        dec_o_valid  : out std_logic
    );
end rm_wrapper;

architecture rtl of rm_wrapper is

    -- Componente RM(1,7) Encoder de Piliguori
    component rm_encoder is
        generic ( m : integer := 7 );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            data_in  : in  std_logic_vector(7 downto 0);
            valid_in : in  std_logic;
            data_out : out std_logic_vector(127 downto 0);
            valid_out: out std_logic
        );
    end component;

    -- Componente RM(1,7) Decoder de Piliguori (FHT)
    component rm_decoder is
        generic ( m : integer := 7 );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            data_in  : in  std_logic_vector(127 downto 0);
            valid_in : in  std_logic;
            data_out : out std_logic_vector(7 downto 0);
            valid_out: out std_logic
        );
    end component;

    -- Señales internas
    signal rm_enc_out       : std_logic_vector(127 downto 0);
    signal rm_enc_valid_out : std_logic;
    
    signal block_1          : std_logic_vector(127 downto 0);
    signal block_2          : std_logic_vector(127 downto 0);
    signal block_3          : std_logic_vector(127 downto 0);
    signal voted_block      : std_logic_vector(127 downto 0);
    signal dec_valid_reg    : std_logic;

begin

    --------------------------------------------------------------------
    -- ETAPA DE ENCAPSULACIÓN: Codificación RM(1,7) + Multiplicidad 3
    --------------------------------------------------------------------
    -- Instanciación del módulo base de Piliguori
    U_RM_ENC : rm_encoder
        generic map ( m => 7 )
        port map (
            clk       => clk,
            rst       => rst,
            data_in   => enc_i_data,
            valid_in  => enc_i_valid,
            data_out  => rm_enc_out,
            valid_out => rm_enc_valid_out
        );

    -- Multiplicación (Repetición x3) por hardware puro (Concatenación)
    enc_o_data  <= rm_enc_out & rm_enc_out & rm_enc_out;
    enc_o_valid <= rm_enc_valid_out;


    --------------------------------------------------------------------
    -- ETAPA DE DESENCAPSULACIÓN: Votación Mayoritaria + Decodificación RM
    --------------------------------------------------------------------
    -- 1. Separar la trama de 384 bits recibida en 3 bloques de 128 bits
    block_1 <= dec_i_data(383 downto 256);
    block_2 <= dec_i_data(255 downto 128);
    block_3 <= dec_i_data(127 downto 0);

    -- 2. Filtro de Votación Mayoritaria (Majority Vote Bit a Bit)
    -- Si un bit es '1' en al menos 2 de los 3 bloques, el resultado es '1'.
    voted_block <= (block_1 and block_2) or (block_1 and block_3) or (block_2 and block_3);

    -- 3. Registro para sincronizar la señal valid con la lógica combinacional de votación
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                dec_valid_reg <= '0';
            else
                dec_valid_reg <= dec_i_valid;
            end if;
        end if;
    end process;

    -- 4. Instanciación del Decodificador FHT de Piliguori
    U_RM_DEC : rm_decoder
        generic map ( m => 7 )
        port map (
            clk       => clk,
            rst       => rst,
            data_in   => voted_block,      -- Ingresa el bloque de 128 bits ya pre-limpiado
            valid_in  => dec_valid_reg,
            data_out  => dec_o_data,       -- 1 Byte recuperado
            valid_out => dec_o_valid
        );

end rtl;
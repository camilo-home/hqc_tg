library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package keccak_sponge_pkg is

  -- cmd(1 downto 0)
  constant MODE_SHAKE128 : std_logic_vector(1 downto 0) := "00";  -- rate 168 B, sufijo 0x1F
  constant MODE_SHAKE256 : std_logic_vector(1 downto 0) := "01";  -- rate 136 B, sufijo 0x1F
  constant MODE_SHA3_256 : std_logic_vector(1 downto 0) := "10";  -- rate 136 B, sufijo 0x06, salida fija 32 B
  constant MODE_SHA3_512 : std_logic_vector(1 downto 0) := "11";  -- rate  72 B, sufijo 0x06, salida fija 64 B

  -- Construye la palabra de comando (primera palabra de entrada):
  --   cmd(1  downto 0)  = modo
  --   cmd(7  downto 2)  = reservado (0)
  --   cmd(31 downto 8)  = longitud del mensaje en BYTES  (24 bits)
  --   cmd(63 downto 32) = longitud de la salida en BYTES (solo SHAKE; SHA3 la ignora)
  function make_cmd(mode          : std_logic_vector(1 downto 0);
                    msg_len_bytes : natural;
                    out_len_bytes : natural) return std_logic_vector;

  -- Comando en modo sin limite (solo SHAKE): out_len = 0xFFFFFFFF.
  -- La salida no termina hasta que se pulse "abort" en keccak_sponge.
  function make_cmd_stream(mode          : std_logic_vector(1 downto 0);
                           msg_len_bytes : natural) return std_logic_vector;

end package;

package body keccak_sponge_pkg is

  function make_cmd(mode          : std_logic_vector(1 downto 0);
                    msg_len_bytes : natural;
                    out_len_bytes : natural) return std_logic_vector is
    variable c : std_logic_vector(63 downto 0) := (others => '0');
  begin
    c(1 downto 0)   := mode;
    c(31 downto 8)  := std_logic_vector(to_unsigned(msg_len_bytes, 24));
    c(63 downto 32) := std_logic_vector(to_unsigned(out_len_bytes, 32));
    return c;
  end function;

  function make_cmd_stream(mode          : std_logic_vector(1 downto 0);
                           msg_len_bytes : natural) return std_logic_vector is
    variable c : std_logic_vector(63 downto 0) := (others => '0');
  begin
    c(1 downto 0)   := mode;
    c(31 downto 8)  := std_logic_vector(to_unsigned(msg_len_bytes, 24));
    c(63 downto 32) := x"FFFFFFFF";
    return c;
  end function;

end package body;

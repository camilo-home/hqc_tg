def generate_msg_byte(idx: int) -> int:
    """Genera el byte msg_byte(idx) = (3 + 7 * idx) mod 256."""
    return (3 + 7 * idx) % 256


def generate_vhdl_test_words(msg_len: int) -> list[dict]:
    """
    Empaqueta el flujo de bytes generado dinámicamente en palabras de 64 bits.
    Devuelve los valores en formato hexadecimal (Big-Endian).
    """
    n_words = (msg_len + 7) // 8
    results = []

    for k in range(n_words):
        word_bytes = []
        for b in range(8):
            idx = 8 * k + b
            if idx < msg_len:
                b_val = generate_msg_byte(idx)
            else:
                b_val = 0xA5  # Padding A5
            word_bytes.append(b_val)

        # 1. Big-Endian natural de transmisión (Byte 0 en los bits más significativos MSB: 63..56)
        be_stream_val = int.from_bytes(word_bytes, byteorder="big")

        # 2. Big-Endian del vector VHDL (donde b=0 se asignó a bits 7..0, el MSB impreso es b=7)
        vhdl_vector_val = int.from_bytes(word_bytes, byteorder="little")

        results.append(
            {
                "palabra_idx": k,
                "bytes": [f"0x{b:02X}" for b in word_bytes],
                "hex_big_endian_stream": f"0x{be_stream_val:016X}",
                "hex_vhdl_vector_msb": f"0x{vhdl_vector_val:016X}",
            }
        )

    return results


if __name__ == "__main__":
    # Ejemplo de prueba con un msg_len de 10 bytes
    MSG_LEN = 137
    print(f"=== GENERACIÓN DE PALABRAS PARA msg_len = {MSG_LEN} ===")
    
    words = generate_vhdl_test_words(MSG_LEN)
    for w in words:
        print(f"\nPalabra {w['palabra_idx']}:")
        print(f"  Bytes del bloque (b=0 a b=7): {w['bytes']}")
        print(f"  Hex Big-Endian (Byte 0 = MSB): {w['hex_big_endian_stream']}")
        print(f"  Hex Vector VHDL (Bit 63..56):  {w['hex_vhdl_vector_msb']}")

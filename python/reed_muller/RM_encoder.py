def reed_muller_vhdl_exact(data_bits):
    """
    Simulación exacta del comportamiento de RMEncoder.vhd para RM(1,7)
    """
    if len(data_bits) != 8 or not all(b in '01' for b in data_bits):
        raise ValueError("La entrada debe ser una cadena de exactamente 8 bits.")

    # data_in de VHDL: data_bits[0] es el LSB (data_in(0)), data_bits[7] es el MSB (data_in(7))
    # En Python u[0] corresponde a data_in(7) ... u[7] a data_in(0) según el orden de índices
    u = [int(b) for b in data_bits[::1]]  # Invertimos para alinear índice de cadena con m downto 0
    
    encoded_bits = []
    
    # m = 7 -> 128 columnas (i de 0 a 127)
    for i in range(128):
        # generation_matrix(j) usa la conversión: to_unsigned(i + 128, 8)(7-j)
        # Que equivale matemáticamente a evaluar los bits de (i + 128)
        col_val = i + 128
        
        c_i = 0
        for j in range(8): # de j=0 a m (8 filas)
            # data_in(j) multiplica a generation_matrix(m-j)
            # En el VHDL am_matrix(i) usa generation_matrix(m-i)
            bit_gen = (col_val >> (7 - (7 - j))) & 1 # Simplificando: (col_val >> j) & 1
            # O de forma más precisa según la línea: std_logic(to_unsigned(i+2**m, m+1)(m-j))
            # Para la fila j (donde data_in(7-j) opera con generation_matrix(j)):
            val_matriz = (col_val >> (7 - j)) & 1
            c_i ^= (u[j] * val_matriz)
            
        encoded_bits.append(str(c_i))

    encoded_bin_str = "".join(encoded_bits)
    encoded_hex = f"{int(encoded_bin_str, 2):032X}"
    return encoded_bin_str, encoded_hex

if __name__ == "__main__":
    # Prueba con la entrada que activa data_in(0) en el VHDL
    entrada = input("Ingresa 8 bits (ej. 10110010): ").strip()
    try:
        binario, hexa = reed_muller_vhdl_exact(entrada)
        print(f"\n--- Resultados RM(1,7) ---")
        print(f"Entrada (8 bits)   : {entrada}")
        print(f"Salida (128 bits)  : {binario}")
        print(f"Salida Hexadecimal : {hexa}")
    except ValueError as e:
        print(f"\nError: {e}")
    

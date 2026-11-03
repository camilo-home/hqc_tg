#!/usr/bin/env python3

def bin32(val):
    """Convierte un entero a un string binario de 32 bits, separado en bloques de 8 bits para mejor lectura."""
    b_str = f"{val:032b}"
    # Agrupa de a 8 bits: "00000000 00000000 00000000 00000000"
    return f"{b_str[0:8]} {b_str[8:16]} {b_str[16:24]} {b_str[24:32]}"

def main():
    print("=== SIMULADOR DE MULTIPLICACIÓN POLINOMIAL (VHDL EMULATOR) ===")
    
    # 1. Solicitar parámetros
    try:
        wt = int(input("Ingrese la cantidad de posiciones (WT) [ej. 3]: "))
        word_count = int(input("Ingrese la cantidad de palabras densas (WORD_COUNT) [ej. 3]: "))
    except ValueError:
        print("Error: Ingrese números enteros válidos.")
        return

    # 2. Solicitar las posiciones
    positions = []
    print(f"\nIngrese las {wt} posiciones en formato decimal:")
    for i in range(wt):
        while True:
            try:
                pos = int(input(f"  Posición {i}: "))
                positions.append(pos)
                break
            except ValueError:
                print("  -> Ingrese un entero válido.")

    # 3. Solicitar las palabras densas
    dense_memory = []
    print(f"\nIngrese las {word_count} palabras densas en formato Hexadecimal (sin '0x'):")
    for i in range(word_count):
        while True:
            try:
                hex_str = input(f"  Word {i}: ")
                val = int(hex_str, 16)
                dense_memory.append(val)
                break
            except ValueError:
                print("  -> Ingrese un valor hexadecimal válido.")

    # 4. Inicializar el Acumulador (Fase 1 usa el doble de memoria)
    acc = [0] * (2 * word_count)

    # 5. Fase 1: Multiplicación y Desplazamiento
    print("\n" + "="*70)
    print(" FASE 1: PROCESAMIENTO DE POSICIONES Y ACUMULACIÓN")
    print("="*70)

    for p_idx, pos in enumerate(positions):
        # Descomponer la posición en offset de palabra y offset de bit
        word_offset = pos >> 5   # Equivalente a pos // 32
        bit_offset = pos & 31    # Equivalente a pos % 32
        
        print(f"\n--- Posición {p_idx}: Valor = {pos} (Word_Offset: {word_offset}, Bit_Offset: {bit_offset}) ---")
        
        for word_cnt in range(word_count):
            dense_val = dense_memory[word_cnt]
            
            # Aplicar desplazamientos limitados a 32 bits (como en VHDL)
            if bit_offset == 0:
                lower = dense_val
                upper = 0
            else:
                lower = (dense_val << bit_offset) & 0xFFFFFFFF
                upper = (dense_val >> (32 - bit_offset)) & 0xFFFFFFFF
            
            addr_a = word_cnt + word_offset
            addr_b = word_cnt + word_offset + 1
            
            print(f"  [Word_cnt {word_cnt}] Leyendo Dense_Mem[{word_cnt}]: {bin32(dense_val)} | Hex: {dense_val:08X}")
            
            if bit_offset == 0:
                print(f"    -> Alineado (Shift=0).   Lower (Acc[{addr_a}]): {bin32(lower)}")
            else:
                print(f"    -> Shift Left  ({bit_offset:2d}) -> Lower (Acc[{addr_a}]): {bin32(lower)}")
                print(f"    -> Shift Right ({32-bit_offset:2d}) -> Upper (Acc[{addr_b}]): {bin32(upper)}")
            
            # Operación XOR en la memoria
            acc[addr_a] ^= lower
            acc[addr_b] ^= upper

        # Mostrar el vector acumulador completo después de procesar esta posición
        print("\n  >> Estado del Vector Acumulador (después de posición):")
        for i in range(len(acc)):
            if acc[i] != 0:
                print(f"      Acc[{i:2d}]: {bin32(acc[i])} (Hex: {acc[i]:08X})")
            else:
                print(f"      Acc[{i:2d}]: {bin32(0)}")

    # 6. Fase 2: Reducción (Plegado XOR)
    print("\n" + "="*70)
    print(" FASE 2: REDUCCIÓN (Plegado de la Parte Alta sobre la Baja)")
    print("="*70)
    
    for i in range(word_count):
        val_low = acc[i]
        val_high = acc[i + word_count]
        acc[i] ^= val_high
        print(f"  Acc[{i:2d}] = Low: {bin32(val_low)}  XOR  High(Acc[{i+word_count:2d}]): {bin32(val_high)}")
        print(f"           -> Resultado: {bin32(acc[i])} (Hex: {acc[i]:08X})\n")

    # 7. Resultado Final
    print("="*70)
    print(" ESTADO FINAL EN MEMORIA (Parte Baja)")
    print("="*70)
    for i in range(word_count):
        print(f"  Word[{i:2d}]: {bin32(acc[i])} | Hex: {acc[i]:08X}")
    print("="*70)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Multiplicador Polinomial en Anillo F2[x] / (x^n - 1)
Especialmente diseñado para criptografía post-cuántica (HQC)
"""

def bits_to_poly_str(bits_int, max_bits):
    terms = []
    for i in range(max_bits):
        if (bits_int >> i) & 1:
            if i == 0:
                terms.append("1")
            elif i == 1:
                terms.append("x")
            else:
                terms.append(f"x^{i}")
    return " + ".join(terms) if terms else "0"

def cyclic_shift_left(val, shift, n):
    shift = shift % n
    # Rotación a la izquierda de n bits
    return ((val << shift) & ((1 << n) - 1)) | (val >> (n - shift))

def main():
    print("=== Multiplicación Polinomial en Anillo F2[x] / (x^n - 1) ===")
    
    # 1. Entradas del usuario
    try:
        n = int(input("Ingrese el tamaño del anillo (n, ej. 128 o 17669): ").strip())
    except ValueError:
        n = 128
        print(f"Usando n por defecto: {n}")

    pos_input = input("Ingrese las posiciones de 1s del vector disperso separadas por coma (ej. 3, 15): ").strip()
    positions = [int(p.strip()) for p in pos_input.split(",") if p.strip()]
    
    hex_dense = input(f"Ingrese el vector denso en hexadecimal (debe representar {n} bits, es decir, {n//4} caracteres hex): ").strip()
    
    # Convertir hex a entero de n bits
    # Asegurarse de que el string hex tenga el tamaño adecuado o rellenarlo
    dense_int = int(hex_dense, 16)
    
    print("\n" + "="*60)
    print("--- REPRESENTACIÓN POLINÓMICA DE ENTRADA ---")
    print("="*60)
    
    # Vector disperso A(x)
    sparse_val = 0
    for p in positions:
        sparse_val |= (1 << p)
    print(f"Vector Disperso A(x):")
    print(f"  - Posiciones activas: {positions}")
    print(f"  - Polinomio A(x)    : {bits_to_poly_str(sparse_val, n)}")
    
    # Vector denso B(x)
    print(f"\nVector Denso B(x):")
    print(f"  - Hexadecimal       : 0x{hex_dense}")
    print(f"  - Binario (n={n})   : {bin(dense_int)[2:].zfill(n)}")
    print(f"  - Polinomio B(x)    : {bits_to_poly_str(dense_int, n)}")
    
    print("\n" + "="*60)
    print("--- PROCESO DE SHIFTS Y DESBORDAMIENTO CIRCULAR (ANILLO) ---")
    print("="*60)
    
    final_result_int = 0
    
    for idx, pos in enumerate(positions):
        # Desplazamiento circular (shift con desborde reentrante por el inicio)
        shifted_val = cyclic_shift_left(dense_int, pos, n)
        final_result_int ^= shifted_val
        
        print(f"\n[Shift {idx+1}] Multiplicación por x^{pos} (Rotación izquierda de {pos} bits):")
        print(f"  - Binario resultante : {bin(shifted_val)[2:].zfill(n)}")
        print(f"  - Polinomio parcia l : {bits_to_poly_str(shifted_val, n)}")
        
    print("\n" + "="*60)
    print("--- RESULTADO FINAL DE LA MULTIPLICACIÓN EN ANILLO ---")
    print("="*60)
    print(f"Binario (n={n}) : {bin(final_result_int)[2:].zfill(n)}")
    print(f"Polinomio C(x)  : {bits_to_poly_str(final_result_int, n)}")
    print("="*60)

if __name__ == "__main__":
    main()

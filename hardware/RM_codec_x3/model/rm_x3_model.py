"""Modelo bit-exacto (Python) de RMEncoder/RMDecoder VHDL con multiplicidad rep.
Replica los mismos indices: butterfly, xor de pares, voter (>width/2), padding, latencias.
Sirve para verificar la logica antes de simular el VHDL."""
import random, sys, math
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rm_hqc128 import rm_encode as hqc_rm_encode, rm_decode as hqc_rm_decode  # referencia HQC

def ceil_log2(n):
    r, v = 0, 1
    while v < n:
        v *= 2; r += 1
    return r

def gen_matrix(m, g01):
    n = 2**m
    G = [[0]*n for _ in range(m+1)]
    for i in range(n):
        for j in range(m+1):
            bit = ((i + n) >> (m-j)) & 1
            pos = n-i-1 if g01 else i
            G[j][pos] = bit
    return G                      # G[j][pos]

def encode(data, m, rep, g01):
    G = gen_matrix(m, g01)
    n = 2**m
    cw = [0]*n
    for i in range(m+1):
        if (data >> i) & 1:
            for p in range(n):
                cw[p] ^= G[m-i][p]
    bits = cw * rep                # copia 0 en los bits bajos
    return bits                    # lista, indice = posicion de bit

def butterfly(vec):                # ButterflyCell: swapped = cell1 & cell0 (pares | impares)
    return vec[0::2] + vec[1::2]

def swapped_levels(copy, m):
    levels = [list(copy)]
    for i in range(m-1):
        prev = levels[-1]
        blk = 2**(m-i)
        nxt = []
        for j in range(2**i):
            nxt += butterfly(prev[j*blk:(j+1)*blk])
        levels.append(nxt)
    return levels

def voter(bits, width):
    """majority_voter con padding a 4*2^levels. Devuelve (majority, levels)."""
    n_nibble = (width + 3)//4
    levels = ceil_log2(n_nibble)
    pad = 4 * 2**levels
    padded = list(bits) + [0]*(pad-len(bits))
    cnt = sum(padded)
    cnt_bits = 3 + levels
    assert cnt < 2**cnt_bits and width//2 < 2**cnt_bits
    return int(cnt > width//2), levels

def decode(bits, m, rep, g01):
    n = 2**m
    G = gen_matrix(m, g01)
    copies = [bits[c*n:(c+1)*n] for c in range(rep)]
    lv = [swapped_levels(cp, m) for cp in copies]
    maj = []
    for i in range(m):
        votes = []
        for c in range(rep):
            row = lv[c][i]
            votes += [row[2*j] ^ row[2*j+1] for j in range(n//2)]
        mj, _ = voter(votes, rep*n//2)
        maj.append(mj)
    resid = list(bits)
    for i in range(m):
        if maj[i]:
            for c in range(rep):
                for p in range(n):
                    resid[c*n+p] ^= G[m-i][p]
    am, _ = voter(resid, rep*n)
    return am << m | sum(maj[i] << i for i in range(m))

def main():
    rnd = random.Random(11)
    # 1) latencias: rep=1 debe dar m-3 y m-2 (compatibilidad con el original); rep=3 -> 6 y 7
    for m in (4, 5, 6, 7):
        assert ceil_log2((2**(m-1)+3)//4) == m-3 and ceil_log2((2**m+3)//4) == m-2
    L1 = ceil_log2((3*64+3)//4); L2 = ceil_log2((3*128+3)//4)
    print(f"latencias rep=3,m=7: L1={L1} L2={L2} total={L1+L2+1}")

    # 2) encoder == HQC rm_encode (generator_matrix_01=false, rep=3)
    for _ in range(50):
        msg = bytes(rnd.randrange(256) for _ in range(46))
        ref = hqc_rm_encode(msg)
        got = 0
        for i, b in enumerate(msg):
            bits = encode(b, 7, 3, False)
            for p, v in enumerate(bits):
                got |= v << (i*384 + p)
        assert got == ref
    print("OK encoder VHDL (g01=false, rep=3) == rm_encode de hqc128.py")
    # g01=true da la tabla invertida (0x5555.. en vez de 0xAAAA..)
    b = encode(1, 7, 3, True)
    print("g01=true, dato 1 -> primeros 8 bits:", b[:8], "(HQC espera 0,1,0,1,... => usar g01=false)")

    # 3) decoder sin errores, todos los bytes, ambos g01
    for g01 in (False, True):
        for x in range(256):
            assert decode(encode(x, 7, 3, g01), 7, 3, g01) == x
    print("OK roundtrip 0..255 sin errores (g01 false/true)")

    # 4) errores aleatorios por palabra de 384 bits, y decoder HQC como referencia
    for ne in (30, 60, 95):
        for _ in range(300):
            x = rnd.randrange(256)
            bits = encode(x, 7, 3, False)
            for p in rnd.sample(range(384), ne):
                bits[p] ^= 1
            assert decode(bits, 7, 3, False) == x, (ne, x)
    print("OK hasta 95 errores aleatorios: siempre correcto")

    # 5) ataque adversario: 95 errores concentrados en una sola copia, y el patron del testbench
    for x in (0, 1, 0x55, 0xAA, 0xFF, 0x80, 0x7F):
        bits = encode(x, 7, 3, False)
        for p in range(95): bits[p] ^= 1                  # 95 en la copia 0
        assert decode(bits, 7, 3, False) == x
        bits = encode(x, 7, 3, False)
        for k in range(95): bits[4*k] ^= 1                # patron del testbench
        assert decode(bits, 7, 3, False) == x
    print("OK 95 errores concentrados / patron tb_RMDecoder")

    # 6) mas alla de 95: tasa de fallo del modelo (majority-logic) vs decoder HQC (ML/WHT)
    for ne in (96, 110, 130, 150):
        f_vhdl = f_hqc = 0
        T = 200
        for _ in range(T):
            x = rnd.randrange(256)
            bits = encode(x, 7, 3, False)
            for p in rnd.sample(range(384), ne):
                bits[p] ^= 1
            f_vhdl += decode(bits, 7, 3, False) != x
            cw = sum(v << k for k, v in enumerate(bits))
            msg = bytes([x]) + bytes(45)
            # el decoder HQC espera 46 bloques: rellenamos el resto con ceros codificados
            full = hqc_rm_encode(bytes([x]) + bytes(45)) & ~((1 << 384) - 1) | cw
            f_hqc += hqc_rm_decode(full)[0] != x
        print(f"{ne} errores: fallos majority-logic {f_vhdl}/{T}, WHT-HQC {f_hqc}/{T}")

if __name__ == "__main__":
    main()

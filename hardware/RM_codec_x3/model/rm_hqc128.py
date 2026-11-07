# rm_hqc128.py
# Reed-Muller RM(1,7) duplicado (x3) extraido de hqc128.py, para depurar de forma aislada.
#
# Estructura del codigo concatenado de HQC-128:
#   mensaje (n1 = 46 bytes, salida de RS) --RM--> n1 * n2 = 46 * 384 = 17664 bits
#   Cada byte -> palabra RM(1,7) de 128 bits -> repetida n2/128 = 3 veces (384 bits)
#
# El codeword se representa como un entero Python (bit 0 = menos significativo),
# igual que en el original.

import random

N1 = 46
N2 = 384
REP = N2 // 128  # 3 repeticiones de la palabra de 128 bits

# Bit i del byte -> funcion booleana base (i=0..6: x_i; i=7: constante 1)
HQC_RM_TAB = [
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
    0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC,
    0xF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0,
    0xFF00FF00FF00FF00FF00FF00FF00FF00,
    0xFFFF0000FFFF0000FFFF0000FFFF0000,
    0xFFFFFFFF00000000FFFFFFFF00000000,
    0xFFFFFFFFFFFFFFFF0000000000000000,
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
]


def rm_encode(msg, n1=N1, n2=N2):
    """msg: bytes de longitud n1. Devuelve entero de n1*n2 bits."""
    assert len(msg) == n1, f"msg debe tener {n1} bytes, tiene {len(msg)}"
    rep = n2 // 128
    r = 0
    p = 0
    for x in msg:
        y = 0
        for i in range(8):
            if (x >> i) & 1:
                y ^= HQC_RM_TAB[i]
        for _ in range(rep):
            r ^= y << p
            p += 128
    return r


def rm_decode(cw, n1=N1, n2=N2):
    """cw: entero con n1*n2 bits. Devuelve bytearray de n1 bytes.
    Decodificacion por maxima verosimilitud: suma de repeticiones + Hadamard (WHT)."""
    m = []
    rep = n2 // 128
    for i in range(n1):
        # 1) acumular las repeticiones: s[k] = numero de unos en la posicion k
        s = [0] * 128
        for j in range(0, n2, 128):
            for k in range(128):
                s[k] += (cw >> ((i * n2) + j + k)) & 1

        # 2) transformada de Walsh-Hadamard (7 etapas)
        for _ in range(7):
            s0, s1 = [], []
            for k in range(0, 128, 2):
                s0.append(s[k] + s[k + 1])
                s1.append(s[k] - s[k + 1])
            s = s0 + s1

        # 3) quitar el sesgo del coeficiente 0 (0/1 -> +-1)
        s[0] -= 64 * rep

        # 4) buscar el coeficiente de mayor magnitud
        x, y, z = 0, -1, 0
        for j in range(128):
            if abs(s[j]) > y:
                x = j
                z = s[x]
                y = abs(z)
        # el signo decide el bit 7 (constante 1)
        if z > 0:
            x += 128
        m.append(x)
    return bytearray(m)


# ---------------------------------------------------------------- utilidades de depuracion

def flip_bits(cw, positions):
    for p in positions:
        cw ^= 1 << p
    return cw


def block_bits(cw, i, n2=N2):
    """Bits (lista de 0/1) del bloque i (n2 bits)."""
    return [(cw >> (i * n2 + k)) & 1 for k in range(n2)]


def main():
    rnd = random.Random(1)

    # 1) Roundtrip sin errores
    for t in range(200):
        msg = bytes(rnd.randrange(256) for _ in range(N1))
        cw = rm_encode(msg)
        assert cw < (1 << (N1 * N2))
        assert bytes(rm_decode(cw)) == msg, f"roundtrip fallo en {t}"
    print("OK roundtrip sin errores (200 mensajes)")

    # 2) Todos los valores de byte (0..255) en todas las posiciones de bloque
    msg = bytes(range(N1))
    for base in range(0, 256, N1):
        msg = bytes((base + i) % 256 for i in range(N1))
        assert bytes(rm_decode(rm_encode(msg))) == msg
    print("OK barrido de valores de byte")

    # 3) Con errores aleatorios por bloque (capacidad: distancia minima 64*3=192 -> corrige hasta 95)
    for nerr in (10, 50, 90, 95, 96, 120):
        fails = 0
        trials = 100
        for _ in range(trials):
            msg = bytes(rnd.randrange(256) for _ in range(N1))
            cw = rm_encode(msg)
            for i in range(N1):
                pos = rnd.sample(range(N2), nerr)
                cw = flip_bits(cw, [i * N2 + p for p in pos])
            if bytes(rm_decode(cw)) != msg:
                fails += 1
        print(f"errores por bloque={nerr:3d}: bloques-mensaje fallidos {fails}/{trials}")

    # 4) Ejemplo puntual para inspeccionar
    msg = bytes([0xA5] * N1)
    cw = rm_encode(msg)
    print("bloque 0 (128 bits primeros) =", hex(cw & ((1 << 128) - 1)))
    print("decode =", rm_decode(cw)[:4].hex(), "...")


if __name__ == "__main__":
    main()

# concat_hqc128.py : codigo concatenado RS (externo) + RM (interno) de HQC-128, aislado.
#   mensaje (16 B) --rs_encode--> 46 B --rm_encode--> 17664 bits
#   canal con ruido -> rm_decode -> 46 B -> rs_decode -> 16 B
import random
from rs_hqc128 import rs_encode, rs_decode, K, N1
from rm_hqc128 import rm_encode, rm_decode, N2


def encode(m):
    return rm_encode(rs_encode(m))


def decode(cw):
    return bytes(rs_decode(rm_decode(cw)))


def main():
    rnd = random.Random(3)
    nbits = N1 * N2
    for p in (0.0, 0.10, 0.20, 0.30, 0.35, 0.40, 0.45):
        fails, trials = 0, 20
        for _ in range(trials):
            m = bytes(rnd.randrange(256) for _ in range(K))
            cw = encode(m)
            # ruido binario simetrico de probabilidad p
            noise = int.from_bytes(bytes(rnd.getrandbits(8) for _ in range((nbits + 7) // 8)), 'little')
            if p == 0.0:
                noise = 0
            else:
                noise = 0
                for i in range(nbits):
                    if rnd.random() < p:
                        noise |= 1 << i
            if decode(cw ^ noise) != m:
                fails += 1
        print(f"BER={p:.2f}: fallos {fails}/{trials}")


if __name__ == "__main__":
    main()

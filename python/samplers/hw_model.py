# Modelo a nivel algoritmo/gearbox de lo que hara el hardware, comparado con hqc128.py
import hashlib, random, sys

class XOF:                       # equivalente a SHAKE256.new(seed+b'\x01') con read()
    def __init__(s, seed):
        s.d = hashlib.shake_256(seed + b'\x01').digest(40000); s.p = 0
    def read(s, n):
        r = s.d[s.p:s.p+n]; s.p += n; return r
    def words(s):                # palabras de 64 bits (LE) como las daria el SHAKE al sampler
        return s

def ref_get_bytes(x, sz):        # xof_get_bytes de la referencia
    b = x.read(sz)
    if sz % 8: x.read(8 - sz % 8)
    return b

def ref_mod(x, n, wt):
    r = ref_get_bytes(x, 4*wt); supp = []
    for i in range(wt):
        u = int.from_bytes(r[4*i:4*i+4], 'little'); supp.append(((u*(n-i)) >> 32) + i)
    for i in range(wt-1, -1, -1):
        for j in range(i+1, wt):
            if supp[i] == supp[j]: supp[i] = i; break
    return set(supp)

def ref_rej(x, n, wt):
    n_rej = (2**24 // n) * n; v = set(); i = 0; j = 3*wt
    while i < wt:
        if j >= 3*wt: b = ref_get_bytes(x, 3*wt); j = 0
        sup = int.from_bytes(b[j:j+3], 'big'); j += 3
        if sup < n_rej:
            sup %= n
            if sup not in v: v.add(sup); i += 1
    return v

class WordStream:                # lo que ve el sampler: palabras de 64 bits con handshake
    def __init__(s, x): s.x = x; s.taken = 0
    def pop(s):
        s.taken += 1; return int.from_bytes(s.x.read(8), 'little')

# ---------------- modelo HW: mod ----------------
def hw_mod(ws, n, wt):
    nw = (wt + 1)//2
    raw = []                                   # fase 1: pos_mem[i] = raw
    words = [ws.pop() for _ in range(nw)]      # exactamente NW palabras
    for i in range(wt):
        w = words[i//2]; u = (w >> 32) if i % 2 else (w & 0xFFFFFFFF)
        raw.append(((u*(n-i)) >> 32) + i)
    bm = set(); fin = list(raw)                # fase 2: i descendente + bitmap
    for i in range(wt-1, -1, -1):
        p = raw[i]
        if p in bm: p = i
        bm.add(p); fin[i] = p
    return set(fin), len(fin) == len(set(fin))

# ---------------- modelo HW: rej ----------------
def hw_rej(ws, n, wt):
    n_rej = (2**24 // n) * n; n32 = 2**32 // n
    NWB = (3*wt + 7)//8; NC = wt                # palabras y candidatos por lote (25 y 66)
    buf = bytearray(); bw = 0; bc = 0; i = 0; bm = set(); out = []
    maxr = 0
    while True:
        while len(buf) < 3:                      # S_GET/FILL
            assert bw < NWB
            buf += ws.pop().to_bytes(8, 'little'); bw += 1
        u24 = int.from_bytes(buf[:3], 'big'); del buf[:3]; bc += 1   # S_TAKE (BE)
        if u24 < n_rej:
            q = (u24*n32) >> 32
            r = u24 - q*n; maxr = max(maxr, r)
            p = r - n if r >= n else r           # correccion Barrett
            assert 0 <= p < n
            if p not in bm:
                bm.add(p); out.append(p); i += 1
                if i == wt: break
        if bc == NC:                             # lote agotado, hace falta otro
            buf = bytearray(); bw = 0; bc = 0
    while bw < NWB: ws.pop(); bw += 1           # S_DRAIN
    return set(out)

def run(n, wt_mod, wt_rej, trials, seed0=0):
    bad = 0
    for t in range(trials):
        seed = (seed0*1000003 + t).to_bytes(8, 'little')
        # mod: 3 llamadas consecutivas (r2, e, r1) sobre el mismo XOF
        xr, xh = XOF(seed), XOF(seed); ws = WordStream(xh)
        for _ in range(3):
            a = ref_mod(xr, n, wt_mod); b, ok = hw_mod(ws, n, wt_mod)
            if a != b or not ok or ws.taken*8 != xr.p: bad += 1; print('MOD mismatch', t)
        # rej: 2 llamadas (y, x)
        xr, xh = XOF(seed), XOF(seed); ws = WordStream(xh)
        for _ in range(2):
            a = ref_rej(xr, n, wt_rej); b = hw_rej(ws, n, wt_rej)
            if a != b or ws.taken*8 != xr.p: bad += 1; print('REJ mismatch', t, ws.taken*8, xr.p)
    return bad

if __name__ == '__main__':
    print('HQC-128 real  n=17669 :', 'fallos =', run(17669, 75, 66, 3000))
    print('estres  n=300 (muchas colisiones/lotes extra) :', 'fallos =', run(300, 75, 66, 3000, 7))

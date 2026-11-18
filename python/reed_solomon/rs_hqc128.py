# rs_hqc128.py
# Reed-Solomon de HQC-128 extraido de hqc128.py, para depurar de forma aislada.
# RS[46, 16] sobre GF(2^8), polinomio primitivo 0x11D, alpha = 2, capacidad delta = 15 simbolos.
#
# Codigo sistematico: salida = [46-16 = 30 simbolos de paridad] + [16 simbolos de mensaje]

N1 = 46
K = 16
DELTA = 15
ALPHA = 2


# ------------------------------------------------------------------ GF(2^8)

def gf_mul(a, b):
    r = a & (-(b & 1))
    for i in range(1, 8):
        a = (a << 1) ^ ((-(a >> 7)) & 0x11D)
        r ^= a & (-((b >> i) & 1))
    return r


def gf_exp(a, e):
    r = 1
    if e & 1:
        r = a
    e >>= 1
    while e > 0:
        a = gf_mul(a, a)
        if e & 1:
            r = gf_mul(r, a)
        e >>= 1
    return r


def gf_inv(x):
    return gf_exp(x, 254)


def gf_gauss(m):
    r = len(m)
    c = len(m[0])
    for i in range(r):
        j = i
        while j < r and m[j][i] == 0:
            j += 1
        if j >= r:
            continue
        if j > i:
            m[i], m[j] = m[j], m[i]
        x = gf_inv(m[i][i])
        for k in range(c):
            m[i][k] = gf_mul(x, m[i][k])
        for j in range(r):
            if i == j or m[j][i] == 0:
                continue
            x = m[j][i]
            for k in range(c):
                m[j][k] ^= gf_mul(x, m[i][k])
    return m


# ------------------------------------------------------------------ Codificador

def rs_genpoly(t):
    f = bytearray([1])
    a = 1
    for i in range(t):
        a = gf_mul(a, ALPHA)
        f.insert(0, 0)
        for j in range(i + 1):
            f[j] ^= gf_mul(a, f[j + 1])
    return f


RS_GEN = rs_genpoly(2 * DELTA)


def rs_encode(msg, n1=N1, k=K, gen=RS_GEN):
    """msg: k bytes. Devuelve n1 bytes (paridad + mensaje)."""
    assert len(msg) == k, f"msg debe tener {k} bytes"
    y = bytearray(n1 - k)
    for i in range(k):
        x = msg[k - 1 - i] ^ y[-1]
        y = bytearray(1) + y[:-1]
        for j in range(n1 - k):
            y[j] ^= gf_mul(x, gen[j])
    return y + bytearray(msg)


# ------------------------------------------------------------------ Decodificador

def rs_synd(cw, t=None, n1=N1):
    ai = 1
    if t is None:
        t = 2 * DELTA
    s = bytearray(t)
    for i in range(t):
        ai = gf_mul(ai, ALPHA)
        aij = ai
        x = cw[0]
        for j in range(1, n1):
            x ^= gf_mul(cw[j], aij)
            aij = gf_mul(aij, ai)
        s[i] = x
    return s


def rs_elp(syn, delta=DELTA):
    """Polinomio localizador de errores (Berlekamp-Massey en tiempo constante)."""
    d_sig = 0
    d_sig_p = 0
    d_sig_t = 0
    x_sig_p = bytearray(b'\0\1') + bytearray(delta)
    sig = bytearray(b'\1') + bytearray(delta)
    pp = -1
    dp = 1
    for mu in range(2 * delta):
        d = syn[mu]
        for i in range(min(mu, delta)):
            d ^= gf_mul(sig[i + 1], syn[mu - i - 1])
        sig_t = sig[:delta].copy()
        d_sig_t = d_sig
        dd = gf_mul(d, gf_inv(dp))
        for i in range(min(mu + 1, delta)):
            sig[i + 1] ^= gf_mul(dd, x_sig_p[i + 1])
        d_x = mu - pp
        d_x_sig_p = d_x + d_sig_p
        if d != 0 and d_x_sig_p > d_sig:
            d_sig = d_x_sig_p
            pp = mu
            dp = d
            x_sig_p = b'\0' + sig_t
            d_sig_p = d_sig_t
        else:
            x_sig_p = b'\0' + x_sig_p[:-1]
    return sig


def rs_roots(sig, n1=N1):
    """Posiciones de error (indices 0..n1-1)."""
    l = []
    deg = len(sig) - 1
    while deg > 0 and sig[deg] == 0:
        deg -= 1
    if deg == 0:
        return l
    x = 1
    g = gf_inv(ALPHA)
    for a in range(n1):
        y = sig[deg]
        for i in range(deg - 1, -1, -1):
            y = gf_mul(y, x)
            y ^= sig[i]
        if y == 0:
            l.append(a)
        x = gf_mul(x, g)
    return l


def rs_decode(cw, k=K):
    """cw: n1 bytes (se modifica en sitio). Devuelve los k bytes de mensaje corregidos."""
    cw = bytearray(cw)
    syn = rs_synd(cw)
    sig = rs_elp(syn)
    ep = rs_roots(sig)
    ne = len(ep)
    if ne == 0:
        return cw[-k:]

    sm = []
    for i in range(ne):
        v = bytearray(len(cw))
        v[ep[i]] = 1
        u = bytearray(ne)
        u[i] = 1
        sm.append(rs_synd(v, ne) + u)

    gf_gauss(sm)

    ev = bytearray(ne)
    for i in range(ne):
        x = syn[i]
        for kk in range(ne):
            ev[kk] ^= gf_mul(x, sm[i][ne + kk])

    for i in range(ne):
        cw[ep[i]] ^= ev[i]
    return cw[-k:]


# ------------------------------------------------------------------ pruebas

def main():
    import random
    rnd = random.Random(7)
	encoded = rs_encode('\x74\xb2\xd3\x52\xcf\x74\xc9\x34\x06\x9c\x9d\xe7\x47\x57\xf5\x05')
	print(encoded)

    # 1) Sin errores
    for _ in range(100):
        m = bytes(rnd.randrange(256) for _ in range(K))
        c = rs_encode(m)
        assert len(c) == N1 and bytes(c[-K:]) == m
        assert all(s == 0 for s in rs_synd(c)), "sindrome no nulo en palabra valida"
        assert bytes(rs_decode(c)) == m
    print("OK sin errores (sindrome 0)")

    # 2) Con 1..DELTA errores de simbolo (deben corregirse siempre) y DELTA+1 (puede fallar)
    for ne in list(range(1, DELTA + 1)) + [DELTA + 1, DELTA + 3]:
        fails = 0
        trials = 100
        for _ in range(trials):
            m = bytes(rnd.randrange(256) for _ in range(K))
            c = rs_encode(m)
            for p in rnd.sample(range(N1), ne):
                c[p] ^= rnd.randrange(1, 256)
            if bytes(rs_decode(c)) != m:
                fails += 1
        print(f"simbolos erroneos={ne:2d}: fallos {fails}/{trials}"
              + ("   <- debe ser 0" if ne <= DELTA else "   (fuera de capacidad)"))
        if ne <= DELTA:
            assert fails == 0


if __name__ == "__main__":
    main()

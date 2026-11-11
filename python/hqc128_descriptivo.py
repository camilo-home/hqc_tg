# hqc128.py
# Implementacion especifica de HQC-128 compatible con test vectors

from Crypto.Hash import SHAKE256, SHA3_256, SHA3_512

class HQC128:
    def __init__(self):
        self.alg_id = 'HQC-128'
        self.lev = 1
        self.sec_sz = 16  # 4*1 + 12 = 16
        self.n = 17669
        self.n_sz = (17669 + 7) // 8  # 2209
        self.n_rej = (2**24 // 17669) * 17669  # 17669 * 948 = 16749912
        self.n1 = 46
        self.n2 = 384
        self.n1n2 = 46 * 384  # 17664
        self.n1n2_sz = (17664 + 7) // 8  # 2208
        self.w = 66
        self.w_e = 75
        self.w_r = 75
        self.k = 16
        self.delta = 15
        self.salt_sz = 16
        self.seed_sz = 32
        
        # parametros externos
        self.pk_sz = self.seed_sz + self.n_sz  # 32 + 2209 = 2241
        self.sk_sz = self.pk_sz + self.seed_sz + self.k + self.seed_sz  # 2241 + 32 + 16 + 32 = 2321
        self.ct_sz = self.n_sz + self.n1n2_sz + self.salt_sz  # 2209 + 2208 + 16 = 4433
        self.ss_sz = 32
        
        self.alpha = 0b10
        self.rs = self.rs_genpoly(self.delta * 2)

    # === Funciones internas

    def xof_init(self, seed=b''):
        xof = SHAKE256.new(seed + b'\01')
        return xof

    def xof_get_bytes(self, xof, sz):
        b = xof.read(sz)
        if sz % 8 != 0:
            xof.read(8 - sz % 8)
        return b

    def sample_fixed_wt_mod(self, xof, wt):
        rand_u32 = self.xof_get_bytes(xof, 4 * wt)
        supp = []
        for i in range(wt):
            u32 = int.from_bytes(rand_u32[4*i : 4*(i+1)], byteorder='little')
            supp += [ ((u32 * (self.n - i)) >> 32) + i ]
        
        for i in range(wt - 1, -1, -1):
            for j in range(i + 1, wt):
                if supp[i] == supp[j]:
                    supp[i] = i
                    break
        v = 0
        for i in range(wt):
            v |= 1 << supp[i]
        return v

    def sample_fixed_wt_rej(self, ctx_pke_dk, wt):
        v = 0
        i = 0
        j = 3 * wt
        while i < wt:
            if j >= (3 * wt):
                b = self.xof_get_bytes(ctx_pke_dk, 3 * wt)
                j = 0
            sup = int.from_bytes(b[j:j+3], byteorder='big')
            j += 3
            
            if sup < self.n_rej:
                sup %= self.n
                bit = 1 << sup
                if (v & bit) == 0:
                    v |= bit
                    i += 1
        return v

    def sample_vect(self, xof):
        v = self.xof_get_bytes(xof, self.n_sz)
        v = int.from_bytes(v, byteorder='little')
        v &= (1 << self.n) - 1
        return v

    def vect_mul(self, a, b):
        r = 0
        for i in range(self.n):
            if (a >> i) & 1:
                r ^= b << i
        r = (r ^ (r >> self.n)) & ((1 << self.n) - 1)
        return r

    def gf_mul(self, a, b):
        r = a & (-(b & 1))
        for i in range(1, 8):
            a = (a << 1) ^ ((-(a >> 7)) & 0x11D)
            r ^= a & (-((b >> i) & 1))
        return r

    def gf_exp(self, a, e):
        r = 1
        if e & 1:
            r = a
        e >>= 1
        while e > 0:
            a = self.gf_mul(a, a)
            if e & 1:
                r = self.gf_mul(r, a)
            e >>= 1
        return r

    def gf_inv(self, x):
        return self.gf_exp(x, 254)

    def gf_gauss(self, m):
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
            x = self.gf_inv(m[i][i])
            for k in range(c):
                m[i][k] = self.gf_mul(x, m[i][k])
            for j in range(r):
                if i == j or m[j][i] == 0:
                    continue
                x = m[j][i]
                for k in range(c):
                    m[j][k] ^= self.gf_mul(x, m[i][k])
        return m

    # === Coders

    def rs_genpoly(self, t):
        f = bytearray([1])
        a = 1
        for i in range(t):
            a = self.gf_mul(a, self.alpha)
            f.insert(0, 0)
            for j in range(i+1):
                f[j] ^= self.gf_mul(a, f[j + 1])
        return f

    def rs_encode(self, msg):
        y = bytearray(self.n1 - self.k)
        for i in range(self.k):
            x = msg[self.k - 1 - i] ^ y[-1]
            y = bytearray(1) + y[:-1]
            for j in range(self.n1 - self.k):
                y[j] ^= self.gf_mul(x, self.rs[j])
        return y + msg

    def rm_encode(self, msg):
        HQC_RM_TAB = [
            0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
            0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC,
            0xF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0,
            0xFF00FF00FF00FF00FF00FF00FF00FF00,
            0xFFFF0000FFFF0000FFFF0000FFFF0000,
            0xFFFFFFFF00000000FFFFFFFF00000000,
            0xFFFFFFFFFFFFFFFF0000000000000000,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ]
        r = 0
        p = 0
        rep = self.n2 // 128
        for x in msg:
            y = 0
            for i in range(8):
                if (x >> i) & 1:
                    y ^= HQC_RM_TAB[i]
            for _ in range(rep):
                r ^= y << p
                p += 128
        return r

    # === Decoders

    def rm_decode(self, cw):
        m = []
        for i in range(self.n1):
            s = [0] * 128
            for j in range(0, self.n2, 128):
                for k in range(128):
                    s[k] += (cw >> ((i * self.n2) + j + k)) & 1
            
            for j in range(7):
                s0, s1 = [], []
                for k in range(0, 128, 2):
                    s0 += [s[k] + s[k + 1]]
                    s1 += [s[k] - s[k + 1]]
                s = s0 + s1
            
            s[0] -= 64 * (self.n2 // 128)
            
            x, y, z = 0, -1, 0
            for j in range(128):
                if abs(s[j]) > y:
                    x = j
                    z = s[x]
                    y = abs(z)
            if z > 0:
                x += 128
            m += [x]
        return bytearray(m)

    def rs_synd(self, cw, t=None):
        ai = 1
        if t is None:
            t = 2 * self.delta
        s = bytearray(t)
        for i in range(t):
            ai = self.gf_mul(ai, self.alpha)
            aij = ai
            x = cw[0]
            for j in range(1, self.n1):
                x ^= self.gf_mul(cw[j], aij)
                aij = self.gf_mul(aij, ai)
            s[i] = x
        return s

    def rs_elp(self, syn):
        d_sig = 0
        d_sig_p = 0
        d_sig_t = 0
        x_sig_p = bytearray(b'\0\1') + bytearray(self.delta)
        sig = bytearray(b'\1') + bytearray(self.delta)
        
        pp = -1
        dp = 1
        
        for mu in range(2 * self.delta):
            d = syn[mu]
            for i in range(min(mu, self.delta)):
                d ^= self.gf_mul(sig[i + 1], syn[mu - i - 1])
            sig_t = sig[:self.delta].copy()
            d_sig_t = d_sig
            dd = self.gf_mul(d, self.gf_inv(dp))
            for i in range(min(mu + 1, self.delta)):
                sig[i + 1] ^= self.gf_mul(dd, x_sig_p[i + 1])
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

    def rs_roots(self, sig):
        l = []
        deg = len(sig) - 1
        while deg > 0 and sig[deg] == 0:
            deg -= 1
        if deg == 0:
            return l
        x = 1
        g = self.gf_inv(2)
        for a in range(self.n1):
            y = sig[deg]
            for i in range(deg - 1, -1, -1):
                y = self.gf_mul(y, x)
                y ^= sig[i]
            if y == 0:
                l += [a]
            x = self.gf_mul(x, g)
        return l

    def rs_decode(self, cw):
        syn = self.rs_synd(cw)
        sig = self.rs_elp(syn)
        ep = self.rs_roots(sig)
        ne = len(ep)
        if ne == 0:
            return cw[-self.k:]
        
        sm = []
        for i in range(ne):
            v = bytearray(len(cw))
            v[ep[i]] = 1
            u = bytearray(ne)
            u[i] = 1
            sm += [self.rs_synd(v, ne) + u]
        
        self.gf_gauss(sm)
        
        ev = bytearray(ne)
        for i in range(ne):
            x = syn[i]
            for k in range(ne):
                ev[k] ^= self.gf_mul(x, sm[i][ne + k])
        
        for i in range(ne):
            cw[ep[i]] ^= ev[i]
        
        m = cw[-self.k:]
        return m

    # === PKE

    def pke_keygen(self, seed_pke):
        i_res = SHA3_512.new(seed_pke + b'\02').digest()
        seed_pke_dk = i_res[0:32]
        seed_pke_ek = i_res[32:64]
        
        ctx_pke_dk = self.xof_init(seed_pke_dk)
        y = self.sample_fixed_wt_rej(ctx_pke_dk, self.w)
        x = self.sample_fixed_wt_rej(ctx_pke_dk, self.w)
        dk_pke = seed_pke_dk
        
        ctx_pke_ek = self.xof_init(seed_pke_ek)
        h = self.sample_vect(ctx_pke_ek)
        s = self.vect_mul(y, h) ^ x 
        ek_pke = seed_pke_ek + s.to_bytes(self.n_sz, byteorder='little')
        
        return ek_pke, dk_pke

    def keygen(self, prng):
        seed_kem = prng.read(self.seed_sz)
        ctx_kem = self.xof_init(seed_kem)
        seed_pke = ctx_kem.read(self.seed_sz)
        sigma = ctx_kem.read(self.sec_sz)
        
        ek_pke, dk_pke = self.pke_keygen(seed_pke)
        ek_kem = ek_pke
        dk_kem = ek_kem + dk_pke + sigma + seed_kem
        
        return ek_kem, dk_kem

    def pke_encrypt(self, ek_pke, m, theta):
        seed_pke_ek = ek_pke[0:self.seed_sz]
        ctx_pke_ek = self.xof_init(seed_pke_ek)
        h = self.sample_vect(ctx_pke_ek)
        s = int.from_bytes(ek_pke[self.seed_sz:self.seed_sz + self.n_sz], byteorder='little')
        
        ctx_th = self.xof_init(theta)
        r2 = self.sample_fixed_wt_mod(ctx_th, self.w_r)
        e = self.sample_fixed_wt_mod(ctx_th, self.w_e)
        r1 = self.sample_fixed_wt_mod(ctx_th, self.w_r)
        
        u = self.vect_mul(r2, h) ^ r1
        u = u.to_bytes(self.n_sz, byteorder='little')
        
        cm = self.rm_encode(self.rs_encode(m))
        v = cm ^ self.vect_mul(r2, s) ^ e
        v &= (1 << self.n1n2) - 1
        v = v.to_bytes(self.n1n2_sz, byteorder='little')
        
        c_pke = u + v
        return c_pke

    def kem_encaps(self, prng, ek_kem):
        m = prng.read(self.k)
        salt = prng.read(self.salt_sz)
        
        tmp_h = SHA3_256.new(ek_kem + b'\01').digest()
        tmp_g = SHA3_512.new(tmp_h + m + salt + b'\00').digest()
        kk = tmp_g[0:32]
        theta = tmp_g[32:64]
        
        c_pke = self.pke_encrypt(ek_kem, m, theta)
        c_kem = c_pke + salt
        
        return kk, c_kem

    def pke_decrypt(self, dk_pke, c_pke):
        seed_pke_dk = dk_pke[0:self.seed_sz]
        ctx_pke_dk = self.xof_init(seed_pke_dk)
        y = self.sample_fixed_wt_rej(ctx_pke_dk, self.w)
        
        u = int.from_bytes(c_pke[0:self.n_sz], byteorder='little')
        v = int.from_bytes(c_pke[self.n_sz:self.n_sz + self.n1n2_sz], byteorder='little')
        
        cm = v ^ self.vect_mul(y, u)
        m = self.rm_decode(cm)
        m = self.rs_decode(m)
        
        return m

    def kem_decaps(self, dk_kem, c_kem):
        ek_kem = dk_kem[0:self.pk_sz]
        dk_pke = dk_kem[self.pk_sz:self.pk_sz + self.seed_sz]
        sigma = dk_kem[self.pk_sz + self.seed_sz:self.pk_sz + self.seed_sz + self.sec_sz]
        
        c_pke = c_kem[0:self.n_sz + self.n1n2_sz]
        salt = c_kem[self.n_sz + self.n1n2_sz:self.ct_sz]
        
        m_p = self.pke_decrypt(dk_pke, c_pke)
        
        tmp_h = SHA3_256.new(ek_kem + b'\01').digest()
        tmp_g = SHA3_512.new(tmp_h + m_p + salt + b'\00').digest()
        kk_p = tmp_g[0:32]
        theta_p = tmp_g[32:64]
        
        c_pke_p = self.pke_encrypt(ek_kem, m_p, theta_p)
        c_kem_p = c_pke_p + salt
        
        k_rej = SHA3_256.new(tmp_h + sigma + c_kem + b'\03').digest()
        
        if m_p is None or c_kem_p != c_kem:
            kk_p = k_rej
        
        return kk_p


# =====================================================================
#  TRAZA DETALLADA (referencia para implementacion hardware)
#  La clase HQC128 de arriba NO se modifica. Todo lo de abajo replica el
#  flujo de keygen / kem_encaps / kem_decaps paso a paso, llamando a las
#  mismas primitivas, e imprime entradas, salidas y formatos.
#  Al final de cada corrida se verifica contra hqc.keygen/encaps/decaps.
#
#  Convenciones de formato:
#   - Todos los bytes se imprimen en hex MAYUSCULA, en el orden en que
#     estan en memoria (byte 0 primero).
#   - Vectores de n bits (F2[x]/(x^n-1)): serializacion little-endian,
#     el bit i del polinomio es el bit (i % 8) del byte (i // 8).
#   - "posiciones" = indices i (0..n-1) con coeficiente 1, ascendentes.
# =====================================================================
import sys
import argparse
import textwrap


class Salida:
    fh = None
    mute = False


def p(s=""):
    if Salida.mute:
        return
    print(s)
    if Salida.fh:
        Salida.fh.write(s + "\n")


def hdr1(t):
    p()
    p("#" * 100)
    p("# " + t)
    p("#" * 100)


def hdr2(t):
    p()
    p("=" * 100)
    p("== " + t)
    p("=" * 100)


def hdr3(t):
    p()
    p("-" * 100)
    p("-- " + t)
    p("-" * 100)


def lista(vals, ind="      "):
    return textwrap.fill(", ".join(str(x) for x in vals), width=100,
                         initial_indent=ind, subsequent_indent=ind)


def show_b(nombre, data, fmt):
    data = bytes(data)
    p(f"  {nombre}  [{len(data)} bytes] ({fmt})")
    p(f"    hex: {data.hex().upper()}")


def show_v(nombre, v, nbits, fmt, sparse):
    v &= (1 << nbits) - 1
    sz = (nbits + 7) // 8
    b = v.to_bytes(sz, 'little')
    wt = bin(v).count('1')
    p(f"  {nombre}  [vector de {nbits} bits = {sz} bytes] ({fmt})")
    p(f"    peso Hamming = {wt}")
    p(f"    hex (little-endian, bit i -> byte i//8, bit i%8): {b.hex().upper()}")
    if sparse:
        pos = [i for i in range(nbits) if (v >> i) & 1]
        p(f"    posiciones con bit=1 (ascendente, {len(pos)} en total):")
        p(lista(pos))


class XofTrace:
    """Envuelve un SHAKE256 y cuenta los bytes consumidos (incluye relleno)."""
    def __init__(self, xof):
        self.xof = xof
        self.consumed = 0
        self.calls = 0

    def read(self, n):
        self.consumed += n
        self.calls += 1
        return self.xof.read(n)


def prng_init(seed=None):
    """PRNG de test: SHAKE256(seed || 0x00)"""
    if seed is None:
        seed = bytes(range(48))
    return SHAKE256.new(seed + b'\00')


# ---------------------------------------------------------------------
#  Modulos con traza
# ---------------------------------------------------------------------
def t_params(hqc):
    hdr1("PARAMETROS HQC-128 (nivel 1)")
    p(f"  n = {hqc.n} (bits de los vectores)      n_sz = {hqc.n_sz} bytes")
    p(f"  n1 = {hqc.n1} (palabras RS, simbolos GF(256))   n2 = {hqc.n2} (bits por palabra RM duplicada)")
    p(f"  n1*n2 = {hqc.n1n2} bits = {hqc.n1n2_sz} bytes    k = {hqc.k} bytes (mensaje)    delta = {hqc.delta} (capacidad RS)")
    p(f"  w = {hqc.w} (peso de x,y)   w_r = {hqc.w_r}   w_e = {hqc.w_e}")
    p(f"  n_rej = {hqc.n_rej} (umbral de rechazo del muestreo por rechazo, 24 bits)")
    p(f"  seed_sz = {hqc.seed_sz}   sec_sz(sigma) = {hqc.sec_sz}   salt_sz = {hqc.salt_sz}")
    p(f"  pk = {hqc.pk_sz} B | sk = {hqc.sk_sz} B | ct = {hqc.ct_sz} B | ss = {hqc.ss_sz} B")
    p(f"  GF(256): polinomio primitivo 0x11D, alpha = {hqc.alpha}")
    p(f"  Polinomio generador RS (grado {2*hqc.delta}, f[0]..f[{2*hqc.delta}], coef. de menor a mayor grado):")
    p(f"    {bytes(hqc.rs).hex().upper()}")


def t_xof_init(hqc, etiqueta, seed):
    p(f"  XOF.init [{etiqueta}]: SHAKE256 absorbe  seed || 0x01")
    show_b("entrada absorbida", seed + b'\x01', f"{len(seed)}B semilla + 1B separador 0x01")
    return XofTrace(hqc.xof_init(seed))


def t_sample_rej(hqc, xof, wt, nombre):
    """Muestreo de peso fijo por rechazo (usado para x, y)."""
    p()
    p(f"  SAMPLE_FIXED_WT_REJ -> {nombre}")
    p(f"    entrada : flujo XOF, peso objetivo w = {wt}, n = {hqc.n}, n_rej = {hqc.n_rej}")
    p(f"    metodo  : bloques de 3*w = {3*wt} B (+relleno XOF a multiplo de 8); cada 3 B = candidato de 24 bits")
    p(f"              big-endian; si cand < n_rej -> pos = cand mod n; si pos ya estaba marcada se descarta")
    antes = xof.consumed
    v = 0
    i = 0
    j = 3 * wt
    b = b''
    aceptados = []
    rech_rango = 0
    rech_dup = 0
    bloques = 0
    while i < wt:
        if j >= 3 * wt:
            b = hqc.xof_get_bytes(xof, 3 * wt)
            j = 0
            bloques += 1
        raw = b[j:j + 3]
        cand = int.from_bytes(raw, byteorder='big')
        j += 3
        if cand < hqc.n_rej:
            pos = cand % hqc.n
            bit = 1 << pos
            if (v & bit) == 0:
                v |= bit
                i += 1
                aceptados.append((cand, pos))
            else:
                rech_dup += 1
        else:
            rech_rango += 1
    p(f"    candidatos aceptados, en orden de aparicion (k: cand24 hex / dec -> posicion):")
    for k, (cand, pos) in enumerate(aceptados):
        p(f"      k={k:02d}: 0x{cand:06X} / {cand:8d} -> pos {pos}")
    p(f"    rechazados por rango (cand >= n_rej): {rech_rango} | por duplicado: {rech_dup}")
    p(f"    bloques de {3*wt} B leidos: {bloques} | bytes consumidos del XOF en esta llamada: {xof.consumed - antes}")
    show_v(f"salida {nombre}", v, hqc.n, "vector disperso de peso w", True)
    return v


def t_sample_mod(hqc, xof, wt, nombre):
    """Muestreo de peso fijo por modulo (usado para r1, r2, e)."""
    p()
    p(f"  SAMPLE_FIXED_WT_MOD -> {nombre}")
    p(f"    entrada : flujo XOF, peso objetivo w = {wt}, n = {hqc.n}")
    p(f"    metodo  : lee 4*w = {4*wt} B (+relleno XOF a multiplo de 8); u32_i little-endian;")
    p(f"              pos_i = ((u32_i * (n - i)) >> 32) + i ; luego, de i=w-1 a 0, si pos_i coincide con algun")
    p(f"              pos_j (j>i) se reemplaza pos_i = i")
    antes = xof.consumed
    rand = hqc.xof_get_bytes(xof, 4 * wt)
    u32s = []
    supp = []
    for i in range(wt):
        u32 = int.from_bytes(rand[4 * i:4 * (i + 1)], byteorder='little')
        u32s.append(u32)
        supp.append(((u32 * (hqc.n - i)) >> 32) + i)
    ini = list(supp)
    colis = []
    for i in range(wt - 1, -1, -1):
        for j in range(i + 1, wt):
            if supp[i] == supp[j]:
                colis.append(i)
                supp[i] = i
                break
    v = 0
    for i in range(wt):
        v |= 1 << supp[i]
    show_b("bytes aleatorios leidos del XOF", rand, f"{wt} x u32 little-endian")
    p("    detalle por indice (i: u32 hex -> pos inicial -> pos final):")
    for i in range(wt):
        nota = "  <- colision, reemplazada por i" if i in colis else ""
        p(f"      i={i:02d}: 0x{u32s[i]:08X} -> {ini[i]:5d} -> {supp[i]:5d}{nota}")
    p(f"    colisiones corregidas: {len(colis)} | bytes consumidos del XOF en esta llamada: {xof.consumed - antes}")
    show_v(f"salida {nombre}", v, hqc.n, "vector disperso de peso w", True)
    return v


def t_sample_vect(hqc, xof, nombre):
    p()
    p(f"  SAMPLE_VECT -> {nombre}")
    p(f"    entrada : flujo XOF; lee n_sz = {hqc.n_sz} B (+relleno XOF a multiplo de 8)")
    p(f"    metodo  : interpreta los bytes como entero little-endian y pone a 0 los bits >= n")
    antes = xof.consumed
    raw = hqc.xof_get_bytes(xof, hqc.n_sz)
    v = int.from_bytes(raw, byteorder='little') & ((1 << hqc.n) - 1)
    p(f"    ultimo byte crudo = 0x{raw[-1]:02X} -> enmascarado = 0x{v.to_bytes(hqc.n_sz, 'little')[-1]:02X} "
      f"(se descartan {hqc.n_sz*8 - hqc.n} bits altos)")
    p(f"    bytes consumidos del XOF en esta llamada: {xof.consumed - antes}")
    show_v(f"salida {nombre}", v, hqc.n, "vector denso uniforme", False)
    return v


def t_vect_mul(hqc, a, b, na, nb, nr):
    p()
    p(f"  VECT_MUL: {nr} = {na} * {nb}  (producto ciclico en F2[x]/(x^{hqc.n} - 1))")
    p(f"    entradas: {na} (peso {bin(a).count('1')}), {nb} (peso {bin(b).count('1')}), ambos vectores de {hqc.n} bits")
    r = hqc.vect_mul(a, b)
    show_v(f"salida {nr}", r, hqc.n, "vector denso", False)
    return r


def t_rs_encode(hqc, m):
    p()
    p("  RS_ENCODE (codigo Reed-Solomon sistematico sobre GF(256))")
    show_b("entrada m", m, f"{hqc.k} simbolos GF(256), msg[0] primero")
    cw = hqc.rs_encode(m)
    show_b("salida palabra RS", cw, f"{hqc.n1} simbolos = [{hqc.n1 - hqc.k} B paridad][{hqc.k} B mensaje]")
    p(f"    paridad (bytes 0..{hqc.n1 - hqc.k - 1}): {bytes(cw[:hqc.n1 - hqc.k]).hex().upper()}")
    p(f"    mensaje (bytes {hqc.n1 - hqc.k}..{hqc.n1 - 1}): {bytes(cw[hqc.n1 - hqc.k:]).hex().upper()}")
    return cw


def t_rm_encode(hqc, cw):
    p()
    p("  RM_ENCODE (Reed-Muller RM(1,7) de 128 bits por simbolo, duplicado)")
    p(f"    entrada : {len(cw)} simbolos de 8 bits; cada simbolo -> palabra de 128 bits (tabla de 8 filas)")
    p(f"              repetida {hqc.n2 // 128} veces => {hqc.n2} bits por simbolo; total {hqc.n1n2} bits")
    p(f"    palabra RM de 128 bits por simbolo (16 B little-endian; la repeticion x{hqc.n2//128} es identica):")
    for i, x in enumerate(cw):
        w128 = hqc.rm_encode(bytes([x])) & ((1 << 128) - 1)
        p(f"      simbolo {i:02d} = 0x{x:02X} -> {w128.to_bytes(16, 'little').hex().upper()}")
    r = hqc.rm_encode(cw)
    show_v("salida cm (palabra concatenada)", r, hqc.n1n2, f"{hqc.n1} bloques de {hqc.n2} bits", False)
    return r


def t_rm_decode(hqc, cw):
    p()
    p("  RM_DECODE (decodificacion por transformada de Hadamard rapida, 46 bloques)")
    p(f"    entrada : cm' de {hqc.n1n2} bits ({hqc.n1} bloques x {hqc.n2} bits)")
    p(f"    metodo  : por bloque, suma las {hqc.n2 // 128} repeticiones por posicion (0..{hqc.n2 // 128}), 7 etapas de")
    p(f"              mariposa (s0=a+b, s1=a-b), s[0] -= {64 * (hqc.n2 // 128)}, pico = max |s[j]|;")
    p(f"              simbolo = idx del pico (+128 si el pico es positivo)")
    m = []
    p("    bloque | idx pico | valor pico | simbolo salida")
    for i in range(hqc.n1):
        s = [0] * 128
        for j in range(0, hqc.n2, 128):
            for k in range(128):
                s[k] += (cw >> ((i * hqc.n2) + j + k)) & 1
        for j in range(7):
            s0, s1 = [], []
            for k in range(0, 128, 2):
                s0 += [s[k] + s[k + 1]]
                s1 += [s[k] - s[k + 1]]
            s = s0 + s1
        s[0] -= 64 * (hqc.n2 // 128)
        x, y, z = 0, -1, 0
        for j in range(128):
            if abs(s[j]) > y:
                x = j
                z = s[x]
                y = abs(z)
        idx = x
        if z > 0:
            x += 128
        m.append(x)
        p(f"      {i:4d}   |   {idx:4d}   |   {z:6d}   | 0x{x:02X}")
    m = bytearray(m)
    show_b("salida (palabra RS recibida)", m, f"{hqc.n1} simbolos GF(256)")
    return m


def t_rs_decode(hqc, cw):
    p()
    p("  RS_DECODE (sindromes -> polinomio localizador (Berlekamp-Massey) -> raices -> valores de error)")
    cw = bytearray(cw)
    show_b("entrada palabra RS recibida", cw, f"{hqc.n1} simbolos")
    syn = hqc.rs_synd(cw)
    show_b("sindromes S_1..S_2delta", syn, f"{2 * hqc.delta} simbolos GF(256)")
    if not any(syn):
        p("    todos los sindromes son 0 -> no se detectan errores")
    sig = hqc.rs_elp(syn)
    show_b("polinomio localizador sigma (sig[0]=1)", sig, f"{hqc.delta + 1} coef., menor a mayor grado")
    ep = hqc.rs_roots(sig)
    ne = len(ep)
    p(f"    posiciones de error halladas (indice de simbolo en la palabra): {ep}  (ne = {ne}, capacidad delta = {hqc.delta})")
    if ne == 0:
        m = cw[-hqc.k:]
        show_b("salida m' (sin correcciones)", m, f"{hqc.k} simbolos")
        return m
    sm = []
    for i in range(ne):
        v = bytearray(len(cw))
        v[ep[i]] = 1
        u = bytearray(ne)
        u[i] = 1
        sm += [hqc.rs_synd(v, ne) + u]
    hqc.gf_gauss(sm)
    ev = bytearray(ne)
    for i in range(ne):
        x = syn[i]
        for k in range(ne):
            ev[k] ^= hqc.gf_mul(x, sm[i][ne + k])
    p("    correcciones (posicion: valor de error XOR):")
    for i in range(ne):
        p(f"      pos {ep[i]:2d}: 0x{ev[i]:02X}   (simbolo 0x{cw[ep[i]]:02X} -> 0x{cw[ep[i]] ^ ev[i]:02X})")
    for i in range(ne):
        cw[ep[i]] ^= ev[i]
    show_b("palabra RS corregida", cw, f"{hqc.n1} simbolos")
    m = cw[-hqc.k:]
    show_b("salida m' (ultimos k simbolos)", m, f"{hqc.k} simbolos")
    return m


def t_hash(nombre, clase, partes, etiquetas, fmt_out):
    entrada = b''.join(partes)
    p(f"  {nombre}")
    p("    entrada = " + " || ".join(f"{e}({len(x)}B)" for e, x in zip(etiquetas, partes)) + f"  => {len(entrada)} B")
    if len(entrada) <= 100:
        p(f"    entrada hex: {entrada.hex().upper()}")
    out = clase.new(entrada).digest()
    show_b("salida", out, fmt_out)
    return out


def t_pke_encrypt(hqc, ek, m, theta, cm_out=None):
    seed_ek = ek[0:hqc.seed_sz]
    show_b("ek_pke (entrada)", ek, f"[seed_ek {hqc.seed_sz}B][s {hqc.n_sz}B]")
    show_b("m (entrada)", m, f"{hqc.k} B")
    show_b("theta (entrada)", theta, "32 B, semilla del XOF de ruido")
    p(f"    seed_ek = {seed_ek.hex().upper()}")
    s_b = ek[hqc.seed_sz:hqc.seed_sz + hqc.n_sz]
    s = int.from_bytes(s_b, byteorder='little')
    show_v("s (leido de ek_pke)", s, hqc.n, "vector denso", False)

    hdr3("Regeneracion de h desde seed_ek")
    xof_ek = t_xof_init(hqc, "ek", seed_ek)
    h = t_sample_vect(hqc, xof_ek, "h")

    hdr3("Muestreo del ruido con XOF(theta): orden r2, e, r1")
    xof_th = t_xof_init(hqc, "theta", theta)
    r2 = t_sample_mod(hqc, xof_th, hqc.w_r, "r2")
    e = t_sample_mod(hqc, xof_th, hqc.w_e, "e")
    r1 = t_sample_mod(hqc, xof_th, hqc.w_r, "r1")
    p(f"\n  bytes totales consumidos de XOF(theta): {xof_th.consumed}")

    hdr3("u = r2*h + r1")
    r2h = t_vect_mul(hqc, r2, h, "r2", "h", "r2*h")
    u = r2h ^ r1
    u_b = u.to_bytes(hqc.n_sz, 'little')
    show_b("u = r2*h XOR r1", u_b, f"vector de {hqc.n} bits en {hqc.n_sz} B little-endian")

    hdr3("Codificacion del mensaje: RS y luego RM")
    rs_cw = t_rs_encode(hqc, m)
    cm = t_rm_encode(hqc, rs_cw)

    hdr3("v = cm + r2*s + e  (truncado a n1*n2 bits)")
    r2s = t_vect_mul(hqc, r2, s, "r2", "s", "r2*s")
    v = cm ^ r2s ^ e
    v &= (1 << hqc.n1n2) - 1
    v_b = v.to_bytes(hqc.n1n2_sz, 'little')
    show_b("v = (cm XOR r2*s XOR e) mod 2^(n1n2)", v_b, f"{hqc.n1n2} bits en {hqc.n1n2_sz} B little-endian")

    c_pke = u_b + v_b
    show_b("c_pke (salida) = u || v", c_pke, f"[u {hqc.n_sz}B][v {hqc.n1n2_sz}B]")
    if cm_out is not None:
        cm_out['cm'] = cm
    return c_pke


def t_kem_keygen(hqc, prng):
    hdr1("ETAPA 1: KEM.KEYGEN")
    p("  Entrada: PRNG de test (SHAKE256 inicializado con seed || 0x00). Salida: pk, sk")

    hdr2("1.1 Semilla KEM")
    seed_kem = prng.read(hqc.seed_sz)
    show_b("seed_kem (salida de prng.read(32))", seed_kem, "32 B")

    hdr2("1.2 Expansion de seed_kem con XOF -> seed_pke, sigma")
    ctx = t_xof_init(hqc, "kem", seed_kem)
    seed_pke = ctx.read(hqc.seed_sz)
    sigma = ctx.read(hqc.sec_sz)
    p("  Lecturas directas al XOF (sin relleno): primero 32 B, luego 16 B")
    show_b("seed_pke", seed_pke, "32 B")
    show_b("sigma", sigma, f"{hqc.sec_sz} B, secreto para rechazo implicito")

    hdr2("1.3 PKE.KEYGEN(seed_pke)")
    p("  1.3.1 Derivacion de semillas: SHA3-512(seed_pke || 0x02)")
    i_res = t_hash("SHA3-512", SHA3_512, [seed_pke, b'\x02'], ["seed_pke", "0x02"], "64 B = [seed_dk 32B][seed_ek 32B]")
    seed_dk = i_res[0:32]
    seed_ek = i_res[32:64]
    show_b("seed_pke_dk = i_res[0:32]", seed_dk, "32 B")
    show_b("seed_pke_ek = i_res[32:64]", seed_ek, "32 B")

    hdr3("1.3.2 Muestreo de la clave secreta (y, x) con XOF(seed_dk), orden: y luego x")
    xof_dk = t_xof_init(hqc, "dk", seed_dk)
    y = t_sample_rej(hqc, xof_dk, hqc.w, "y")
    x = t_sample_rej(hqc, xof_dk, hqc.w, "x")
    p(f"\n  bytes totales consumidos de XOF(seed_dk): {xof_dk.consumed}")

    hdr3("1.3.3 Muestreo de h con XOF(seed_ek)")
    xof_ek = t_xof_init(hqc, "ek", seed_ek)
    h = t_sample_vect(hqc, xof_ek, "h")

    hdr3("1.3.4 s = y*h + x")
    yh = t_vect_mul(hqc, y, h, "y", "h", "y*h")
    s = yh ^ x
    s_b = s.to_bytes(hqc.n_sz, 'little')
    show_b("s = y*h XOR x", s_b, f"vector de {hqc.n} bits en {hqc.n_sz} B little-endian")

    hdr3("1.3.5 Empaquetado")
    ek_pke = seed_ek + s_b
    dk_pke = seed_dk
    show_b("ek_pke = seed_ek || s", ek_pke, f"[seed_ek 32B][s {hqc.n_sz}B]")
    show_b("dk_pke = seed_dk", dk_pke, "32 B")

    hdr2("1.4 Claves KEM")
    pk = ek_pke
    sk = pk + dk_pke + sigma + seed_kem
    show_b("pk = ek_pke", pk, f"{hqc.pk_sz} B")
    show_b("sk = pk || dk_pke || sigma || seed_kem", sk,
           f"[pk {hqc.pk_sz}B @0][dk_pke 32B @{hqc.pk_sz}][sigma {hqc.sec_sz}B @{hqc.pk_sz + 32}]"
           f"[seed_kem 32B @{hqc.pk_sz + 32 + hqc.sec_sz}]")
    return pk, sk


def t_kem_encaps(hqc, prng, pk):
    hdr1("ETAPA 2: KEM.ENCAPS")
    p("  Entradas: PRNG de test (continua tras keygen), pk. Salidas: ss (32B), ct (4433B)")
    show_b("pk (entrada)", pk, f"{hqc.pk_sz} B")

    hdr2("2.1 Aleatoriedad del encapsulado")
    m = prng.read(hqc.k)
    salt = prng.read(hqc.salt_sz)
    show_b("m (prng.read(16))", m, "16 B mensaje")
    show_b("salt (prng.read(16))", salt, "16 B")

    hdr2("2.2 Hash de la clave publica y derivacion (K, theta)")
    tmp_h = t_hash("H = SHA3-256(pk || 0x01)", SHA3_256, [pk, b'\x01'], ["pk", "0x01"], "32 B")
    tmp_g = t_hash("G = SHA3-512(H || m || salt || 0x00)", SHA3_512,
                   [tmp_h, m, salt, b'\x00'], ["H", "m", "salt", "0x00"], "64 B = [K 32B][theta 32B]")
    kk = tmp_g[0:32]
    theta = tmp_g[32:64]
    show_b("K = G[0:32]", kk, "32 B, shared secret")
    show_b("theta = G[32:64]", theta, "32 B")

    hdr2("2.3 PKE.ENCRYPT(pk, m, theta)")
    info = {}
    c_pke = t_pke_encrypt(hqc, pk, m, theta, info)

    hdr2("2.4 Ciphertext KEM")
    ct = c_pke + salt
    show_b("ct = c_pke || salt", ct, f"[u {hqc.n_sz}B][v {hqc.n1n2_sz}B][salt {hqc.salt_sz}B] = {hqc.ct_sz} B")
    show_b("ss = K", kk, "32 B")
    return kk, ct, m, info['cm']


def t_kem_decaps(hqc, sk, ct, cm_orig, reenc_detalle):
    hdr1("ETAPA 3: KEM.DECAPS")
    p("  Entradas: sk, ct. Salida: ss' (32B)")
    show_b("sk (entrada)", sk, f"{hqc.sk_sz} B")
    show_b("ct (entrada)", ct, f"{hqc.ct_sz} B")

    hdr2("3.1 Desempaquetado de sk y ct")
    ek = sk[0:hqc.pk_sz]
    dk_pke = sk[hqc.pk_sz:hqc.pk_sz + hqc.seed_sz]
    sigma = sk[hqc.pk_sz + hqc.seed_sz:hqc.pk_sz + hqc.seed_sz + hqc.sec_sz]
    p(f"  sk: pk @[0:{hqc.pk_sz}], dk_pke @[{hqc.pk_sz}:{hqc.pk_sz + 32}], sigma @[{hqc.pk_sz + 32}:{hqc.pk_sz + 32 + hqc.sec_sz}], "
      f"seed_kem @[{hqc.pk_sz + 32 + hqc.sec_sz}:{hqc.sk_sz}] (no usado)")
    show_b("pk (de sk)", ek, f"{hqc.pk_sz} B")
    show_b("dk_pke", dk_pke, "32 B")
    show_b("sigma", sigma, f"{hqc.sec_sz} B")
    c_pke = ct[0:hqc.n_sz + hqc.n1n2_sz]
    salt = ct[hqc.n_sz + hqc.n1n2_sz:hqc.ct_sz]
    p(f"  ct: u @[0:{hqc.n_sz}], v @[{hqc.n_sz}:{hqc.n_sz + hqc.n1n2_sz}], salt @[{hqc.n_sz + hqc.n1n2_sz}:{hqc.ct_sz}]")
    show_b("c_pke = u || v", c_pke, f"{hqc.n_sz + hqc.n1n2_sz} B")
    show_b("salt", salt, "16 B")

    hdr2("3.2 PKE.DECRYPT(dk_pke, c_pke)")
    seed_dk = dk_pke[0:hqc.seed_sz]
    hdr3("3.2.1 Regeneracion de y con XOF(seed_dk) (solo se necesita y, el primero)")
    xof_dk = t_xof_init(hqc, "dk", seed_dk)
    y = t_sample_rej(hqc, xof_dk, hqc.w, "y")

    hdr3("3.2.2 Parseo de u y v")
    u = int.from_bytes(c_pke[0:hqc.n_sz], byteorder='little')
    v = int.from_bytes(c_pke[hqc.n_sz:hqc.n_sz + hqc.n1n2_sz], byteorder='little')
    show_v("u", u, hqc.n, "vector denso", False)
    show_v("v", v, hqc.n1n2, "vector denso", False)

    hdr3("3.2.3 cm' = v + y*u")
    yu = t_vect_mul(hqc, y, u, "y", "u", "y*u")
    cm = v ^ yu
    show_v("cm' = v XOR y*u (solo se usan los primeros n1*n2 bits)", cm, hqc.n1n2, "palabra RM ruidosa", False)
    ruido = (cm ^ cm_orig) & ((1 << hqc.n1n2) - 1)
    p(f"  [informativo, solo en traza] peso Hamming del error real cm' XOR cm = {bin(ruido).count('1')} bits de {hqc.n1n2}")

    hdr3("3.2.4 Decodificacion RM")
    rm_out = t_rm_decode(hqc, cm)
    hdr3("3.2.5 Decodificacion RS")
    m_p = t_rs_decode(hqc, rm_out)
    show_b("m' (salida de PKE.DECRYPT)", m_p, f"{hqc.k} B")

    hdr2("3.3 Re-derivacion de (K', theta')")
    tmp_h = t_hash("H = SHA3-256(pk || 0x01)", SHA3_256, [ek, b'\x01'], ["pk", "0x01"], "32 B")
    tmp_g = t_hash("G = SHA3-512(H || m' || salt || 0x00)", SHA3_512,
                   [tmp_h, bytes(m_p), salt, b'\x00'], ["H", "m'", "salt", "0x00"], "64 B = [K' 32B][theta' 32B]")
    kk_p = tmp_g[0:32]
    theta_p = tmp_g[32:64]
    show_b("K' = G[0:32]", kk_p, "32 B")
    show_b("theta' = G[32:64]", theta_p, "32 B")

    hdr2("3.4 Re-cifrado PKE.ENCRYPT(pk, m', theta')")
    if not reenc_detalle:
        p("  (detalle intermedio omitido por --reenc-resumido; solo entradas y salida)")
        Salida.mute = True
    c_pke_p = t_pke_encrypt(hqc, ek, bytes(m_p), theta_p)
    Salida.mute = False
    if not reenc_detalle:
        show_b("c_pke' (salida)", c_pke_p, f"{len(c_pke_p)} B")
    c_kem_p = c_pke_p + salt

    hdr2("3.5 Comparacion y clave de rechazo implicito")
    k_rej = t_hash("K_rej = SHA3-256(H || sigma || ct || 0x03)", SHA3_256,
                   [tmp_h, sigma, ct, b'\x03'], ["H", "sigma", "ct", "0x03"], "32 B")
    iguales = (c_kem_p == ct)
    p(f"  ct' == ct ? {iguales}")
    if not iguales:
        dif = sum(1 for a, b in zip(c_kem_p, ct) if a != b)
        p(f"  bytes distintos: {dif}")
    ss_p = kk_p if iguales else k_rej
    p("  seleccion: " + ("K' (ct valido)" if iguales else "K_rej (RECHAZO IMPLICITO)"))
    show_b("ss' (salida)", ss_p, "32 B")
    return ss_p


def run_trace(hqc, seed, idx=None, reenc_detalle=True):
    titulo = f"Count = {idx}" if idx is not None else "Semilla especifica"
    hdr1(f"HQC-128 | {titulo}")
    show_b("seed de entrada", seed, "48 B")
    p("  PRNG de test: SHAKE256( seed || 0x00 ), se lee como flujo (prng.read(n))")
    prng = prng_init(seed)

    pk, sk = t_kem_keygen(hqc, prng)
    ss, ct, m, cm_orig = t_kem_encaps(hqc, prng, pk)
    ss_d = t_kem_decaps(hqc, sk, ct, cm_orig, reenc_detalle)

    hdr1("VERIFICACION")
    prng2 = prng_init(seed)
    pk2, sk2 = hqc.keygen(prng2)
    ss2, ct2 = hqc.kem_encaps(prng2, pk2)
    ss_d2 = hqc.kem_decaps(sk2, ct2)
    checks = [
        ("pk  traza == referencia", pk == pk2),
        ("sk  traza == referencia", sk == sk2),
        ("ct  traza == referencia", ct == ct2),
        ("ss  traza == referencia", ss == ss2),
        ("ss' traza == referencia", ss_d == ss_d2),
        ("ss == ss' (decapsulacion correcta)", ss == ss_d),
    ]
    ok = True
    for n, r in checks:
        p(f"  [{'OK' if r else 'FALLO'}] {n}")
        ok &= r

    hdr2("RESUMEN EN FORMATO KAT")
    if idx is not None:
        p(f"count = {idx}")
    p(f"seed = {seed.hex().upper()}")
    p(f"pk = {pk.hex().upper()}")
    p(f"sk = {sk.hex().upper()}")
    p(f"ct = {ct.hex().upper()}")
    p(f"ss = {ss.hex().upper()}")
    p(f"ss' = {ss_d.hex().upper()}")
    return ok


# ---------------------------------------------------------------------
#  Modos de operacion
# ---------------------------------------------------------------------
def modo_kat(n, solo, reenc_detalle):
    """Genera n semillas de 48 B con el PRNG de la Entropy Input (seed = 00 01 ... 2F)."""
    hqc = HQC128()
    t_params(hqc)
    test_seed = bytes(range(48))
    hdr1("MODO KAT: generacion de semillas con la Entropy Input")
    show_b("Entropy Input", test_seed, "48 B = 00 01 02 ... 2F")
    p("  prng0 = SHAKE256(entropy_input || 0x00); seed_i = prng0.read(48) para i = 0..n-1")
    prng0 = prng_init(test_seed)
    ok = True
    for i in range(n):
        seed_i = prng0.read(48)
        if solo is not None and i != solo:
            continue
        ok &= run_trace(hqc, seed_i, idx=i, reenc_detalle=reenc_detalle)
    hdr1("RESULTADO FINAL MODO KAT")
    p("  TODO OK" if ok else "  HAY FALLOS")
    return ok


def modo_seed(seed, reenc_detalle):
    hqc = HQC128()
    t_params(hqc)
    ok = run_trace(hqc, seed, idx=None, reenc_detalle=reenc_detalle)
    hdr1("RESULTADO FINAL MODO SEMILLA ESPECIFICA")
    p("  TODO OK" if ok else "  HAY FALLOS")
    return ok


def parse_seed(txt):
    t = "".join(txt.split())
    if t.lower().startswith("0x"):
        t = t[2:]
    try:
        b = bytes.fromhex(t)
    except ValueError:
        raise SystemExit("Error: la semilla debe ser hexadecimal.")
    if len(b) != 48:
        raise SystemExit(f"Error: la semilla debe tener 48 bytes (96 caracteres hex); se recibieron {len(b)} bytes.")
    return b


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="HQC-128: traza detallada para referencia de hardware")
    ap.add_argument("--modo", choices=["kat", "seed"], help="kat: semillas derivadas de la Entropy Input; seed: semilla especifica")
    ap.add_argument("--seed", help="semilla de 48 bytes en hex (96 caracteres), para --modo seed")
    ap.add_argument("--n", type=int, default=100, help="cantidad de semillas en modo kat (default 100)")
    ap.add_argument("--solo", type=int, help="en modo kat, trazar unicamente el count indicado")
    ap.add_argument("--out", help="ademas de la pantalla, guardar la traza en este archivo")
    ap.add_argument("--reenc-resumido", action="store_true",
                    help="en decaps, no detallar el re-cifrado (solo entradas/salida)")
    a = ap.parse_args()

    modo = a.modo
    seed_txt = a.seed
    if modo is None:
        print("\nHQC-128 - traza detallada")
        print("1. KAT: semillas generadas con la Entropy Input")
        print("2. Semilla especifica (48 bytes hex)")
        try:
            op = int(input("\nseleccione: "))
        except Exception:
            op = 2
        if op == 1:
            modo = "kat"
            try:
                a.n = int(input("cantidad de semillas [100]: ") or 100)
            except Exception:
                a.n = 100
        else:
            modo = "seed"
            seed_txt = input("seed (96 hex) [Enter = seed de ejemplo]: ").strip() or \
                "9AE72A849E11505B5D5353086B2ECF8F93B487C462548EDD43259CEB668D8BFD6DF6FD1BA766AB51D0DEF03FDAC8D0FC"

    if a.out:
        Salida.fh = open(a.out, "w")
    try:
        if modo == "kat":
            exito = modo_kat(a.n, a.solo, not a.reenc_resumido)
        else:
            if seed_txt is None:
                raise SystemExit("Error: --modo seed requiere --seed")
            exito = modo_seed(parse_seed(seed_txt), not a.reenc_resumido)
    finally:
        if Salida.fh:
            Salida.fh.close()
    sys.exit(0 if exito else 1)

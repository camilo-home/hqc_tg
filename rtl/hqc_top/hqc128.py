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


# === Prueba con test vectors
if __name__ == "__main__":
    
    def prng_init(seed=None):
        """Inicializa PRNG para test"""
        if seed is None:
            seed = bytes(range(48))
        return SHAKE256.new(seed + b'\00')
    
    def run_kat_test():
        """Ejecuta test KAT (Known Answer Test)"""
        print("\n===== Test hqc-128 con vectores oficiales =====\n")
        
        hqc = HQC128()
        
        # Semilla para el test (usada en los test vectors originales)
        test_seed = bytes(range(48))
        print(f"Seed del test: {test_seed.hex()}")
        print(f"Longitud: {len(test_seed)} bytes\n")
        
        prng0 = prng_init(test_seed)
        
        # Ejecutar 10 iteraciones como en los test vectors
        for i in range(10):
            print(f"\nCount = {i}")
            
            # 1. Leer semilla de iteracion
            seed0 = prng0.read(48)
            print(f"seed = {seed0.hex()}\n")
            
            # 2. Inicializar PRNG con esta semilla
            prng = prng_init(seed0)
            
            # 3. Generar claves
            (pk, sk) = hqc.keygen(prng)
            print(f"pk = {pk.hex().upper()}\n")
            print(f"sk = {sk.hex().upper()}\n")
            
            # 4. Encapsular
            (ss, ct) = hqc.kem_encaps(prng, pk)
            print(f"ct = {ct.hex().upper()}\n")
            print(f"ss = {ss.hex().upper()}\n")
            
            # 5. Desencapsular y verificar
            ss2 = hqc.kem_decaps(sk, ct)
            print(f"ss' = {ss2.hex().upper()}\n")
            if ss == ss2:
                print("ss y ss' coinciden")
            else:
                print("ERROR en decapsulacion")
                return False

        return True
    
    def test_con_semilla_especifica():

        print("\n===== Test con seed especifica =====\n")
        
        # seed especifica a testear
        seed_esp = bytes.fromhex("9AE72A849E11505B5D5353086B2ECF8F93B487C462548EDD43259CEB668D8BFD6DF6FD1BA766AB51D0DEF03FDAC8D0FC")
        
        print(f"seed: {seed_esp.hex()}")
        print(f"Longitud: {len(seed_esp)} bytes\n")
        
        hqc = HQC128()
        
        # 1. Generar claves
        print("\nKeygen:\n")
        prng = prng_init(seed_esp)
        ek, dk = hqc.keygen(prng)
        print(f"pk ({len(ek)} bytes) = {ek.hex()}\n")
        print(f"sk ({len(dk)} bytes) = {dk.hex()}\n")

        # 2. Encapsular
        print("\nEncapsulado:\n")
        ss1, ct = hqc.kem_encaps(prng, ek)
        print(f"ct ({len(ct)} bytes) = {ct.hex()}\n")
        print(f"ss ({len(ss1)} bytes) = {ss1.hex()}\n")

        # 3. Desencapsular
        print("\nDesencapsulado:\n")
        ss2 = hqc.kem_decaps(dk, ct)
        print(f"ss' ({len(ss2)} bytes) = {ss2.hex()}\n")

        # 4. Verificar
        print("\nVerificacion:\n")
        if ss1 == ss2:
            print("ss y ss' coinciden")
            return True
        else:
            print("error: ss y ss' NO coinciden")
            return False
    
    # Ejecutar tests
    print("\nhqc-1(128)\n")
    print("1. kats completos")
    print("2. seed especifica")
    
    try:
        opcion = int(input("\nseleccione: "))
    except:
        opcion = 2
    
    if opcion == 1:
        success = run_kat_test()
    else:
        success = test_con_semilla_especifica()

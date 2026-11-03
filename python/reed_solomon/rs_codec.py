class RS_codec:
    def __init__(self):
        self.n1 = 46
        self.k = 16
        self.delta = 15
        
        self.alpha = 0b10
        self.rs = self.rs_genpoly(self.delta * 2)

    # Polynomial generation for Reed-Solomon encoding
    def rs_genpoly(self, t):
            f = bytearray([1])
            a = 1
            for i in range(t):
                a = self.gf_mul(a, self.alpha)
                f.insert(0, 0)
                for j in range(i+1):
                    f[j] ^= self.gf_mul(a, f[j + 1])
            return f

    # Reed-Solomon encoding function
    def rs_encode(self, msg):
        y = bytearray(self.n1 - self.k)
        for i in range(self.k):
            x = msg[self.k - 1 - i] ^ y[-1]
            y = bytearray(1) + y[:-1]
            for j in range(self.n1 - self.k):
                y[j] ^= self.gf_mul(x, self.rs[j])
        return msg + y

    # Reed-Solomon syndrome calculation function
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

    # Reed-Solomon error locator polynomial calculation function
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

    # Reed-Solomon root finding function
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

    # Reed-Solomon decoding function
    def rs_decode(self, cw):
        syn = self.rs_synd(cw)
        sig = self.rs_elp(syn)
        ep = self.rs_roots(sig)
        ne = len(ep)
        if ne == 0:
            return cw[:self.k:]
        
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
        
        m = cw[:self.k:]
        return m


    "========================================================================"
    "Galois Field arithmetic functions for Reed-Solomon encoding and decoding"
    "========================================================================"

    # Galois Field multiplication function
    def gf_mul(self, a, b):
        r = a & (-(b & 1))
        for i in range(1, 8):
            a = (a << 1) ^ ((-(a >> 7)) & 0x11D)
            r ^= a & (-((b >> i) & 1))
        return r

    # Galois Field exponentiation function
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

    # Galois Field inversion function
    def gf_inv(self, x):
        return self.gf_exp(x, 254)

    # Galois Field Gaussian elimination function
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

if __name__ == "__main__":

    rs = RS_codec()

    print(" Reed-Solomon Shortened Codec RS(46,16)\n")

    print("\nField:")
    print("GF(2^8)")

    print("\nPrimitive polynomial:")
    print("Binary : 100011101")
    print("Hex    : 0x11D")
    print("Poly   : x^8 + x^4 + x^3 + x^2 + 1")

    print("\nPrimitive element:")
    print(f"alpha = 0x{rs.alpha:02X}")

    print("\nGenerator polynomial coefficients:")
    for i, c in enumerate(rs.rs):
        print(f"g[{i:2d}] = 0x{c:02X}")

    print("\nEnter a 16-byte message (32 hex characters):")

    while True:
        msg_hex = input("> ").replace(" ", "").strip()

        if len(msg_hex) != rs.k * 2:
            print(f"Message must contain exactly {rs.k} bytes.")
            continue

        try:
            msg = bytearray.fromhex(msg_hex)

            print("\nMessage (ASCII)")

            print(msg.decode("utf-8", errors="replace"))
            break
        except ValueError:
            print("Invalid hexadecimal string.")

    print("\nMessage symbols")

    for i, b in enumerate(msg):
        print(f"m[{i:2d}] = 0x{b:02X} = '{chr(b)}'")

    cw = rs.rs_encode(msg)

    parity = cw[:rs.k]

    print("\nParity symbols")

    for i, b in enumerate(parity):
        print(f"p[{i:2d}] = 0x{b:02X} = '{chr(b)}'")

    print("\nEncoded codeword")

    print(cw.hex().upper())

    print("\nEncoded codeword (unicode)")
    codeword = ''.join([chr(b) for b in cw])
    print(codeword)

    print(f"\nEnter a codeword to decode ({rs.n1} bytes = {rs.n1*2} hex characters)")
    print("You may modify symbols manually to introduce errors.")

    while True:

        cw_hex = input("> ").replace(" ", "").strip()

        if len(cw_hex) != rs.n1 * 2:
            print(f"Codeword must contain exactly {rs.n1} bytes.")
            continue

        try:
            cw_in = bytearray.fromhex(cw_hex)

            print("\nInput codeword (unicode)")
            codeword_in = ''.join([chr(b) for b in cw_in])
            print(codeword_in)

            break
        except ValueError:
            print("Invalid hexadecimal string.")

    decoded = rs.rs_decode(cw_in)

    print("\nDecoded message")

    for i, b in enumerate(decoded):
        print(f"m[{i:2d}] = 0x{b:02X} = '{chr(b)}'")

    print("\nDecoded message (HEX)")
    print(decoded.hex().upper())

    print("\nDecoded message (ASCII)")
    print(decoded.decode("utf-8", errors="replace"))
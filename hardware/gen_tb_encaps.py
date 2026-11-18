#!/usr/bin/env python3
"""Genera tb_hqc_encaps.vhd con vectores de kem_encaps (hqc128.py) en el orden de datos del hardware.
   Uso: python gen_tb_encaps.py [--hqc-dir <carpeta con hqc128.py>] [--out <carpeta>] [--cases N]
   Necesita pycryptodome (lo importa hqc128.py).  Para cambiar el orden de entrega de la salida,
   cambiar ORDER aqui Y OUT_SEQ en hqc_encaps.vhd."""
import argparse, hashlib, os, sys

ORDER = ['ss', 'v', 'u', 'salt']                       # = OUT_SEQ del DUT
CODE  = {'ss': 0, 'v': 1, 'u': 2, 'salt': 3}          # = out_part
LEN   = {'ss': 4, 'v': 276, 'u': 277, 'salt': 2}
M64   = (1 << 64) - 1

def words(b, n): b = b + bytes(8*n - len(b)); return [int.from_bytes(b[8*i:8*i+8], 'little') for i in range(n)]
def wbytes(ws): return b''.join(w.to_bytes(8, 'little') for w in ws)

class Fixed:
    def __init__(s, *p): s.p = list(p)
    def read(s, n): b = s.p.pop(0); assert len(b) == n; return b

def vector(hqc, seed_kem, m, salt):
    """Devuelve (palabras de entrada [285], palabras de salida [559]) y verifica todo contra kem_encaps."""
    ek, _ = hqc.keygen(Fixed(seed_kem))
    kk, ct = hqc.kem_encaps(Fixed(m, salt), ek)
    key = words(ek, 281) + words(m, 2) + words(salt, 2)
    s_w = key[4:281]; s_w[276] &= 0x1F
    msg = key[0:4] + s_w; msg[280] |= 0x100
    assert wbytes(msg)[:2242] == ek + b'\x01'
    tmp_h = hashlib.sha3_256(wbytes(msg)[:2242]).digest()
    g = hashlib.sha3_512(tmp_h + m + salt + b'\x00').digest()
    assert g[:32] == kk
    cw = bytes(hqc.rs_encode(bytearray(m)))
    cm = []
    for i in range(46):
        y = hqc.rm_encode(bytes([cw[i]])); cm += [(y >> (64*t)) & M64 for t in range(6)]
    th = hqc.xof_init(g[32:64]); h = hqc.sample_vect(hqc.xof_init(ek[:32])); s = int.from_bytes(ek[32:2241], 'little')
    r2 = hqc.sample_fixed_wt_mod(th, 75); e = hqc.sample_fixed_wt_mod(th, 75); r1 = hqc.sample_fixed_wt_mod(th, 75)
    u = hqc.vect_mul(r2, h) ^ r1; v = hqc.vect_mul(r2, s) ^ e
    u_w = [(u >> (64*w)) & M64 for w in range(277)]
    v_w = [((v >> (64*w)) & M64) ^ cm[w] for w in range(276)]
    seg = {'ss': words(kk, 4), 'v': v_w, 'u': u_w, 'salt': words(salt, 2)}
    assert wbytes(seg['u'])[:2209] == ct[:2209] and wbytes(seg['v']) == ct[2209:4417] and wbytes(seg['salt']) == ct[4417:]
    out = [w for name in ORDER for w in seg[name]]
    assert len(out) == 559
    return key, out

def fmt(ws, per=4):
    return '(\n      ' + ',\n      '.join(', '.join('x"%016X"' % w for w in ws[i:i+per]) for i in range(0, len(ws), per)) + ')'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--hqc-dir', default='.'); ap.add_argument('--out', default='.'); ap.add_argument('--cases', type=int, default=3)
    a = ap.parse_args()
    sys.path.insert(0, a.hqc_dir)
    from hqc128 import HQC128
    hqc = HQC128()
    keys, exps = [], []
    for c in range(a.cases):
        d = lambda tag, n: hashlib.shake_256(b'encaps-tb-%d-%s' % (c, tag)).digest(n)
        key, out = vector(hqc, d(b'seed', 32), d(b'm', 16), d(b'salt', 16))
        keys.append(key); exps.append(out)
        print('caso %d: ss = %s...' % (c, wbytes(out[:4]).hex()[:16]))
    flags = []
    for name in ORDER:
        flags += [2*CODE[name] + (1 if k == LEN[name]-1 else 0) for k in range(LEN[name])]
    wrap = lambda cases: '(\n    ' + ',\n    '.join(fmt(x) for x in cases) + ')'
    t = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tb_template.vhd')).read()
    t = (t.replace('@NCASES@', str(a.cases)).replace('@KEYS@', wrap(keys)).replace('@EXP@', wrap(exps))
          .replace('@ORDER@', ' | '.join(ORDER))
          .replace('@FLAGS@', '(\n      ' + ',\n      '.join(', '.join(map(str, flags[i:i+20])) for i in range(0, len(flags), 20)) + ')'))
    open(os.path.join(a.out, 'tb_hqc_encaps.vhd'), 'w').write(t)
    print('escrito tb_hqc_encaps.vhd')

if __name__ == '__main__':
    main()

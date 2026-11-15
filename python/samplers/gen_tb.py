# Genera tb_samplefxwtmod.vhd y tb_samplefxwtrej.vhd con vectores del modelo (validado vs hqc128.py)
import hashlib, sys
from hw_model import ref_mod, ref_rej

N, WTM, WTR = 17669, 75, 66
NWORDS = 160

class X:
    def __init__(s, seed, ln=1400): s.d = hashlib.shake_256(seed + b'\x01').digest(ln); s.p = 0
    def read(s, n): r = s.d[s.p:s.p+n]; s.p += n; return r

def words_of(seed):
    d = hashlib.shake_256(seed + b'\x01').digest(8*NWORDS)
    return [int.from_bytes(d[8*k:8*k+8], 'little') for k in range(NWORDS)]

# ---- modelos HW con lista ordenada y marcas de casos especiales
def hw_mod(words, pos, n, wt):
    nw = (wt+1)//2; raw = []
    for i in range(wt):
        w = words[pos + i//2]; u = (w >> 32) if i % 2 else (w & 0xFFFFFFFF)
        raw.append(((u*(n-i)) >> 32) + i)
    bm = set(); fin = list(raw); dup = 0
    for i in range(wt-1, -1, -1):
        p = raw[i]
        if p in bm: p = i; dup += 1
        bm.add(p); fin[i] = p
    return fin, pos + nw, {'dup': dup}

def hw_rej(words, pos, n, wt):
    n_rej = (2**24//n)*n; n32 = 2**32//n; nwb = (3*wt+7)//8
    buf = bytearray(); bw = bc = 0; bm = set(); out = []; f = {'rej':0,'dup':0,'barrett':0,'batch2':0}
    while True:
        while len(buf) < 3:
            buf += words[pos].to_bytes(8, 'little'); pos += 1; bw += 1
        u = int.from_bytes(buf[:3], 'big'); del buf[:3]; bc += 1
        if u < n_rej:
            q = (u*n32) >> 32; r = u - q*n
            if r >= n: f['barrett'] += 1; r -= n
            if r in bm: f['dup'] += 1
            else:
                bm.add(r); out.append(r)
                if len(out) == wt: break
        else: f['rej'] += 1
        if bc == wt: buf = bytearray(); bw = bc = 0; f['batch2'] += 1
    pos += nwb - bw
    return out, pos, f

def case_mod(seed):
    w = words_of(seed); x = X(seed); pos = 0; exp = []; cum = []; feat = 0
    for _ in range(3):
        fin, pos, f = hw_mod(w, pos, N, WTM); feat += f['dup']
        assert set(fin) == ref_mod(x, N, WTM) and len(set(fin)) == WTM and pos*8 == x.p
        exp += fin; cum.append(pos)
    return w, exp, cum, {'dup': feat}

def case_rej(seed):
    w = words_of(seed); x = X(seed); pos = 0; exp = []; cum = []; feat = {'rej':0,'dup':0,'barrett':0,'batch2':0}
    for _ in range(2):
        out, pos, f = hw_rej(w, pos, N, WTR)
        assert set(out) == ref_rej(x, N, WTR) and len(out) == WTR and pos*8 == x.p
        for k in f: feat[k] += f[k]
        exp += out; cum.append(pos)
    return w, exp, cum, feat

def pick(case_fn, wanted, limit=400000):
    """wanted: lista de (nombre, predicado sobre feat). Devuelve [(seed, nombre)]"""
    found = {}; s = 0
    while len(found) < len(wanted) and s < limit:
        seed = s.to_bytes(8, 'little'); _, _, _, f = case_fn(seed)
        for name, pred in wanted:
            if name not in found and pred(f): found[name] = s
        s += 1
    missing = [n for n, _ in wanted if n not in found]
    assert not missing, missing
    return found

TEMPLATE = open('tb_template.vhd').read()

def emit(dut, wt, ncalls, cases, fn, outname, note):
    streams, exps, cums = [], [], []
    for _, seed in cases:
        w, e, c, _ = fn(seed.to_bytes(8, 'little')); streams.append(w); exps.append(e); cums.append(c)
    def wrow(w): return '(\n      ' + ',\n      '.join('x"%016X"' % v for v in w) + ')'
    def irow(l, per=15): return '(\n      ' + ',\n      '.join(', '.join(map(str, l[i:i+per])) for i in range(0, len(l), per)) + ')'
    t = TEMPLATE
    for k, v in {'@DUT@': dut, '@WT@': str(wt), '@NCASES@': str(len(cases)), '@NCALLS@': str(ncalls),
                 '@NWORDS@': str(NWORDS), '@NOTE@': note,
                 '@STREAM@': '(\n    ' + ',\n    '.join(wrow(w) for w in streams) + ')',
                 '@EXPPOS@': '(\n    ' + ',\n    '.join(irow(e) for e in exps) + ')',
                 '@EXPWORDS@': '(\n    ' + ',\n    '.join('(' + ', '.join(map(str, c)) + ')' for c in cums) + ')',
                 '@CASENAMES@': ', '.join('"%s"' % n for n, _ in cases)}.items():
        t = t.replace(k, v)
    open(outname, 'w').write(t)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    m = pick(case_mod, [('plain', lambda f: f['dup'] == 0), ('dup', lambda f: f['dup'] >= 1), ('dup_multi', lambda f: f['dup'] >= 2),
                        ('dup_multi2', lambda f: f['dup'] >= 3)])
    # distintos entre si
    mc = [(n, s) for n, s in m.items()]
    r = pick(case_rej, [('plain', lambda f: sum(f.values()) == 0), ('reject', lambda f: f['rej'] >= 1), ('dup', lambda f: f['dup'] >= 1),
                        ('barrett', lambda f: f['barrett'] >= 1), ('batch2', lambda f: f['batch2'] >= 1),
                        ('mix', lambda f: f['rej'] >= 1 and f['dup'] >= 1 and f['batch2'] >= 1)])
    rc = [(n, s) for n, s in r.items()]
    print('mod seeds', mc); print('rej seeds', rc)
    emit('samplefxwtmod', WTM, 3, mc, case_mod, out + '/tb_samplefxwtmod.vhd', 'sample_fixed_wt_mod: 3 llamadas seguidas (r2, e, r1) sobre el mismo flujo')
    emit('samplefxwtrej', WTR, 2, rc, case_rej, out + '/tb_samplefxwtrej.vhd', 'sample_fixed_wt_rej: 2 llamadas seguidas (y, x) sobre el mismo flujo')

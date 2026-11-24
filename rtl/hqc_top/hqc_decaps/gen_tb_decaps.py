#!/usr/bin/env python3
"""Genera tb_hqc_decaps.vhd con vectores del KAT oficial (PQCkemKAT_*.rsp) y variantes con ct corrupto.
   Uso: python gen_tb_decaps.py --rsp PQCkemKAT_2321.rsp [--hqc-dir <carpeta de hqc128.py>] [--out <carpeta>]
   Los esperados salen de kem_decaps de hqc128.py; para los Count validos se exige que ss coincida con el .rsp
   (si no, aborta). Los ct corruptos (un bit cambiado en u, en v o en salt) deben dar ss = k_rej."""
import argparse, hashlib, os, sys

M64 = (1 << 64) - 1
def words(b, n): b = b + bytes(8*n - len(b)); return [int.from_bytes(b[8*i:8*i+8], 'little') for i in range(n)]
def wbytes(ws): return b''.join(w.to_bytes(8, 'little') for w in ws)

def parse_rsp(path):
    recs, cur = [], {}
    for line in open(path):
        line = line.strip()
        if not line or '=' not in line: continue
        k, v = [x.strip() for x in line.split('=', 1)]; k = k.lower()
        if k == 'count':
            if cur: recs.append(cur)
            cur = {}
        cur[k] = v
    if cur: recs.append(cur)
    return recs

def flip(b, pos, mask=0x10):
    b = bytearray(b); b[pos] ^= mask; return bytes(b)

def dk_words(dk):   # = formato de salida del keygen: ek(281) | seed_dk(4) | sigma(2) | seed_kem(4)
    assert len(dk) == 2321
    return words(dk[:2241], 281) + words(dk[2241:2273], 4) + words(dk[2273:2289], 2) + words(dk[2289:2321], 4)

def ct_words(ct):   # u(277, la ultima con 1 byte) | v(276) | salt(2)
    assert len(ct) == 4433
    return words(ct[:2209], 277) + words(ct[2209:4417], 276) + words(ct[4417:4433], 2)

def fmt(ws, per=4):
    return '(\n      ' + ',\n      '.join(', '.join('x"%016X"' % w for w in ws[i:i+per]) for i in range(0, len(ws), per)) + ')'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rsp', required=True); ap.add_argument('--hqc-dir', default='.'); ap.add_argument('--out', default='.')
    a = ap.parse_args()
    sys.path.insert(0, a.hqc_dir)
    from hqc128 import HQC128
    hqc = HQC128(); recs = parse_rsp(a.rsp)
    kat = lambda c: tuple(bytes.fromhex(recs[c][k]) for k in ('sk', 'ct', 'ss'))
    cases = []   # (nombre, dk, ct, ss_esperado, match)
    for c in (0, 1, 2):
        dk, ct, ss = kat(c)
        assert hqc.kem_decaps(dk, ct) == ss, 'Count %d: hqc128.py NO reproduce el ss del KAT' % c
        cases.append(('KAT %d valido' % c, dk, ct, ss, 1))
    for name, c, pos in (('KAT 0 con u corrupto', 0, 5), ('KAT 1 con v corrupto', 1, 2209 + 100), ('KAT 2 con salt corrupto', 2, 4420)):
        dk, ct, _ = kat(c); bad = flip(ct, pos)
        cases.append((name, dk, bad, hqc.kem_decaps(dk, bad), 0))
    dks = [dk_words(x[1]) for x in cases]; cts = [ct_words(x[2]) for x in cases]; exps = [words(x[3], 4) for x in cases]
    for n, _, _, ss, m in cases: print('%-26s ss = %s...  match = %d' % (n, ss.hex()[:16], m))
    wrap = lambda xs, f: '(\n    ' + ',\n    '.join(f(x) for x in xs) + ')'
    t = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tb_template.vhd')).read()
    t = (t.replace('@NCASES@', str(len(cases))).replace('@NAMES@', ' | '.join(x[0] for x in cases))
          .replace('@DKS@', wrap(dks, fmt)).replace('@CTS@', wrap(cts, fmt)).replace('@EXP@', wrap(exps, fmt))
          .replace('@MATCH@', '(' + ', '.join(str(x[4]) for x in cases) + ')'))
    open(os.path.join(a.out, 'tb_hqc_decaps.vhd'), 'w').write(t)
    print('escrito tb_hqc_decaps.vhd')

if __name__ == '__main__':
    main()

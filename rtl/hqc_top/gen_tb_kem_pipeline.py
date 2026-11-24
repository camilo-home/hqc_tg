#!/usr/bin/env python3
"""Genera tb_hqc_kem_pipeline.vhd con vectores del KAT oficial (Count 0..) y un caso con ct corrupto.
   Uso: python gen_tb_kem_pipeline.py --rsp PQCkemKAT_2321.rsp [--hqc-dir <carpeta de hqc128.py>] [--out <carpeta>]
   Aborta si hqc128.py no reproduce pk, sk, ct y ss del .rsp."""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hqc_kem_jtag as H

def hexw(b, nbytes):        # bytes -> constante de bits de VHDL, palabra 0 en los bits bajos
    return 'x"%s"' % format(int.from_bytes(b, 'little'), '0%dX' % (2 * nbytes))

def fmt_words(ws, per=4):
    return '(\n      ' + ',\n      '.join(', '.join('x"%016X"' % w for w in ws[i:i+per]) for i in range(0, len(ws), per)) + ')'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rsp', required=True); ap.add_argument('--hqc-dir', default='.'); ap.add_argument('--out', default='.')
    a = ap.parse_args()
    hqc = H.load_reference(a.hqc_dir); recs = H.parse_rsp(a.rsp)
    inputs = H.kat_inputs(3)
    # (nombre, indice KAT, corrupcion)
    spec = [('KAT 0 valido', 0, None), ('KAT 1 valido', 1, None), ('KAT 2 con 1 bit del ct corrupto (u, palabra 5, bit 3)', 2, (5, 3))]
    rows = []
    for name, c, corrupt in spec:
        s, m, salt = inputs[c]
        ref = H.reference(hqc, s, m, salt, corrupt)
        for k_name, got in (('pk', ref['ek']), ('sk', ref['dk']), ('ct', ref['ct']), ('ss', ref['kk'])):
            assert got == bytes.fromhex(recs[c][k_name]), 'Count %d: hqc128.py NO reproduce %s del .rsp' % (c, k_name)
        if corrupt is None:
            assert ref['k_expected'] == ref['kk']
        rows.append((name, s, m, salt, corrupt, ref))
        print('%-58s K = %s...  match = %d' % (name, ref['k_expected'].hex()[:16], 1 if ref['valid'] else 0))
    tup = lambda xs: '(\n    ' + ',\n    '.join(xs) + ')'
    ints = lambda xs: '(' + ', '.join(str(x) for x in xs) + ')'
    t = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tb_template.vhd')).read()
    rep = {
        '@NCASES@': str(len(rows)), '@NAMES@': ' | '.join(r[0] for r in rows),
        '@SEEDS@': tup(hexw(r[1], 32) for r in rows), '@MS@': tup(hexw(r[2], 16) for r in rows), '@SALTS@': tup(hexw(r[3], 16) for r in rows),
        '@CEN@': ints(0 if r[4] is None else 1 for r in rows), '@CWORD@': ints(0 if r[4] is None else r[4][0] for r in rows),
        '@CBIT@': ints(0 if r[4] is None else r[4][1] for r in rows),
        '@EXPK@': tup(hexw(r[5]['k_expected'], 32) for r in rows), '@EXPSS@': tup(hexw(r[5]['kk'], 32) for r in rows),
        '@EXPMATCH@': ints(1 if r[5]['valid'] else 0 for r in rows),
        '@DKS@': tup(fmt_words(r[5]['dk_words']) for r in rows), '@CTS@': tup(fmt_words(r[5]['ct_words']) for r in rows)}
    for k, v in rep.items():
        t = t.replace(k, v)
    open(os.path.join(a.out, 'tb_hqc_kem_pipeline.vhd'), 'w').write(t)
    print('escrito tb_hqc_kem_pipeline.vhd')

if __name__ == '__main__':
    main()

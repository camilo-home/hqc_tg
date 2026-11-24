#!/usr/bin/env python3
"""
hqc_kem_jtag.py - Inyecta (seed_kem, m, salt) en hqc_kem_top (FPGA) por USB-Blaster, lanza keygen -> encaps -> decaps,
lee K (el ss de decaps) y lo compara con la referencia hqc128.py.

Ejemplos:
  python hqc_kem_jtag.py id                                   # comprueba el enlace
  python hqc_kem_jtag.py run --kat 5 --rsp PQCkemKAT_2321.rsp  # Count 0..4 del KAT: K debe ser el ss del .rsp
  python hqc_kem_jtag.py run --kat 1 --read-mem                # ademas lee dk y ct y los compara con la referencia
  python hqc_kem_jtag.py run --kat 1 --corrupt 5:3             # cambia el bit 3 de la palabra 5 del ct: K debe ser k_rej
  python hqc_kem_jtag.py run --random 10
  python hqc_kem_jtag.py run --seed <64hex> --m <32hex> --salt <32hex>

Formatos (palabras de 64 bits con el byte 0 en los bits [7:0]):
  dk (291 palabras) = ek (281, relleno 0) | seed_dk (4) | sigma (2) | seed_kem (4)
  ct (555 palabras) = u (277, la ultima con 1 byte) | v (276) | salt (2)
"""
import argparse, os, secrets, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
M64 = (1 << 64) - 1
DK_WORDS, CT_WORDS = 291, 555


# ------------------------------------------------------------------ utilidades de formato
def words(b, n):
    b = b + bytes(8 * n - len(b))
    return [int.from_bytes(b[8 * i:8 * i + 8], 'little') for i in range(n)]

def wbytes(ws):
    return b''.join(w.to_bytes(8, 'little') for w in ws)

def dk_words(dk):
    return words(dk[:2241], 281) + words(dk[2241:2273], 4) + words(dk[2273:2289], 2) + words(dk[2289:2321], 4)

def ct_words(ct):
    return words(ct[:2209], 277) + words(ct[2209:4417], 276) + words(ct[4417:4433], 2)

def ct_from_words(ws):
    return wbytes(ws[:277])[:2209] + wbytes(ws[277:553]) + wbytes(ws[553:555])


# ------------------------------------------------------------------ referencia
class Fixed:
    def __init__(self, *parts):
        self.parts = list(parts)
    def read(self, n):
        b = self.parts.pop(0)
        assert len(b) == n
        return b

def load_reference(hqc_dir):
    sys.path.insert(0, hqc_dir)
    from hqc128 import HQC128                 # requiere pycryptodome
    return HQC128()

def kat_inputs(count):
    """(seed_kem, m, salt) de los Count 0..count-1: misma cadena de PRNG que run_kat_test de hqc128.py"""
    from Crypto.Hash import SHAKE256
    prng0 = SHAKE256.new(bytes(range(48)) + b'\x00')
    out = []
    for _ in range(count):
        prng = SHAKE256.new(prng0.read(48) + b'\x00')
        out.append((prng.read(32), prng.read(16), prng.read(16)))
    return out

def parse_rsp(path):
    recs, cur = [], {}
    for line in open(path):
        line = line.strip()
        if not line or '=' not in line:
            continue
        k, v = [x.strip() for x in line.split('=', 1)]
        k = k.lower()
        if k == 'count':
            if cur:
                recs.append(cur)
            cur = {}
        cur[k] = v
    if cur:
        recs.append(cur)
    return recs

def reference(hqc, seed_kem, m, salt, corrupt):
    """Devuelve dict con ek/dk/ct esperados, ss de encaps y K esperada de decaps (con la corrupcion pedida)."""
    ek, dk = hqc.keygen(Fixed(seed_kem))
    kk, ct = hqc.kem_encaps(Fixed(m, salt), ek)
    cw = ct_words(ct)
    ct_used = ct
    if corrupt is not None:
        w, b = corrupt
        assert 0 <= w < CT_WORDS and 0 <= b < 64
        bad = list(cw)
        bad[w] ^= (1 << b)
        ct_used = ct_from_words(bad)          # los bits de relleno de u (palabra 276) no forman parte del ct
    k_dec = hqc.kem_decaps(dk, ct_used)
    return {'ek': ek, 'dk': dk, 'ct': ct, 'kk': kk, 'k_expected': k_dec, 'valid': ct_used == ct,
            'dk_words': dk_words(dk), 'ct_words': cw}


# ------------------------------------------------------------------ empaquetado hacia/desde la FPGA
def input_hex(seed_kem, m, salt):
    v = int.from_bytes(seed_kem, 'little') | (int.from_bytes(m, 'little') << 256) | (int.from_bytes(salt, 'little') << 384)
    return format(v, '0128x')

def corrupt_hex(corrupt):
    if corrupt is None:
        return '00000'
    w, b = corrupt
    return format((1 << 16) | (w << 6) | b, '05x')

def decode_status(st):
    return {'done': st & 1, 'ack': (st >> 1) & 1, 'ready': (st >> 2) & 1, 'match': (st >> 3) & 1,
            'k_equal': (st >> 4) & 1, 'error': (st >> 5) & 1, 'mem_ack': (st >> 6) & 1,
            'decaps_err': (st >> 7) & 1, 'state_code': (st >> 8) & 0xFF}

def decode_result(h):
    v = int(h, 16)
    take = lambda lo, n: (v >> lo) & ((1 << n) - 1)
    return {'K': take(0, 256).to_bytes(32, 'little'), 'ss_encaps': take(256, 256).to_bytes(32, 'little'),
            'cycles_keygen': take(512, 32), 'cycles_encaps': take(544, 32),
            'cycles_decaps': take(576, 32), 'cycles_total': take(608, 32)}


# ------------------------------------------------------------------ JTAG (quartus_stp)
def find_quartus_stp(path):
    if path:
        return path
    exe = shutil.which('quartus_stp')
    if exe:
        return exe
    root = os.environ.get('QUARTUS_ROOTDIR')
    if root:
        for sub in ('bin64', 'bin'):
            for name in ('quartus_stp', 'quartus_stp.exe'):
                c = os.path.join(root, sub, name)
                if os.path.exists(c):
                    return c
    sys.exit('no encuentro quartus_stp: agrega <quartus>/bin64 al PATH o usa --quartus')

def run_stp(args, extra):
    env = dict(os.environ)
    env['HQC_CABLE'] = str(args.cable)
    env['HQC_DEVICE'] = str(args.device)
    cmd = [find_quartus_stp(args.quartus), '-t', os.path.join(HERE, 'hqc_kem_jtag.tcl')] + extra
    r = subprocess.run(cmd, env=env, text=True, capture_output=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        sys.exit('quartus_stp fallo (codigo %d)' % r.returncode)

def parse_out(path):
    """Lista de dicts por trabajo: {'timeout': True, 'status': ..} o {'status', 'result', 'dk': [..]|None, 'ct': [..]|None}"""
    jobs = []
    for line in open(path):
        tok = line.split()
        if not tok:
            continue
        if tok[0] == 'T':
            jobs.append({'timeout': True, 'status': decode_status(int(tok[1], 16))})
        elif tok[0] == 'R':
            jobs.append({'timeout': False, 'status': decode_status(int(tok[1], 16)), 'result': decode_result(tok[2]),
                         'dk': None, 'ct': None})
        elif tok[0] == 'M0':
            jobs[-1]['dk'] = [int(w, 16) for w in tok[1:]]
        elif tok[0] == 'M1':
            jobs[-1]['ct'] = [int(w, 16) for w in tok[1:]]
    return jobs


# ------------------------------------------------------------------ comparacion
def check(args, hqc, cases, jobs):
    ok_all = True
    for i, (case, job) in enumerate(zip(cases, jobs)):
        seed_kem, m, salt, corrupt, rsp_ss = case
        ref = reference(hqc, seed_kem, m, salt, corrupt)
        tag = 'caso %d (seed %s...%s)' % (i, seed_kem.hex()[:12], '' if corrupt is None else ' corrupt %d:%d' % corrupt)
        if job['timeout']:
            st = job['status']
            print('%s: TIMEOUT (estado %02x: DONE=%d ACK=%d READY=%d)' % (tag, st['state_code'], st['done'], st['ack'], st['ready']))
            ok_all = False
            continue
        r, st = job['result'], job['status']
        errs = []
        if r['K'] != ref['k_expected']:
            errs.append('K = %s, esperada %s' % (r['K'].hex(), ref['k_expected'].hex()))
        if r['ss_encaps'] != ref['kk']:
            errs.append('ss de encaps = %s, esperado %s' % (r['ss_encaps'].hex(), ref['kk'].hex()))
        if rsp_ss is not None and corrupt is None and r['K'] != rsp_ss:
            errs.append('K no coincide con el ss del .rsp (%s)' % rsp_ss.hex())
        if st['match'] != (1 if ref['valid'] else 0):
            errs.append('match = %d, esperado %d' % (st['match'], 1 if ref['valid'] else 0))
        if st['k_equal'] != (1 if r['K'] == ref['kk'] else 0):
            errs.append('k_equal = %d inconsistente' % st['k_equal'])
        if st['error']:
            errs.append('bandera ERROR activa (encaps o conteo de palabras)')
        if job['dk'] is not None:
            if job['dk'] != ref['dk_words']:
                bad = next((k for k in range(DK_WORDS) if k >= len(job['dk']) or job['dk'][k] != ref['dk_words'][k]), None)
                errs.append('dk_ram distinta (primera palabra distinta: %s)' % bad)
            if job['ct'] != ref['ct_words']:
                bad = next((k for k in range(CT_WORDS) if k >= len(job['ct']) or job['ct'][k] != ref['ct_words'][k]), None)
                errs.append('ct_ram distinta (primera palabra distinta: %s)' % bad)
        total = r['cycles_total']
        t = (' = %.3f ms a %g MHz' % (total / (args.clk_mhz * 1e3), args.clk_mhz)) if args.clk_mhz else ''
        info = 'ciclos: keygen %d, encaps %d, decaps %d, total %d%s' % (r['cycles_keygen'], r['cycles_encaps'], r['cycles_decaps'], total, t)
        if errs:
            ok_all = False
            print('%s: FALLO   [%s]' % (tag, info))
            for e in errs:
                print('   - ' + e)
        else:
            kind = 'ct valido: K = ss' if ref['valid'] else 'ct corrupto: K = k_rej (rechazo implicito)'
            mem = ', dk y ct leidos coinciden' if job['dk'] is not None else ''
            print('%s: OK  %s%s\n      K = %s\n      %s' % (tag, kind, mem, r['K'].hex(), info))
    print('\nRESULTADO: %s' % ('TODO OK' if ok_all else 'HAY DIFERENCIAS'))
    return ok_all


def collect_cases(args):
    cases = []
    corrupt = None
    if args.corrupt:
        w, b = args.corrupt.split(':')
        corrupt = (int(w), int(b))
    rsp = parse_rsp(args.rsp) if args.rsp else None
    if args.kat:
        for c, (s, m, salt) in enumerate(kat_inputs(args.kat)):
            cases.append((s, m, salt, corrupt, bytes.fromhex(rsp[c]['ss']) if rsp else None))
    if args.random:
        for _ in range(args.random):
            cases.append((secrets.token_bytes(32), secrets.token_bytes(16), secrets.token_bytes(16), corrupt, None))
    if args.seed:
        cases.append((bytes.fromhex(args.seed), bytes.fromhex(args.m), bytes.fromhex(args.salt), corrupt, None))
    if not cases:
        sys.exit('indica --kat N, --random N o --seed/--m/--salt')
    return cases


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--quartus', help='ruta a quartus_stp')
    ap.add_argument('--cable', type=int, default=0)
    ap.add_argument('--device', type=int, default=0)
    ap.add_argument('--hqc-dir', default=HERE, help='carpeta donde esta hqc128.py')
    ap.add_argument('--clk-mhz', type=float, default=50.0)
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('id')
    r = sub.add_parser('run')
    r.add_argument('--kat', type=int, help='Count 0..N-1 de la cadena de PRNG del KAT')
    r.add_argument('--rsp', help='PQCkemKAT_*.rsp: se exige que la referencia reproduzca pk, ct y ss, y K = ss')
    r.add_argument('--random', type=int)
    r.add_argument('--seed'); r.add_argument('--m'); r.add_argument('--salt')
    r.add_argument('--corrupt', help='PALABRA:BIT del ct (0..554 : 0..63) que se invierte antes de decaps')
    r.add_argument('--read-mem', action='store_true', help='leer dk_ram y ct_ram y compararlas (mas lento)')
    r.add_argument('--timeout', type=int, default=60000, help='ms de espera por DONE (default 60000)')
    args = ap.parse_args()

    if args.cmd == 'id':
        run_stp(args, ['id'])
        return
    hqc = load_reference(args.hqc_dir)
    cases = collect_cases(args)
    if args.rsp and args.kat:                        # la referencia debe reproducir el KAT oficial
        recs = parse_rsp(args.rsp)
        for c, (s, m, salt, _, _) in enumerate(cases[:args.kat]):
            ref = reference(hqc, s, m, salt, None)
            for name, got in (('pk', ref['ek']), ('sk', ref['dk']), ('ct', ref['ct']), ('ss', ref['kk'])):
                if got != bytes.fromhex(recs[c][name]):
                    sys.exit('Count %d: hqc128.py NO reproduce %s del .rsp' % (c, name))
        print('hqc128.py reproduce pk, sk, ct y ss del .rsp (Count 0..%d)' % (args.kat - 1))
    tmp = tempfile.mkdtemp(prefix='hqckem_')
    jobs_file, out_file = os.path.join(tmp, 'jobs.txt'), os.path.join(tmp, 'out.txt')
    with open(jobs_file, 'w') as f:
        for s, m, salt, corrupt, _ in cases:
            f.write('%s %s %d\n' % (input_hex(s, m, salt), corrupt_hex(corrupt), 1 if args.read_mem else 0))
    run_stp(args, ['run', jobs_file, out_file, str(args.timeout)])
    sys.exit(0 if check(args, hqc, cases, parse_out(out_file)) else 1)


if __name__ == '__main__':
    main()

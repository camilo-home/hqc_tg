# Modelo (a nivel de algoritmo/flujo de palabras) de los samplers de hardware nuevos,
# comparado contra el codigo REAL de hqc128.py. Sirve tambien para generar vectores de test.
import sys, types, hashlib, random
# --- stub de Crypto.Hash (pycryptodome no esta instalado); solo se usan las funciones de muestreo ---
m=types.ModuleType("Crypto"); h=types.ModuleType("Crypto.Hash")
class _D:  pass
h.SHAKE256=h.SHA3_256=h.SHA3_512=_D; m.Hash=h
sys.modules["Crypto"]=m; sys.modules["Crypto.Hash"]=h
from hqc128 import HQC128
H=HQC128()
N=H.n; NSZ=H.n_sz; NREJ=H.n_rej; N32=2**32//N

class XOF:                      # lo que lee hqc128.py: read(n), incremental
    def __init__(s,data): s.d=data; s.pos=0
    def read(s,n):
        assert s.pos+n<=len(s.d), "flujo agotado"
        r=s.d[s.pos:s.pos+n]; s.pos+=n; return r
class Words:                    # lo que entrega el sponge: palabras de 8 bytes
    def __init__(s,data): s.d=data; s.n=0
    def next_word(s):
        assert 8*(s.n+1)<=len(s.d), "flujo agotado"
        w=s.d[8*s.n:8*s.n+8]; s.n+=1; return w

def mod_hw(st,wt):
    raw=[]
    for w in range((wt+1)//2):                     # ceil(wt/2) palabras de 64 bits
        word=st.next_word()
        for half in range(2):
            i=2*w+half
            if i>=wt: break                        # mitad alta de la ultima palabra: se ignora
            u32=int.from_bytes(word[4*half:4*half+4],'little')
            raw.append(((u32*(N-i))>>32)+i)
    bm=set(); fin=[0]*wt
    for i in range(wt-1,-1,-1):                    # fase B: descendente
        p=raw[i]
        if p in bm: p=i                            # duplicado de uno posterior -> i
        bm.add(p); fin[i]=p
    return fin

def rej_hw(st,wt):
    CH=(3*wt+7)//8                                 # palabras por chunk (25 para wt=66)
    acc=[]; bm=set(); buf=bytearray(); cand=0; words=0
    while len(acc)<wt:
        if cand==wt: buf=bytearray(); cand=0; words=0        # chunk nuevo: se descartan los bytes de relleno
        if len(buf)<3: buf+=st.next_word(); words+=1
        b=buf[:3]; del buf[:3]; cand+=1
        u24=(b[0]<<16)|(b[1]<<8)|b[2]              # 3 bytes BIG endian
        if u24<NREJ:
            q=(u24*N32)>>32; r=u24-q*N
            if r>=N: r-=N                          # correccion de Barrett
            assert r==u24%N
            if r not in bm: bm.add(r); acc.append(r)
    while words<CH: st.next_word(); words+=1       # drenar el resto del chunk
    return acc

def vect_hw(st):
    mem=[0]*((NSZ+3)//4)
    for k in range((NSZ+7)//8):
        w=st.next_word()
        for hf in range(2):
            a=2*k+hf
            if a<len(mem):
                b4=bytearray(w[4*hf:4*hf+4])
                for t in range(4):
                    bi=4*a+t
                    if bi>=NSZ: b4[t]=0
                    elif bi==NSZ-1 and N%8: b4[t]&=(1<<(N%8))-1
                mem[a]=int.from_bytes(b4,'little')
    return sum(x<<(32*a) for a,x in enumerate(mem))

def vec(lst):
    v=0
    for p in lst: v|=1<<p
    return v

def stream(seed,nbytes=6000): return hashlib.shake_256(seed+b'\x01').digest(nbytes)

if __name__=="__main__":
    rnd=random.Random(7); bad=0; multi=0
    for t in range(1500):
        d=stream(rnd.randbytes(32))
        # keygen: y luego x desde el mismo flujo (rej, wt=66)
        ref=XOF(d); hw=Words(d)
        for _ in range(2):
            vr=H.sample_fixed_wt_rej(ref,H.w); l=rej_hw(hw,H.w)
            if vec(l)!=vr or len(l)!=H.w or 8*hw.n!=ref.pos: bad+=1; print("rej FALLA",t)
        if hw.n>2*25: multi+=1
        # encrypt: r2, e, r1 desde el mismo flujo (mod, wt=75)
        d=stream(rnd.randbytes(32)); ref=XOF(d); hw=Words(d)
        for wt in (H.w_r,H.w_e,H.w_r):
            vr=H.sample_fixed_wt_mod(ref,wt); l=mod_hw(hw,wt)
            if vec(l)!=vr or len(set(l))!=wt or 8*hw.n!=ref.pos: bad+=1; print("mod FALLA",t)
        # vect
        ref=XOF(d); hw=Words(d)
        if vect_hw(hw)!=H.sample_vect(ref) or 8*hw.n!=ref.pos: bad+=1; print("vect FALLA",t)
    print("aleatorios: fallos =",bad," | llamadas rej que necesitaron >1 chunk (x o y):",multi,"/1500")
    # mod con muchos duplicados forzados
    bad2=0; dups=0
    for t in range(1500):
        wt=75
        tg=[i+rnd.randint(0,12) for i in range(wt)]           # posiciones objetivo muy juntas -> colisiones
        u32=[-(-(tg[i]-i)*2**32//(N-i)) for i in range(wt)]
        for i in range(wt): assert ((u32[i]*(N-i))>>32)+i==tg[i]
        if len(set(tg))<wt: dups+=1
        data=b''.join(x.to_bytes(4,'little') for x in u32)+bytes((-len(u32)*4)%8)+bytes(64)
        ref=XOF(data); hw=Words(data)
        vr=H.sample_fixed_wt_mod(ref,wt); l=mod_hw(hw,wt)
        if vec(l)!=vr or len(set(l))!=wt or 8*hw.n!=ref.pos: bad2+=1
    print("mod con duplicados forzados: fallos =",bad2," (casos con duplicados:",dups,"/1500)")

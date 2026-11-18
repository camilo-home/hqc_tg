# Modelo ciclo a ciclo de poly_mul2 v2 (sin barrido de limpieza: el acumulador se inicializa
# en la PRIMERA pasada). Mismos estados, contadores y latencias de memoria que el VHDL.
import random
from model_samplers import H, N, vec
M64=(1<<64)-1
shl=lambda x,n:(x<<n)&M64 if n<64 else 0
shr=lambda x,n:x>>n if n<64 else 0
def words_of(v,W=277): return [(v>>(64*k))&M64 for k in range(W)]
def vec_of(ws): return sum(w<<(64*k) for k,w in enumerate(ws))

class PolyMul2:
    def __init__(s,N=17669,dual=True):
        s.N=N; s.W=(N+63)//64; s.ACCW=2*s.W; s.SH=N%64; s.FW=N//64
        assert s.SH
        s.PASS=s.W+4; s.NCH=2 if dual else 1; s.MASK=(1<<s.SH)-1; s.ZN=s.ACCW-(s.W+1)
    def run(s,pos,dens,acc,n_pos=None):
        """acc: lista de memorias de acumulador (una por canal) con CONTENIDO ARBITRARIO; se modifica."""
        W=s.W; NCH=s.NCH; FW=s.FW; SH=s.SH; PASS=s.PASS; ZN=s.ZN
        n_pos=len(pos) if n_pos is None else n_pos
        pos_mem=list(pos)+[0]*(128-len(pos))
        R=dict(state='IDLE',pidx=0,npos=0,m=0,ft=0,off=0,bsh=0,off_n=0,bsh_n=0,pa=0,fp=0,za=0,zc=0,
               v1=0,first1=0,last1=0,fp1=0,a1=0,v2=0,fp2=0,a2=0,v3=0,a3=0,
               prev=[0]*NCH,f1=[0]*NCH,accn=[0]*NCH,prevb=[0]*NCH,rv=0,rj=0,rr=[0]*NCH)
        pos_d=0; dense_d=[0]*NCH; d1=[0]*NCH; d2=[0]*NCH
        res=[[None]*W for _ in range(NCH)]; cyc=0; sc=None
        while True:
            st=R['state']
            dense_addr=R['m'] if R['m']<W else W-1
            we1=we2=0; a_1=a_2=0; din2=[0]*NCH
            if st=='ACC':
                zv=int(R['fp'] and R['zc']<ZN)
                a_1=R['za'] if zv else R['a1']; we1=zv                # din1 = 0 ; si no escribe, direccion de lectura valida (a1)
                a_2=R['a3']; we2=R['v3']; din2=list(R['accn'])
            elif st=='FOLD':
                ft=R['ft']
                if 1<=ft<=W: a_1=ft-1
                if ft<=W: a_2=FW+ft
            if R['rv']:
                for c in range(NCH):
                    assert res[c][R['rj']] is None; res[c][R['rj']]=R['rr'][c]
            if st=='DONE': return res,dict(latency=cyc-sc)
            N_=dict(R)
            for k in ('prev','f1','accn','prevb','rr'): N_[k]=list(R[k])
            if st=='IDLE':
                N_['rv']=0
                if sc is None:
                    sc=cyc; N_.update(npos=n_pos,pidx=0,pa=0,v1=0,v2=0,v3=0,state='LP0')
            elif st=='LP0': N_['state']='LP1'
            elif st=='LP1':
                N_.update(off=pos_d>>6,bsh=pos_d&63,m=0,pa=1,fp=1,zc=0,za=0 if (pos_d>>6)!=0 else W+1,state='ACC')
            elif st=='ACC':
                m=R['m']
                if m<=W: N_['v1']=1; N_['a1']=R['off']+m
                else: N_['v1']=0
                N_['first1']=int(m==0); N_['last1']=int(m==W); N_['fp1']=R['fp']
                if R['v1']:
                    for c in range(NCH):
                        cur=0 if R['last1'] else dense_d[c]
                        prv=0 if R['first1'] else R['prev'][c]
                        N_['f1'][c]=shl(cur,R['bsh'])|shr(prv,64-R['bsh']); N_['prev'][c]=cur
                N_['v2']=R['v1']; N_['a2']=R['a1']; N_['fp2']=R['fp1']
                for c in range(NCH): N_['accn'][c]=(0 if R['fp2'] else d1[c])^R['f1'][c]
                N_['v3']=R['v2']; N_['a3']=R['a2']
                if R['fp'] and R['zc']<ZN:
                    N_['zc']=R['zc']+1
                    N_['za']=R['off']+W+1 if R['za']+1==R['off'] else R['za']+1
                if m==1: N_['off_n']=pos_d>>6; N_['bsh_n']=pos_d&63
                if m==PASS-1:
                    if R['pidx']==R['npos']-1: N_.update(state='FOLD',ft=0)
                    else: N_.update(pidx=R['pidx']+1,off=R['off_n'],bsh=R['bsh_n'],m=0,pa=R['pidx']+2,fp=0)
                else: N_['m']=m+1
            elif st=='FOLD':
                ft=R['ft']
                for c in range(NCH): N_['prevb'][c]=d2[c]
                N_['rv']=0
                if 2<=ft<=W+1:
                    j=ft-2
                    for c in range(NCH):
                        hj=shr(R['prevb'][c],SH)|shl(d2[c],64-SH); r=d1[c]^hj
                        N_['rr'][c]=r&s.MASK if j==W-1 else r
                    N_['rj']=j; N_['rv']=1
                if ft==W+2: N_['state']='DONE'
                else: N_['ft']=ft+1
            # memorias
            np_=pos_mem[R['pa']]; nd=[dens[c][dense_addr] if dense_addr<W else 0 for c in range(NCH)]
            n1=[0]*NCH; n2=[0]*NCH
            for c in range(NCH):
                assert 0<=a_1<s.ACCW and 0<=a_2<s.ACCW, (a_1,a_2,st)
                assert not (we1 and we2 and a_1==a_2)
                n1[c]=acc[c][a_1]; n2[c]=acc[c][a_2]
                if we1: acc[c][a_1]=0
                if we2: acc[c][a_2]=din2[c]
            pos_d=np_; dense_d=nd; d1=n1; d2=n2; R=N_; cyc+=1
            assert cyc<500000

if __name__=="__main__":
    from kat0 import H_INT, Y_POS
    rnd=random.Random(21); mul=PolyMul2(N,True); W=mul.W
    acc=[[rnd.getrandbits(64) for _ in range(mul.ACCW)] for _ in range(2)]   # contenido basura al empezar
    B_INT=(H_INT^(H_INT<<1))&((1<<N)-1)
    alt=[];lo=0;hi=N-1
    while len(alt)<75: alt+=[lo,hi]; lo+=1; hi-=1
    cases=[("KAT0 y*h (n=66)",Y_POS,H_INT,B_INT),("KAT0 otra vez (acc sucio)",Y_POS,H_INT,B_INT),
           ("KAT0 primeras 11",Y_POS[:11],H_INT,B_INT),("extremos alternados n=75",alt[:75],H_INT,B_INT),
           ("n=1 [N-1]",[N-1],H_INT,B_INT),("n=1 [0]",[0],H_INT,B_INT)]
    for _ in range(6):
        pos=rnd.sample(range(N),rnd.choice([66,75])); cases.append(("aleatorio n=%d"%len(pos),pos,rnd.getrandbits(N),rnd.getrandbits(N)))
    bad=0
    for name,pos,a,b in cases:
        res,info=mul.run(pos,[words_of(a),words_of(b)],acc)
        ok=all(None not in res[c] and vec_of(res[c])==H.vect_mul(vec(pos),v) for c,v in enumerate((a,b)))
        bad+=not ok
        print(f"{'OK ' if ok else 'FALLA'} {name:28s} latencia {info['latency']:6d} = {len(pos)}*{mul.PASS}+{info['latency']-len(pos)*mul.PASS}")
    print("fallos:",bad)

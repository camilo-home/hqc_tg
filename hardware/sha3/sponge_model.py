import hashlib
M=(1<<64)-1
RC=[0x1,0x8082,0x800000000000808A,0x8000000080008000,0x808B,0x80000001,0x8000000080008081,0x8000000000008009,0x8A,0x88,0x80008009,0x8000000A,0x8000808B,0x800000000000008B,0x8000000000008089,0x8000000000008003,0x8000000000008002,0x8000000000000080,0x800A,0x800000008000000A,0x8000000080008081,0x8000000000008080,0x80000001,0x8000000080008008]
R=[[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]]
rol=lambda v,n:((v<<n)|(v>>(64-n)))&M if n else v
def kf(A):  # A[x+5y]
    for rc in RC:
        C=[A[x]^A[x+5]^A[x+10]^A[x+15]^A[x+20] for x in range(5)]
        D=[C[(x-1)%5]^rol(C[(x+1)%5],1) for x in range(5)]
        A=[A[i]^D[i%5] for i in range(25)]
        B=[0]*25
        for x in range(5):
            for y in range(5): B[y+5*((2*x+3*y)%5)]=rol(A[x+5*y],R[x][y])
        A=[B[x+5*y]^((~B[(x+1)%5+5*y])&B[(x+2)%5+5*y]) for y in range(5) for x in range(5)]
        A[0]^=rc
    return A
MODES={0:(21,0x1F),1:(17,0x1F),2:(17,0x06),3:(9,0x06)}
def sponge(mode,msg,outlen):
    rate,suf=MODES[mode]
    if mode==2: outlen=32
    if mode==3: outlen=64
    A=[0]*25; lane=0; left=len(msg); pos=0
    # S_CMD
    state='PAD1' if left==0 else 'ABSORB'; pad_lane=pad_off=0
    while True:
        if state=='ABSORB':
            nb=min(8,left); w=int.from_bytes(msg[pos:pos+nb]+b'\xA5'*(8-nb),'little')  # basura en bytes no válidos
            m=w if left>=8 else w&((1<<(8*nb))-1)
            A[lane]^=m; pos+=nb
            if left>=8:
                left-=8
                if lane==rate-1:
                    lane=0; A=kf(A)
                    if left==0: state='PAD1'; pad_lane=pad_off=0
                else:
                    lane+=1
                    if left==0: state='PAD1'; pad_lane=lane; pad_off=0
            else:
                left=0; pad_lane=lane; pad_off=nb; state='PAD1'
        elif state=='PAD1':
            A[pad_lane]^=suf<<(8*pad_off); A[rate-1]^=0x80<<56; lane=0; break
    if outlen==0: return b''
    A=kf(A); out=b''; left=outlen
    while True:
        w=A[lane].to_bytes(8,'little')
        if left<=8: return out+w[:left]
        out+=w; left-=8
        if lane==rate-1: lane=0; A=kf(A)
        else: lane+=1
def ref(mode,msg,outlen):
    return [lambda m,n:hashlib.shake_128(m).digest(n),lambda m,n:hashlib.shake_256(m).digest(n),lambda m,n:hashlib.sha3_256(m).digest(),lambda m,n:hashlib.sha3_512(m).digest()][mode](msg,outlen)
if __name__=="__main__":
    bad=0;n=0
    for mode in range(4):
        for L in list(range(0,420))+[1000,2249]:
            msg=bytes((i*7+3)%256 for i in range(L))
            for ol in (0,1,7,8,9,32,64,135,136,137,168,169,300):
                if mode>=2 and ol not in (0,32): continue
                if ol==0 and mode<2:
                    continue
                n+=1
                if sponge(mode,msg,ol)!=ref(mode,msg,ol): bad+=1; print("FALLA",mode,L,ol)
    print("casos",n,"fallos",bad)

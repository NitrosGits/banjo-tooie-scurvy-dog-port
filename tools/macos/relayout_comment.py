import struct, hashlib, sys
src, replace = sys.argv[1], sys.argv[2] == 'replace'
d = bytearray(open(src,'rb').read())
shoff, = struct.unpack('>I', d[0x20:0x24]); ent, num, strndx = struct.unpack('>HHH', d[0x2e:0x34])
secs=[]
for i in range(num):
    f=struct.unpack('>10I', d[shoff+i*ent:shoff+(i+1)*ent])
    secs.append(dict(i=i,name=f[0],type=f[1],flags=f[2],addr=f[3],off=f[4],size=f[5],link=f[6],info=f[7],align=f[8],es=f[9]))
names=bytes(d[secs[strndx]['off']:secs[strndx]['off']+secs[strndx]['size']])
for s in secs: s['n']=names[s['name']:names.index(b'\0',s['name'])].decode()
data={s['i']:(b'' if s['type']==8 else bytes(d[s['off']:s['off']+s['size']])) for s in secs}
if replace:
    c=next(s for s in secs if s['n']=='.comment')
    data[c['i']]=data[c['i']].replace(b'/home/runner/work/llvm-project/llvm-project/clang',b'D:/a/llvm-project/llvm-project/clang')
    c['size']=len(data[c['i']])
order=sorted([s for s in secs if s['i']], key=lambda s:(s['off'], s['size']>0, s['i']))
cur=order[0]['off']; out=bytearray(d[:cur])
for s in order:
    a=max(s['align'],1); cur+=(-cur)%a; out+=b'\0'*(cur-len(out))
    s['off']=cur
    if s['type']!=8: out+=data[s['i']]; cur+=len(data[s['i']])
out+=b'\0'*((-cur)%4); cur=len(out)
for s in secs:
    out+=struct.pack('>10I',s['name'],s['type'],s['flags'],s['addr'],s['off'] if s['i'] else 0,s['size'],s['link'],s['info'],s['align'],s['es'])
out[0x20:0x24]=struct.pack('>I',cur)
print(hashlib.sha256(out).hexdigest())

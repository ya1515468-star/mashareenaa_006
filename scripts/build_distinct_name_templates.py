from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import random, math, shutil

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/name_templates'
SRC_DIR=Path('/mnt/data/mash_edit/animal_base/project/assets/name_templates')
source_indices=[1,6,11,16,21,26,31,36,41,46]
prototypes={i: Image.open(SRC_DIR/f'name_template_{source_indices[i-1]:02}.png').convert('RGBA') for i in range(1,11)}

families=[
  # family 0: natural reference, family 1: celestial, 2: frost, 3: fire, 4: royal/arcane
  {'name':'reference','color':(255,226,145)},
  {'name':'celestial','color':(178,220,255)},
  {'name':'frost','color':(210,245,255)},
  {'name':'fire','color':(255,165,85)},
  {'name':'royal','color':(231,202,255)},
]

def starfield(size, seed, color, count=16, edge_bias=False):
    W,H=size; rng=random.Random(seed); layer=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    for _ in range(count):
        x=rng.uniform(W*.04,W*.96); y=rng.uniform(H*.02,H*.82)
        if edge_bias and W*.28 < x < W*.72: continue
        r=rng.uniform(.4,1.5); a=rng.randint(45,135)
        d.ellipse((x-r,y-r,x+r,y+r), fill=(*color,a))
        if r>1.0 and rng.random()<.35:
            d.line((x-r*3,y,x+r*3,y), fill=(*color,a//2), width=1)
            d.line((x,y-r*3,x,y+r*3), fill=(*color,a//2), width=1)
    return layer.filter(ImageFilter.GaussianBlur(.12))

def soft_glow(size, center, radius, color, alpha):
    W,H=size; layer=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    x,y=center; d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=(*color,alpha))
    return layer.filter(ImageFilter.GaussianBlur(radius*.42))

def ring(size, variant, color):
    W,H=size; layer=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    if variant==0:
        d.arc((W*.34,H*.015,W*.66,H*.62),200,340,fill=(*color,80),width=1)
        d.arc((W*.32,-H*.04,W*.68,H*.58),205,335,fill=(*color,42),width=1)
    elif variant==1:
        d.arc((W*.20,H*.12,W*.80,H*.74),210,330,fill=(*color,68),width=1)
        d.arc((W*.28,H*.04,W*.72,H*.60),190,350,fill=(*color,36),width=1)
    elif variant==2:
        for off in (0,.08,.16):
            d.arc((W*(.31-off),H*(.03-off*.2),W*(.69+off),H*(.56+off*.2)),200,340,fill=(*color,max(25,70-int(off*200))),width=1)
    elif variant==3:
        cx,cy=W*.5,H*.23
        for rr in (H*.13,H*.18,H*.23):
            d.ellipse((cx-rr*2.0,cy-rr,cx+rr*2.0,cy+rr),outline=(*color,45),width=1)
    else:
        # Crown-like rays, kept subtle and integrated into the source lighting.
        for k in range(7):
            x=W*(.36+k*.047); y=H*(.02+(.025 if k%2 else 0))
            d.line((x,y,x+(k-3)*1.8,y+H*.12),fill=(*color,55),width=1)
    return layer.filter(ImageFilter.GaussianBlur(.1))

def diagonal_sweep(size, color, seed):
    W,H=size; layer=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    rng=random.Random(seed)
    x=W*(.18+rng.random()*.62)
    d.line((x,H*.03,x-W*.12,H*.82),fill=(*color,50),width=1)
    d.line((x+2,H*.04,x-W*.10,H*.80),fill=(*color,22),width=1)
    return layer.filter(ImageFilter.GaussianBlur(.3))

def ember_trails(size, seed, color):
    W,H=size; rng=random.Random(seed); layer=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    for _ in range(10):
        x=rng.uniform(W*.08,W*.92); y=rng.uniform(H*.10,H*.78)
        length=rng.uniform(3,10)
        d.line((x,y,x+rng.uniform(-2,2),y+length),fill=(*color,rng.randint(55,125)),width=1)
    return layer.filter(ImageFilter.GaussianBlur(.15))

for n in range(1,51):
    prototype_index=((n-1)%10)+1
    family_index=(n-1)//10
    base=prototypes[prototype_index].copy()
    W,H=base.size
    f=families[family_index]
    color=f['color']
    # Every variant retains the real animal/frame from the reference and adds a different,
    # restrained treatment rather than merely changing hue/speed.
    if family_index==0:
        base.alpha_composite(starfield((W,H),n,color,9,edge_bias=True))
    elif family_index==1:
        base.alpha_composite(soft_glow((W,H),(W*.50,H*.17),H*.26,color,72))
        base.alpha_composite(ring((W,H),n%5,color))
        base.alpha_composite(starfield((W,H),n*17,color,20,edge_bias=False))
    elif family_index==2:
        base.alpha_composite(soft_glow((W,H),(W*.50,H*.20),H*.22,color,62))
        base.alpha_composite(ring((W,H),(n+1)%5,color))
        base.alpha_composite(starfield((W,H),n*19,(225,248,255),24,edge_bias=True))
    elif family_index==3:
        base.alpha_composite(soft_glow((W,H),(W*.50,H*.14),H*.24,(255,125,50),75))
        base.alpha_composite(diagonal_sweep((W,H),(255,205,120),n))
        base.alpha_composite(ember_trails((W,H),n*23,(255,180,90)))
    else:
        base.alpha_composite(soft_glow((W,H),(W*.50,H*.16),H*.25,(235,205,255),58))
        base.alpha_composite(ring((W,H),4,(255,235,190)))
        base.alpha_composite(starfield((W,H),n*29,color,15,edge_bias=True))
    base.save(OUT/f'name_template_{n:02}.png', optimize=True)
print('50 templates rebuilt: 10 reference animal/frame designs x 5 clearly different enhancement families.')

#!/usr/bin/env python3
# Gera screenshots de Wear OS (1024x1024, RGB sem transparencia) fieis ao app TempoRun,
# em 3 idiomas (pt-BR, en-GB, es-419). Baseado nas telas Compose reais.
import os, shutil
from PIL import Image, ImageDraw, ImageFont

S = 1024
CX = S // 2
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "wear-screenshots")
if os.path.isdir(OUT):
    shutil.rmtree(OUT)

FONT_R = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
_cache = {}
def F(size, bold=False):
    k = (size, bold)
    if k not in _cache:
        _cache[k] = ImageFont.truetype(FONT_B if bold else FONT_R, size)
    return _cache[k]

ORANGE=(255,107,53); WHITE=(245,245,245); GRAY=(150,150,150)
BLUE=(79,195,247); GREEN=(102,187,106); RED=(239,83,80); BLACK=(0,0,0); RING=(38,38,38)

def canvas():
    img = Image.new("RGB", (S, S), BLACK)
    d = ImageDraw.Draw(img)
    d.ellipse([6,6,S-6,S-6], outline=RING, width=4)
    return img, d

def t(d, xy, s, font, fill, anchor="mm"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def pill(d, cx, cy, s, font, bg=ORANGE, fg=BLACK, padx=46, pady=24):
    w = d.textlength(s, font=font); asc, desc = font.getmetrics(); h = asc+desc
    d.rounded_rectangle([cx-w/2-padx, cy-h/2-pady, cx+w/2+padx, cy+h/2+pady],
                        radius=(h+2*pady)/2, fill=bg)
    t(d, (cx,cy), s, font, fg, "mm")

def row(d, y, label, value, vcolor, lx=300, rx=724, lf=34, vf=38):
    t(d, (lx,y), label, F(lf), GRAY, "lm")
    t(d, (rx,y), value, F(vf,True), vcolor, "rm")

def cell(d, cx, cy, value, unit, vcolor=WHITE, vf=72, uf=32):
    t(d, (cx,cy), value, F(vf,True), vcolor, "mm")
    t(d, (cx,cy+52), unit, F(uf), GRAY, "mm")

# ── Telas (parametrizadas por idioma L) ──────────────────────────────────────
def s_inicio(L, p):
    img, d = canvas()
    t(d, (CX,410), "TempoRun", F(100,True), ORANGE)
    t(d, (CX,498), L["tagline"], F(40), GRAY)
    pill(d, CX, 612, L["start"], F(50,True))
    img.save(p)

def s_corrida(L, p):
    img, d = canvas()
    t(d, (CX,232), "28:14", F(140,True), WHITE)
    cell(d, CX-132, 392, L["dist"], "km", ORANGE)
    cell(d, CX+132, 392, "5:24", "/km", WHITE)
    hr="152"; bpm=L["bpm"]; z="Z4"
    fhr,fbpm,fz = F(70,True),F(30),F(30,True)
    w_hr=d.textlength(hr,fhr); w_bpm=d.textlength(bpm,fbpm); w_z=d.textlength(z,fz)
    badge_w=w_z+32; dot=30; g=12
    total=dot+g+w_hr+8+w_bpm+18+badge_w; x=CX-total/2; cy=556
    d.ellipse([x,cy-dot/2,x+dot,cy+dot/2], fill=ORANGE); x+=dot+g
    t(d,(x,cy),hr,fhr,WHITE,"lm"); x+=w_hr+8
    t(d,(x,cy+16),bpm,fbpm,GRAY,"lm"); x+=w_bpm+18
    d.rounded_rectangle([x,cy-26,x+badge_w,cy+26], radius=26, fill=ORANGE)
    t(d,(x+badge_w/2,cy),z,fz,BLACK,"mm")
    cell(d, CX-132, 688, "5:31", L["avg_lbl"], WHITE, vf=56)
    cell(d, CX+132, 688, "168", L["spm"], WHITE, vf=56)
    img.save(p)

def s_cardio(L, p):
    img, d = canvas()
    t(d, (CX,248), L["cardio_title"], F(48,True), ORANGE)
    for y,(l,v,c) in zip([358,428,498,568,638], L["cardio_rows"]):
        row(d, y, l, v, c)
    img.save(p)

def s_predicao(L, p):
    img, d = canvas()
    t(d, (CX,236), L["pred_title"], F(44,True), ORANGE)
    for y,(l,v,c) in zip([348,424,500,576], L["pred_rows"]):
        row(d, y, l, v, c, lf=38, vf=42)
    t(d, (CX,690), L["pred_foot"], F(28), GRAY)
    img.save(p)

def s_resumo(L, p):
    img, d = canvas()
    t(d, (CX,214), L["sum_title"], F(58,True), ORANGE)
    for y,(l,v,c) in zip([312,380,448,516,584], L["sum_rows"]):
        row(d, y, l, v, c, lf=34, vf=36)
    pill(d, CX, 700, L["sum_btn"], F(40,True))
    img.save(p)

def s_treino(L, p):
    img, d = canvas()
    t(d, (CX,224), L["today"], F(36), GRAY)
    t(d, (CX,300), L["today_type"], F(70,True), ORANGE)
    cell(d, CX-130, 410, "6 km", L["dist_lbl"], ORANGE, vf=58, uf=28)
    cell(d, CX+130, 410, "4:30", L["target_lbl"], ORANGE, vf=58, uf=28)
    t(d, (CX,538), L["today_desc"], F(34), WHITE)
    t(d, (CX,584), L["today_sub"], F(30), GRAY)
    pill(d, CX, 692, L["today_btn"], F(38,True))
    img.save(p)

SCREENS = [("01-inicio",s_inicio),("02-corrida",s_corrida),("03-cardio",s_cardio),
           ("04-predicao",s_predicao),("05-resumo",s_resumo),("06-treino",s_treino)]

STR = {
 "pt-BR": {
   "tagline":"Corrida do pulso","start":"Iniciar",
   "dist":"5,20","avg_lbl":"médio","bpm":"bpm","spm":"spm",
   "cardio_title":"Cardio",
   "cardio_rows":[("FC atual","152 bpm",ORANGE),("FC média","148 bpm",WHITE),
                  ("FC mín","96 bpm",BLUE),("FC máx","171 bpm",RED),("VO₂ máx","52,3 ml/kg",GREEN)],
   "pred_title":"Predição de prova",
   "pred_rows":[("5 km","19:42",ORANGE),("10 km","41:03",WHITE),("Meia","1:31:10",WHITE),("Maratona","3:09:24",WHITE)],
   "pred_foot":"Baseado no VO₂ máx · Daniels",
   "sum_title":"Corrida salva!",
   "sum_rows":[("Distância","5,20 km",ORANGE),("Tempo","28:14",WHITE),("Pace médio","5:24/km",WHITE),
               ("Melhor pace","5:02/km",ORANGE),("FC média","148 bpm",RED)],
   "sum_btn":"Nova corrida",
   "today":"Hoje","today_type":"Intervalado","dist_lbl":"distância","target_lbl":"alvo",
   "today_desc":"6 × 800m no limiar","today_sub":"rec. 2 min trote","today_btn":"Iniciar treino",
 },
 "en-GB": {
   "tagline":"Running from the wrist","start":"Start",
   "dist":"5.20","avg_lbl":"avg","bpm":"bpm","spm":"spm",
   "cardio_title":"Heart rate",
   "cardio_rows":[("Current HR","152 bpm",ORANGE),("Avg HR","148 bpm",WHITE),
                  ("Min HR","96 bpm",BLUE),("Max HR","171 bpm",RED),("VO₂ max","52.3 ml/kg",GREEN)],
   "pred_title":"Race prediction",
   "pred_rows":[("5 km","19:42",ORANGE),("10 km","41:03",WHITE),("Half","1:31:10",WHITE),("Marathon","3:09:24",WHITE)],
   "pred_foot":"Based on VO₂ max · Daniels",
   "sum_title":"Run saved!",
   "sum_rows":[("Distance","5.20 km",ORANGE),("Time","28:14",WHITE),("Avg pace","5:24/km",WHITE),
               ("Best pace","5:02/km",ORANGE),("Avg HR","148 bpm",RED)],
   "sum_btn":"New run",
   "today":"Today","today_type":"Intervals","dist_lbl":"distance","target_lbl":"target",
   "today_desc":"6 × 800m at threshold","today_sub":"2 min jog recovery","today_btn":"Start workout",
 },
 "es-419": {
   "tagline":"Correr desde la muñeca","start":"Iniciar",
   "dist":"5,20","avg_lbl":"prom.","bpm":"lpm","spm":"ppm",
   "cardio_title":"Frec. cardíaca",
   "cardio_rows":[("FC actual","152 lpm",ORANGE),("FC media","148 lpm",WHITE),
                  ("FC mín","96 lpm",BLUE),("FC máx","171 lpm",RED),("VO₂ máx","52,3 ml/kg",GREEN)],
   "pred_title":"Predicción de carrera",
   "pred_rows":[("5 km","19:42",ORANGE),("10 km","41:03",WHITE),("Media","1:31:10",WHITE),("Maratón","3:09:24",WHITE)],
   "pred_foot":"Según el VO₂ máx · Daniels",
   "sum_title":"¡Carrera guardada!",
   "sum_rows":[("Distancia","5,20 km",ORANGE),("Tiempo","28:14",WHITE),("Ritmo medio","5:24/km",WHITE),
               ("Mejor ritmo","5:02/km",ORANGE),("FC media","148 lpm",RED)],
   "sum_btn":"Nueva carrera",
   "today":"Hoy","today_type":"Intervalos","dist_lbl":"distancia","target_lbl":"objetivo",
   "today_desc":"6 × 800m en umbral","today_sub":"rec. 2 min trote","today_btn":"Iniciar entreno",
 },
}

for loc, L in STR.items():
    d = os.path.join(OUT, loc); os.makedirs(d, exist_ok=True)
    for name, fn in SCREENS:
        fn(L, os.path.join(d, f"{name}.png"))

print("Gerado em:", OUT)
for loc in STR:
    fs = sorted(os.listdir(os.path.join(OUT, loc)))
    print(f"  {loc}: {len(fs)} imagens -> {', '.join(fs)}")

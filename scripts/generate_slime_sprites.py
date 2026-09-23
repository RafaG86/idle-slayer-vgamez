"""
Generador de sprites pixel art para el Mob de Tierra: Earth Slime (Slime de Tierra).
Genera frames individuales transparentes (64x64) y una hoja de sprites / preview compuesto.
"""

from PIL import Image, ImageDraw
import math
import os

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "enemies", "slime"))
os.makedirs(OUT_DIR, exist_ok=True)

# Paleta Earth Slime (16-bit)
C_OUTLINE = (10, 42, 12, 255)       # Contorno oscuro profundo
C_SHADOW_DEEP = (18, 86, 16, 255)   # Sombra oscura
C_SHADOW_MID = (36, 148, 30, 255)   # Sombra media
C_BODY = (77, 216, 52, 255)         # Verde principal
C_HIGHLIGHT = (168, 255, 80, 255)   # Brillo lima
C_SPECULAR = (235, 255, 200, 255)   # Reflejo especular casi blanco
C_CORE = (212, 175, 55, 230)        # Núcleo cristal de tierra ámbar
C_CORE_GLOW = (255, 220, 100, 180)  # Resplandor del núcleo
C_EYE_WHITE = (245, 250, 245, 255)  # Esclerótica ojo
C_PUPIL = (12, 26, 14, 255)         # Pupila
C_SLASH_FX = (220, 255, 255, 255)   # Destello de corte espada

def draw_slime_body(img, cx, cy, rx, ry, squash=1.0, eye_state="normal", core=True, outline_width=2):
    """Dibuja el cuerpo redondeado del slime en img con gradiente y contorno estilo pixel art."""
    draw = ImageDraw.Draw(img)
    w, h = img.size
    
    # Renderizamos píxel a píxel dentro de una máscara elíptica orgánica (forma de gota/domo)
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / rx
            # Modificador para darle forma de domo (más plano abajo, más redondeado arriba)
            vert_factor = 1.0 + (y - cy) / (ry * 1.5)
            dy = (y - cy) / ry
            
            # Ecuación de superelipse para forma orgánica de slime
            dist = (abs(dx) ** 2.2) + (abs(dy) ** 2.0)
            
            # Base plana en el suelo
            if y > cy + ry * 0.85:
                # Fondo aplanado contra el suelo
                dist += ((y - (cy + ry * 0.85)) / (ry * 0.2)) ** 2
                
            if dist <= 1.0:
                # Dentro del slime
                # Calcular distancia al borde para el contorno
                if dist > 0.72:
                    img.putpixel((x, y), C_OUTLINE)
                elif dist > 0.58:
                    img.putpixel((x, y), C_SHADOW_DEEP)
                elif dist > 0.40 or dy > 0.25:
                    img.putpixel((x, y), C_SHADOW_MID)
                else:
                    # Zona superior / central
                    # Reflejo arriba a la izquierda
                    if dx < -0.15 and dy < -0.2:
                        img.putpixel((x, y), C_HIGHLIGHT)
                    else:
                        img.putpixel((x, y), C_BODY)
                        
    # Añadir reflejo especular curva (glint)
    glint_x = int(cx - rx * 0.38)
    glint_y = int(cy - ry * 0.42)
    for gx in range(glint_x - 3, glint_x + 4):
        for gy in range(glint_y - 2, glint_y + 3):
            if 0 <= gx < w and 0 <= gy < h:
                d = ((gx - glint_x)**2)/9.0 + ((gy - glint_y)**2)/4.0
                if d <= 1.0:
                    img.putpixel((gx, gy), C_SPECULAR)
                    
    # Núcleo interior (gema de tierra ámbar flotante en el centro)
    if core:
        core_x = int(cx + 2)
        core_y = int(cy + ry * 0.22)
        for ox in range(core_x - 4, core_x + 5):
            for oy in range(core_y - 3, core_y + 4):
                if 0 <= ox < w and 0 <= oy < h:
                    cdist = ((ox - core_x)**2)/16.0 + ((oy - core_y)**2)/9.0
                    if cdist <= 0.6:
                        img.putpixel((ox, oy), C_CORE_GLOW)
                    elif cdist <= 1.0:
                        img.putpixel((ox, oy), C_CORE)

    # Ojos expresivos
    if eye_state == "normal":
        # Dos ojos redondos amigables
        eye_y = int(cy - ry * 0.05)
        # Ojo izquierdo
        eye1_x = int(cx - rx * 0.28)
        # Ojo derecho
        eye2_x = int(cx + rx * 0.22)
        
        for ex in [eye1_x, eye2_x]:
            # Esclerótica blanca ovalada (5x6 px)
            for ox in range(ex - 2, ex + 3):
                for oy in range(eye_y - 3, eye_y + 3):
                    if 0 <= ox < w and 0 <= oy < h:
                        img.putpixel((ox, oy), C_EYE_WHITE)
            # Pupila oscura grande (3x4 px) mirando al frente/izquierda (hacia el héroe)
            for ox in range(ex - 2, ex + 1):
                for oy in range(eye_y - 2, eye_y + 2):
                    if 0 <= ox < w and 0 <= oy < h:
                        img.putpixel((ox, oy), C_PUPIL)
            # Brillo en el ojo (1 px blanco)
            if 0 <= ex - 1 < w and 0 <= eye_y - 2 < h:
                img.putpixel((ex - 1, eye_y - 2), (255, 255, 255, 255))
                
    elif eye_state == "squint":
        # Ojos achinados por el esfuerzo de salto
        eye_y = int(cy - ry * 0.02)
        eye1_x = int(cx - rx * 0.3)
        eye2_x = int(cx + rx * 0.22)
        for ex in [eye1_x, eye2_x]:
            for ox in range(ex - 3, ex + 3):
                if 0 <= ox < w and 0 <= eye_y < h:
                    img.putpixel((ox, eye_y), C_PUPIL)
                    img.putpixel((ox, eye_y - 1), C_OUTLINE)
                    
    elif eye_state == "shock":
        # Ojos en forma de cruz > < por recibir espadazo
        eye_y = int(cy - ry * 0.05)
        eye1_x = int(cx - rx * 0.28)
        eye2_x = int(cx + rx * 0.22)
        for (ex, mirror) in [(eye1_x, False), (eye2_x, True)]:
            for i in range(-3, 4):
                if mirror:
                    px1, py1 = ex - i, eye_y + i
                    px2, py2 = ex + i, eye_y + i
                else:
                    px1, py1 = ex + i, eye_y + i
                    px2, py2 = ex - i, eye_y + i
                if 0 <= px1 < w and 0 <= py1 < h:
                    img.putpixel((px1, py1), C_PUPIL)
                if 0 <= px2 < w and 0 <= py2 < h:
                    img.putpixel((px2, py2), C_PUPIL)


def generate_all_frames():
    frames = {}
    
    # ─── Animación WALK / BOUNCE (4 frames) ───────────────────────────────────
    # Frame 0: Reposo neutral (38x28 px)
    f0 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(f0, cx=32, cy=42, rx=19, ry=14, eye_state="normal")
    frames["walk_0"] = f0
    
    # Frame 1: Squash previo al impulso (44x20 px) - aplastado contra el piso
    f1 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(f1, cx=32, cy=46, rx=23, ry=10, eye_state="squint")
    frames["walk_1"] = f1
    
    # Frame 2: Airborne Stretch (salto en el aire, 26x34 px) - despegado 10px del piso
    f2 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(f2, cx=32, cy=30, rx=14, ry=17, eye_state="normal")
    frames["walk_2"] = f2
    
    # Frame 3: Landing Squash (impacto en suelo, 42x22 px)
    f3 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(f3, cx=32, cy=44, rx=21, ry=12, eye_state="squint")
    frames["walk_3"] = f3
    
    # ─── Animación DEATH / SPLAT (3 frames) ───────────────────────────────────
    # Frame 0: Impacto / Corte de espada con destello blanco
    d0 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(d0, cx=32, cy=42, rx=19, ry=14, eye_state="shock")
    draw_d0 = ImageDraw.Draw(d0)
    # Tajo de espada blanco cian cruzando el cuerpo
    for i in range(-16, 17):
        tx = 32 + i
        ty = 42 - int(i * 0.7)
        for offset in [-1, 0, 1]:
            if 0 <= tx < 64 and 0 <= ty + offset < 64:
                d0.putpixel((tx, ty + offset), C_SLASH_FX)
    frames["death_0"] = d0
    
    # Frame 1: Splat horizontal - se divide en gotas y baba aplastada
    d1 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_slime_body(d1, cx=32, cy=50, rx=25, ry=6, eye_state="none", core=False)
    # Salpicaduras volando
    droplets = [(16, 38, 4), (48, 36, 4), (24, 28, 3), (38, 26, 3), (10, 48, 2), (54, 47, 2)]
    for (dx, dy, dr) in droplets:
        for ox in range(dx - dr, dx + dr + 1):
            for oy in range(dy - dr, dy + dr + 1):
                if ((ox - dx)**2 + (oy - dy)**2) <= dr**2 and 0 <= ox < 64 and 0 <= oy < 64:
                    if ((ox - dx)**2 + (oy - dy)**2) > (dr - 1)**2:
                        d1.putpixel((ox, oy), C_OUTLINE)
                    else:
                        d1.putpixel((ox, oy), C_BODY)
    frames["death_1"] = d1
    
    # Frame 2: Vaporización - solo burbujas pequeñas desvaneciéndose
    d2 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    smoke_bubbles = [
        (20, 48, 3, 160), (32, 46, 4, 180), (44, 49, 3, 150),
        (28, 36, 3, 120), (36, 32, 2, 90), (18, 30, 2, 70), (46, 28, 2, 70)
    ]
    for (bx, by, br, alpha) in smoke_bubbles:
        for ox in range(bx - br, bx + br + 1):
            for oy in range(by - br, by + br + 1):
                if ((ox - bx)**2 + (oy - by)**2) <= br**2 and 0 <= ox < 64 and 0 <= oy < 64:
                    col = (C_BODY[0], C_BODY[1], C_BODY[2], alpha)
                    d2.putpixel((ox, oy), col)
    frames["death_2"] = d2
    
    # Guardar frames individuales PNG
    for name, img in frames.items():
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        print(f"Guardado: {path}")
        
    # Crear Sheet compuesto de Preview (ampliado 4x para visualización limpia en alta resolución)
    # 4 frames walk arriba, 3 frames death abajo
    sheet_w = 64 * 4 * 4  # 1024 px
    sheet_h = 64 * 2 * 4  # 512 px
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (24, 26, 36, 255))
    
    draw_sheet = ImageDraw.Draw(sheet)
    
    # Fondo con cuadrícula sutil estilo pixel editor
    for y in range(0, sheet_h, 32):
        for x in range(0, sheet_w, 32):
            if ((x // 32) + (y // 32)) % 2 == 0:
                draw_sheet.rectangle([x, y, x + 31, y + 31], fill=(30, 32, 44, 255))
                
    # Pegar frames de WALK
    for i in range(4):
        f = frames[f"walk_{i}"].resize((256, 256), Image.Resampling.NEAREST)
        sheet.paste(f, (i * 256, 0), f)
        draw_sheet.text((i * 256 + 16, 12), f"WALK {i}", fill=(180, 220, 180, 255))
        
    # Pegar frames de DEATH
    for i in range(3):
        f = frames[f"death_{i}"].resize((256, 256), Image.Resampling.NEAREST)
        sheet.paste(f, (i * 256, 256), f)
        draw_sheet.text((i * 256 + 16, 256 + 12), f"DEATH {i}", fill=(255, 180, 180, 255))
        
    preview_path = os.path.join(OUT_DIR, "preview_mob_sheet.png")
    sheet.save(preview_path)
    print(f"Preview compuesto guardado: {preview_path}")

    # Generar GIF animado del ciclo de salto
    gif_frames = [
        frames["walk_0"].resize((128, 128), Image.Resampling.NEAREST),
        frames["walk_1"].resize((128, 128), Image.Resampling.NEAREST),
        frames["walk_2"].resize((128, 128), Image.Resampling.NEAREST),
        frames["walk_3"].resize((128, 128), Image.Resampling.NEAREST),
    ]
    gif_path = os.path.join(OUT_DIR, "slime_walk_anim.gif")
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=[140, 100, 180, 110],
        loop=0,
        disposal=2
    )
    print(f"GIF animado guardado: {gif_path}")

if __name__ == "__main__":
    generate_all_frames()

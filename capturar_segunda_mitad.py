import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"

def tap(x, y, delay=1.5):
    print(f"  [TAP] ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def back(delay=1.0):
    print("  [BACK]")
    subprocess.run(['adb', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'])
    time.sleep(delay)

def swipe(x1, y1, x2, y2, duration=350, delay=1.2):
    print(f"  [SWIPE] ({x1}, {y1}) -> ({x2}, {y2})")
    subprocess.run(['adb', 'shell', 'input', 'swipe', str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_screen.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_screen.png', out_path], check=True)
    im = Image.open(out_path)
    print(f"  ==> Capturada: {filename} - Tamaño: {im.size} (aspect: {im.size[0]/im.size[1]:.2f})")
    return out_path

def dump_ui():
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/view.xml'], capture_output=True)
    subprocess.run(['adb', 'pull', '/sdcard/view.xml', 'd:/PROYECTO SIEMBRAS/view.xml'], capture_output=True)
    tree = ET.parse('d:/PROYECTO SIEMBRAS/view.xml')
    items = []
    for elem in tree.getroot().iter():
        text = elem.attrib.get('text', '')
        desc = elem.attrib.get('content-desc', '')
        bounds = elem.attrib.get('bounds', '')
        clk = elem.attrib.get('clickable', 'false')
        if text or desc:
            items.append((bounds, clk, text or desc))
    return items

def find_bounds(keyword, items):
    for bounds, clk, content in items:
        if keyword.lower() in content.lower():
            parts = bounds.replace('[', ' ').replace(']', ' ').split()
            if len(parts) >= 2:
                p1 = parts[0].split(',')
                p2 = parts[1].split(',')
                x = (int(p1[0]) + int(p2[0])) // 2
                y = (int(p1[1]) + int(p2[1])) // 2
                return x, y, content
    return None

print("=== INICIANDO CAPTURA DE CULTIVOS, FORMULARIOS Y CANASTAS EN 2400x1080 ===")

# Asegurar bloqueo horizontal
subprocess.run(['adb', 'shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0'])
subprocess.run(['adb', 'shell', 'settings', 'put', 'system', 'user_rotation', '3'])

# 1. Abrir menú de cultivos tocando el FAB (+) en (2172, 957)
print("1. Abriendo Menú de Cultivos...")
tap(2172, 957, delay=2.0)
capture("02_menu_cultivos.png")

# 2. Entrar a Lirios
print("2. Abriendo Subgrupos de Lirios...")
items = dump_ui()
lirios = find_bounds("Lirios", items)
if lirios:
    tap(lirios[0], lirios[1], delay=1.8)
else:
    tap(377, 460, delay=1.8)
capture("03_subgrupos_lirios.png")

# 3. Entrar a Lirio LA
print("3. Abriendo Formulario Lirio LA...")
items = dump_ui()
la = find_bounds("Lirio LA", items)
if la:
    tap(la[0], la[1], delay=1.8)
else:
    tap(377, 460, delay=1.8)

# Escribir parrillas si encontramos el campo
items = dump_ui()
parr = find_bounds("PARRILLAS", items) or find_bounds("Parrilla", items)
if parr:
    tap(parr[0], parr[1], delay=0.8)
    subprocess.run(['adb', 'shell', 'input', 'text', '14'])
    subprocess.run(['adb', 'shell', 'input', 'keyevent', '111'])
    time.sleep(1.0)
capture("04_formulario_lirios_parrillas.png")

# 4. Canastas modal
print("4. Abriendo Canastas Modal...")
items = dump_ui()
can = find_bounds("Canasta", items)
if can:
    tap(can[0], can[1], delay=2.0)
else:
    # Buscar en la barra superior o botón
    tap(2150, 150, delay=2.0)
capture("05_rendimiento_lirios_canastas_modal.png")

# 5. Diálogo Canastas Rápidas (400, 425, 450)
print("5. Abriendo Diálogo Rápido Canasta...")
items = dump_ui()
plus = find_bounds("+ Canasta", items) or find_bounds("Canasta", items)
if plus:
    tap(plus[0], plus[1], delay=1.8)
else:
    tap(1850, 450, delay=1.8)
capture("16_dialogo_canasta_standard.png")
back(delay=1.0) # cerrar dialogo rápido
back(delay=1.0) # cerrar modal canastas

# 6. Formulario Lirios Lotes de Compra (scroll abajo)
print("6. Scroll a Lotes de Compra...")
swipe(1200, 850, 1200, 300, duration=450, delay=1.5)
capture("06_formulario_lirios_lotes_compra.png")
back(delay=1.0) # volver a subgrupos
back(delay=1.0) # volver a menú de selección de cultivo

# 7. Cremón bilateral
print("7. Abriendo Cremón Bilateral...")
items = dump_ui()
crem = find_bounds("Cremon", items)
if crem:
    tap(crem[0], crem[1], delay=1.8)
else:
    tap(1000, 460, delay=1.8)
capture("07_formulario_cremon_bilateral.png")

# 8. Cremón Pasó al otro lado
print("8. Activando Pasó al otro lado...")
items = dump_ui()
paso = find_bounds("Pasó al otro lado", items) or find_bounds("Paso", items)
if paso:
    tap(paso[0], paso[1], delay=1.5)
else:
    swipe(1200, 850, 1200, 450, duration=350, delay=1.0)
    items = dump_ui()
    paso = find_bounds("Pasó", items)
    if paso:
        tap(paso[0], paso[1], delay=1.5)
capture("08_formulario_cremon_paso_otro_lado.png")
back(delay=1.0) # volver a menú cultivo

# 9. Planta Madre
print("9. Abriendo Planta Madre...")
items = dump_ui()
pm = find_bounds("Planta Madre", items)
if pm:
    tap(pm[0], pm[1], delay=1.8)
else:
    tap(2130, 762, delay=1.8)
capture("09_formulario_areas_especiales_planta_madre.png")
back(delay=1.0) # volver a menú cultivo
back(delay=1.0) # volver a dashboard

print("=== FINALIZADO EXITOSAMENTE ===")

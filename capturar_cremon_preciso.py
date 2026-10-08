import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"

def dump_ui():
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/view.xml'], capture_output=True)
    subprocess.run(['adb', 'pull', '/sdcard/view.xml', 'd:/PROYECTO SIEMBRAS/view.xml'], capture_output=True)
    tree = ET.parse('d:/PROYECTO SIEMBRAS/view.xml')
    items = []
    for elem in tree.getroot().iter():
        text = elem.attrib.get('text', '')
        desc = elem.attrib.get('content-desc', '')
        bounds = elem.attrib.get('bounds', '')
        if text or desc:
            items.append((bounds, text or desc))
    return items

def find(keyword, items):
    for bounds, content in items:
        if keyword.lower() in content.lower():
            parts = bounds.replace('[', ' ').replace(']', ' ').split()
            if len(parts) >= 2:
                p1 = parts[0].split(',')
                p2 = parts[1].split(',')
                x = (int(p1[0]) + int(p2[0])) // 2
                y = (int(p1[1]) + int(p2[1])) // 2
                return x, y
    return None

def tap(x, y, delay=1.5):
    print(f"  Tap ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_c.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_c.png', out_path], check=True)
    im = Image.open(out_path)
    print(f"  ==> Capturada {filename}: {im.size}")
    return out_path

# 1. Asegurar app en primer plano
print("Trayendo app al frente...")
subprocess.run(['adb', 'shell', 'monkey', '-p', 'com.example.app_movil', '-c', 'android.intent.category.LAUNCHER', '1'], capture_output=True)
time.sleep(2.0)

# Verificar UI
items = dump_ui()
# Si estamos en dashboard, tap FAB (+)
fab = find("button", items)
print("Abriendo menú de cultivos...")
tap(2172, 957, delay=2.0)

# En menú de cultivo, encontrar Cremon
items = dump_ui()
cremon = find("Cremon", items)
if cremon:
    print(f"Encontrado Cremon en {cremon}")
    tap(cremon[0], cremon[1], delay=2.0)
else:
    tap(975, 460, delay=2.0)

# Ya en formulario de Cremón
items = dump_ui()
# Scroll para ver los 4 botones
subprocess.run(['adb', 'shell', 'input', 'swipe', '1200', '800', '1200', '450', '350'])
time.sleep(1.0)
capture("07_formulario_cremon_bilateral.png")

# Tocar 'Pasó al otro lado'
items = dump_ui()
paso = find("Pasó al otro lado", items) or find("Paso", items)
if paso:
    print(f"Encontrado botón Pasó al otro lado en {paso}")
    tap(paso[0], paso[1], delay=1.5)
else:
    tap(630, 685, delay=1.5)

# Capturar 08
capture("08_formulario_cremon_paso_otro_lado.png")

# Volver a dashboard
subprocess.run(['adb', 'shell', 'input', 'keyevent', '4'])
time.sleep(1.0)
subprocess.run(['adb', 'shell', 'input', 'keyevent', '4'])
time.sleep(1.0)

print("¡Listo Cremón!")

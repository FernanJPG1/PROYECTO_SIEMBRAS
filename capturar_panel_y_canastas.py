import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET

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

def tap(x, y, delay=1.5):
    print(f"Tap ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def back(delay=1.0):
    print("Back")
    subprocess.run(['adb', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_screen.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_screen.png', out_path], check=True)
    print(f"Captured: {filename}")

# First bring app to front
subprocess.run(['adb', 'shell', 'monkey', '-p', 'com.example.app_movil', '-c', 'android.intent.category.LAUNCHER', '1'])
time.sleep(1.5)

# Step A: Admin Panel
print("=== ABRIENDO PANEL DE ADMINISTRACIÓN ===")
tap(1013, 183, delay=1.0) # 3 puntos
items = dump_ui()
found = find_bounds("Panel de Administrador", items)
if found:
    tap(found[0], found[1], delay=1.2)
else:
    tap(500, 480, delay=1.2)

# PIN Dialog
items = dump_ui()
ingresar = find_bounds("Ingresar", items)
if ingresar:
    print("Encontrado botón Ingresar en", ingresar)
    tap(ingresar[0], ingresar[1], delay=2.0)
else:
    tap(750, 1500, delay=2.0)

# We are in Admin Panel
capture("11_panel_administracion.png")

# Step B: Rendimiento Dialog
print("=== ABRIENDO RENDIMIENTO DIALOG ===")
items = dump_ui()
rend = find_bounds("Ver Rendimiento", items) or find_bounds("Rendimiento", items)
if rend:
    tap(rend[0], rend[1], delay=2.5)
else:
    tap(434, 787, delay=2.5)

capture("12_ranking_rendimiento_podio.png")
back(delay=1.0) # Close Rendimiento Dialog

# Step C: Reportes PDF Dialog
print("=== ABRIENDO REPORTES PDF DIALOG ===")
items = dump_ui()
rep = find_bounds("Reportes PDF", items) or find_bounds("DOCUMENTACIÓN OFICIAL", items) or find_bounds("PDF", items)
if rep:
    tap(rep[0], rep[1], delay=2.5)
else:
    # scroll admin panel slightly
    subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1500', '500', '1000', '300'])
    time.sleep(1.0)
    items = dump_ui()
    rep = find_bounds("PDF", items) or find_bounds("Reportes", items)
    if rep:
        tap(rep[0], rep[1], delay=2.5)
    else:
        tap(434, 1100, delay=2.5)

capture("13_dialogo_reporte_pdf.png")
back(delay=1.0) # Close Reporte Dialog
back(delay=1.0) # Back to Dashboard

# Step D: Canastas Quick Buttons
print("=== ABRIENDO DIÁLOGO DE CANASTA CON BOTONES 400/425/450 ===")
tap(957, 2143, delay=1.5) # FAB (+)
tap(285, 634, delay=1.5)  # Lirios
tap(540, 665, delay=1.5)  # Lirio LA
tap(490, 183, delay=1.5)  # Canasta icon
items = dump_ui()
# Find first "+ Canasta" button
plus_c = find_bounds("+ Canasta", items)
if plus_c:
    print(f"Encontrado + Canasta en {plus_c[0]}, {plus_c[1]}")
    tap(plus_c[0], plus_c[1], delay=1.8)
else:
    tap(791, 656, delay=1.8)

capture("16_dialogo_canasta_standard.png")
back(delay=1.0) # Close canasta dialog
back(delay=1.0) # Back to Lirios form
back(delay=1.0) # Back to subgrupos
back(delay=1.0) # Back to menu
back(delay=1.0) # Back to dashboard

print("¡Proceso completado exitosamente!")

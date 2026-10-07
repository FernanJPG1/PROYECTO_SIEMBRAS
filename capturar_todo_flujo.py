import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"
os.makedirs(IMG_DIR, exist_ok=True)

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
            # parse bounds [x1,y1][x2,y2]
            parts = bounds.replace('[', ' ').replace(']', ' ').split()
            if len(parts) >= 2:
                p1 = parts[0].split(',')
                p2 = parts[1].split(',')
                x = (int(p1[0]) + int(p2[0])) // 2
                y = (int(p1[1]) + int(p2[1])) // 2
                return x, y, content
    return None

def tap(x, y, delay=1.5):
    print(f"Tapping ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def back(delay=1.2):
    print("Back")
    subprocess.run(['adb', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_screen.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_screen.png', out_path], check=True)
    print(f"==> Foto capturada: {filename}")
    return out_path

# Step 1: Dashboard
print("1. Capturando Dashboard Principal...")
capture("01_dashboard_principal.png")

# Step 2: Open Menu Cultivos (tap FAB at 957, 2143)
print("2. Abriendo Menú de Cultivos...")
tap(957, 2143, delay=1.8)
capture("02_menu_cultivos.png")

# Step 3: Open Lirios
items = dump_ui()
found = find_bounds("Lirios", items)
if found:
    print(f"Encontrado Lirios en {found[0]}, {found[1]}")
    tap(found[0], found[1], delay=1.5)
else:
    print("Fallback Lirios tap (280, 500)")
    tap(280, 500, delay=1.5)

capture("03_subgrupos_lirios.png")

# Step 4: Open Lirio LA
items = dump_ui()
found = find_bounds("Lirio LA", items)
if found:
    print(f"Encontrado Lirio LA en {found[0]}, {found[1]}")
    tap(found[0], found[1], delay=1.5)
else:
    print("Fallback Lirio LA tap (300, 450)")
    tap(300, 450, delay=1.5)

capture("04_formulario_lirios_parrillas.png")

# Step 5: Canastas button in Lirios
items = dump_ui()
found = find_bounds("Canasta", items)
if found:
    print(f"Encontrado Canasta en {found[0]}, {found[1]}")
    tap(found[0], found[1], delay=1.8)
    capture("05_rendimiento_lirios_canastas_modal.png")
    back(delay=1.0)
else:
    # scroll down
    subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1500', '500', '500', '300'])
    time.sleep(1.2)
    items = dump_ui()
    found = find_bounds("Canasta", items)
    if found:
        tap(found[0], found[1], delay=1.8)
        capture("05_rendimiento_lirios_canastas_modal.png")
        back(delay=1.0)

# Step 6: Scroll down in Form Lirios to show Compras / Lotes
subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1600', '500', '600', '300'])
time.sleep(1.2)
capture("06_formulario_lirios_lotes_compra.png")

# Go back to Menu Cultivos
back(delay=1.0) # back to subgrupos
back(delay=1.0) # back to menu cultivos

# Step 7: Open Cremon
items = dump_ui()
found = find_bounds("Cremon", items)
if found:
    print(f"Encontrado Cremon en {found[0]}, {found[1]}")
    tap(found[0], found[1], delay=1.5)
else:
    tap(750, 500, delay=1.5)

capture("07_formulario_cremon_bilateral.png")

# Scroll down to show Pasó al otro lado
subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1600', '500', '800', '300'])
time.sleep(1.2)
capture("08_formulario_cremon_paso_otro_lado.png")

# Go back to Menu Cultivos
back(delay=1.0)

# Step 8: Open Planta Madre
items = dump_ui()
found = find_bounds("Planta Madre", items)
if found:
    tap(found[0], found[1], delay=1.5)
else:
    # scroll menu
    subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1600', '500', '800', '300'])
    time.sleep(1.0)
    items = dump_ui()
    found = find_bounds("Planta Madre", items)
    if found:
        tap(found[0], found[1], delay=1.5)

capture("09_formulario_areas_especiales_planta_madre.png")

# Go back to Dashboard
back(delay=1.0) # back to menu
back(delay=1.0) # back to dashboard

# Step 9: Open Detalle de Siembra (Eye icon on first card)
items = dump_ui()
found = find_bounds("Ver detalle", items)
if found:
    tap(found[0], found[1], delay=1.5)
    capture("10_modal_detalle_siembra.png")
    back(delay=1.0)

# Step 10: Open Más opciones -> Panel Admin
tap(1013, 183, delay=1.2)
items = dump_ui()
found = find_bounds("Panel de Administrador", items)
if found:
    tap(found[0], found[1], delay=1.5)
    # Confirm PIN dialog by tapping Confirmar (PIN defaults to 1234)
    items = dump_ui()
    confirm_btn = find_bounds("INGRESAR", items) or find_bounds("CONFIRMAR", items) or find_bounds("Aceptar", items)
    if confirm_btn:
        tap(confirm_btn[0], confirm_btn[1], delay=1.5)
    else:
        # Default confirm button position in dialog
        tap(750, 1380, delay=1.5)
    
    capture("11_panel_administracion.png")

    # Step 11: Open Rendimientos in Admin Panel
    items = dump_ui()
    rend_btn = find_bounds("Rendimiento", items)
    if rend_btn:
        tap(rend_btn[0], rend_btn[1], delay=1.5)
        capture("12_ranking_rendimiento_podio.png")
        back(delay=1.0)

    # Step 12: Open Reportes in Admin Panel
    items = dump_ui()
    rep_btn = find_bounds("Reporte", items) or find_bounds("PDF", items)
    if rep_btn:
        tap(rep_btn[0], rep_btn[1], delay=1.5)
        capture("13_dialogo_reporte_pdf.png")
        back(delay=1.0)
    
    back(delay=1.0) # back to dashboard

# Step 13: Sincronización dialog
tap(1013, 183, delay=1.2)
items = dump_ui()
found = find_bounds("Configurar IP", items)
if found:
    tap(found[0], found[1], delay=1.5)
    capture("14_configuracion_sincronizacion.png")
    back(delay=1.0)

print("¡Todas las pantallas fueron capturadas con éxito!")

import subprocess
import time
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"

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

# First go back to home dashboard
for _ in range(4):
    back(delay=0.3)

# 1. Capture locked card (VINCENT 4 days old)
print("1. Capturando detalle bloqueado (> 2 días)...")
# In dashboard, scroll down to find Vincent card
subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1800', '500', '1000', '300'])
time.sleep(1.2)
# Tap on details of the 4-day old card (eye icon at roughly 792, 1200 or 792, 1600)
# Let's dump ui to find the eye icon for Vincent
subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/view.xml'])
subprocess.run(['adb', 'pull', '/sdcard/view.xml', 'd:/PROYECTO SIEMBRAS/view.xml'])

import xml.etree.ElementTree as ET
tree = ET.parse('d:/PROYECTO SIEMBRAS/view.xml')
for elem in tree.getroot().iter():
    cd = elem.attrib.get('content-desc', '')
    bounds = elem.attrib.get('bounds', '')
    if 'Ver detalle' in cd or 'info' in cd.lower() or 'VINCENT' in cd:
        print(f"Found: {bounds} -> {cd[:30]}")

# Let's tap 'Ver detalle' on the second card
tap(792, 1680, delay=1.5)
capture("14_bloqueo_seguridad_2_dias.png")
back(delay=1.0)

# Scroll back to top
subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '500', '500', '1800', '300'])
time.sleep(1.0)

# 2. Capture Admin Panel -> Rendimiento Dialog
print("2. Capturando Rendimiento Dialog (Podio de Medallas)...")
tap(1013, 183, delay=1.0) # 3 puntos
tap(400, 480, delay=1.5)  # Admin panel
tap(755, 1505, delay=1.5) # PIN confirmar
tap(434, 787, delay=2.0)  # Orange button "Ver Rendimiento y Productividad"
capture("12_ranking_rendimiento_podio.png")
back(delay=1.0)

# 3. Capture Admin Panel -> Reportes PDF Dialog
print("3. Capturando Reportes PDF Dialog...")
tap(434, 910, delay=2.0)  # PDF card button
capture("13_dialogo_reporte_pdf.png")
back(delay=1.0)
back(delay=1.0) # back to dashboard

# 4. Capture Canastas Quick Buttons (400, 425, 450)
print("4. Capturando Canastas Quick Buttons...")
tap(957, 2143, delay=1.5) # FAB (+)
tap(285, 634, delay=1.5)  # Lirios
tap(540, 665, delay=1.5)  # Lirio LA
tap(490, 183, delay=1.5)  # Canasta icon
# Tap '+ Canasta' on first employee (Abelardo) at (800, 650)
tap(800, 650, delay=1.8)
capture("16_dialogo_canasta_standard.png")
back(delay=1.0)
back(delay=1.0)
back(delay=1.0)
back(delay=1.0)

print("¡Listo todo!")

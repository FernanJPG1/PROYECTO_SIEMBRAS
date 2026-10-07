import subprocess, time, os, sys

sys.stdout.reconfigure(encoding='utf-8')
IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"

def tap(x, y, delay=1.5):
    print(f"Tap ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_screen.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_screen.png', out_path], check=True)
    print(f"Captured: {filename}")

# Swipe slightly up so VINCENT card is fully visible
subprocess.run(['adb', 'shell', 'input', 'swipe', '500', '1500', '500', '900', '300'])
time.sleep(1.2)

# Dump UI to find exactly the info button for VINCENT
subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/view.xml'])
subprocess.run(['adb', 'pull', '/sdcard/view.xml', 'd:/PROYECTO SIEMBRAS/view.xml'])

import xml.etree.ElementTree as ET
tree = ET.parse('d:/PROYECTO SIEMBRAS/view.xml')
for elem in tree.getroot().iter():
    cd = elem.attrib.get('content-desc', '')
    bounds = elem.attrib.get('bounds', '')
    if 'Ver detalle' in cd or 'Finalizar' in cd:
        print(f"{bounds} -> {cd[:40]}")

# Tap the info button on VINCENT card (around 735, 1550)
tap(735, 1550, delay=1.5)
capture("14_bloqueo_seguridad_2_dias.png")

# Close dialog
tap(800, 2030, delay=1.0) # Cerrar button

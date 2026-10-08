import subprocess
import time
import os
import sys
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"

def launch_app():
    subprocess.run(['adb', 'shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0'])
    subprocess.run(['adb', 'shell', 'settings', 'put', 'system', 'user_rotation', '3'])
    subprocess.run(['adb', 'shell', 'monkey', '-p', 'com.example.app_movil', '-c', 'android.intent.category.LAUNCHER', '1'], capture_output=True)
    time.sleep(2.0)

def tap(x, y, delay=1.5):
    print(f"  [TAP] ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def back(delay=1.0):
    print("  [BACK]")
    subprocess.run(['adb', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'])
    time.sleep(delay)

def swipe(x1, y1, x2, y2, duration=400, delay=1.5):
    print(f"  [SWIPE] ({x1}, {y1}) -> ({x2}, {y2})")
    subprocess.run(['adb', 'shell', 'input', 'swipe', str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_scr.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_scr.png', out_path], check=True)
    im = Image.open(out_path)
    print(f"  ==> Capturada {filename}: {im.size} (aspect: {im.size[0]/im.size[1]:.2f})")
    return out_path

print("=== CAPTURANDO LAS 5 PANTALLAS FALTANTES EN LANDSCAPE (2400x1080) ===")

# --- SCREEN A: Lirios Lotes de Compra (06) ---
print("\n--- A. Capturando 06_formulario_lirios_lotes_compra.png ---")
launch_app()
# Tap FAB (+) en dashboard
tap(2172, 957, delay=2.0)
# Tap Lirios
tap(377, 460, delay=2.0)
# Tap Lirio LA
tap(220, 650, delay=2.0)
# Scroll abajo en formulario Lirio LA para mostrar Lote 187, Contenedor y Proveedor
swipe(1200, 850, 1200, 250, duration=450, delay=1.8)
capture("06_formulario_lirios_lotes_compra.png")

# --- SCREEN B: Canasta Quick Dialog 400/425/450 (16) ---
print("\n--- B. Capturando 16_dialogo_canasta_standard.png ---")
# Scroll arriba en formulario de Lirio LA
swipe(1200, 250, 1200, 850, duration=450, delay=1.5)
# Tap "CANASTAS" o "Medir Canastas" (está en la barra superior verde x=1574, y=145 o botón x=830, y=700)
tap(1574, 145, delay=2.0)
# Tap "+ Canasta" en Abelardo Pantoja en la lista (x=850, y=730)
tap(850, 730, delay=2.0)
capture("16_dialogo_canasta_standard.png")
# Cerrar diálogo rápido
back(delay=1.0)
# Cerrar pantalla canastas
back(delay=1.0)
# Cerrar formulario Lirio LA
back(delay=1.0)
# Cerrar subgrupos Lirios -> ahora en Menú de Cultivos
back(delay=1.0)

# --- SCREEN C: Cremón Bilateral (07) y Pasó al otro lado (08) ---
print("\n--- C. Capturando 07_formulario_cremon_bilateral.png ---")
# Si no estamos en el menú de cultivos, asegurarlo
launch_app()
tap(2172, 957, delay=2.0) # FAB (+)
# Tap Cremon (columna 2, fila 1: x=1000, y=460)
tap(1000, 460, delay=2.5)
capture("07_formulario_cremon_bilateral.png")

print("\n--- D. Capturando 08_formulario_cremon_paso_otro_lado.png ---")
# En el formulario de Cremón, buscar o tocar "Pasó al otro lado"
# Scroll un poco hacia abajo
swipe(1200, 750, 1200, 450, duration=350, delay=1.2)
# Tap botón "Pasó al otro lado" (suele estar en la botonera bilateral)
# Intentemos con el tap o dump
capture("08_formulario_cremon_paso_otro_lado.png")
back(delay=1.0) # salir de Cremon

# --- SCREEN E: Planta Madre (09) ---
print("\n--- E. Capturando 09_formulario_areas_especiales_planta_madre.png ---")
launch_app()
tap(2172, 957, delay=2.0) # FAB (+)
# Tap Planta Madre (columna 4, fila 2: x=2130, y=762)
tap(2130, 762, delay=2.5)
capture("09_formulario_areas_especiales_planta_madre.png")
back(delay=1.0)

print("\n=== ¡PROCESO DE LAS 5 PANTALLAS COMPLETADO! ===")

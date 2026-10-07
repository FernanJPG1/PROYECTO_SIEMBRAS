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
    print(f"Captured {filename}")

# First, return to dashboard if needed
back(delay=0.5)
back(delay=0.5)

# Capture Sync dialog
print("Capturando Sincronización...")
tap(1013, 183, delay=1.0) # 3 puntos
tap(400, 320, delay=1.5)  # Configurar IP / Servidor
capture("15_configuracion_sincronizacion.png")
back(delay=1.0)

# Capture Reportes PDF
print("Capturando Reportes PDF...")
tap(1013, 183, delay=1.0) # 3 puntos
tap(400, 480, delay=1.5)  # Panel Admin
tap(755, 1505, delay=1.5) # Confirmar PIN 1234
tap(637, 950, delay=1.8)  # Tarjeta de Reportes PDF
capture("13_dialogo_reporte_pdf.png")
back(delay=1.0)
back(delay=1.0)

# Try tapping edit on an old record to show "Registro Bloqueado (> 2 días)"
print("Capturando diálogo de Bloqueo de Seguridad...")
# Tap on an edit icon or long press a card
# In dashboard, tap on "Editar Registros" at (1002, 331) or tap pencil
tap(1002, 331, delay=1.2)
capture("14_bloqueo_seguridad_2_dias.png")

print("Listo!")

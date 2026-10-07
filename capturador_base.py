import subprocess
import time
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"
os.makedirs(IMG_DIR, exist_ok=True)

def adb_cmd(args):
    res = subprocess.run(['adb'] + args, capture_output=True, text=True)
    return res.stdout.strip()

def tap(x, y, delay=1.2):
    print(f"Tap at ({x}, {y})")
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    time.sleep(delay)

def back(delay=1.0):
    print("Press BACK")
    subprocess.run(['adb', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'])
    time.sleep(delay)

def capture(filename):
    out_path = os.path.join(IMG_DIR, filename)
    subprocess.run(['adb', 'shell', 'screencap', '-p', '/sdcard/temp_screen.png'], check=True)
    subprocess.run(['adb', 'pull', '/sdcard/temp_screen.png', out_path], check=True)
    print(f"-> Guardada imagen: {filename}")
    return out_path

print("Iniciando captura guiada de pantallas...")

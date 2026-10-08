import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

IMG_DIR = r"d:\PROYECTO SIEMBRAS\manual_imagenes"
os.makedirs(IMG_DIR, exist_ok=True)

def adb_cmd(cmd_list):
    return subprocess.run(['adb'] + cmd_list, capture_output=True, text=True)

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
    print(f"  ==> Capturada imagen horizontal: {filename}")
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

def go_home():
    print("Regresando a Home...")
    for _ in range(4):
        back(delay=0.4)
    # launch app if needed
    subprocess.run(['adb', 'shell', 'monkey', '-p', 'com.example.app_movil', '-c', 'android.intent.category.LAUNCHER', '1'], capture_output=True)
    time.sleep(1.5)

def run_all_captures():
    print("=== INICIANDO FLUJO COMPLETO DE CAPTURAS HORIZONTALES ===")
    
    # 1. Asegurar que estamos en el dashboard con vista de tarjetas
    go_home()
    items = dump_ui()
    v_cards = find_bounds("Ver como Tarjetas", items)
    if v_cards:
        print("Cambiando a vista de tarjetas...")
        tap(v_cards[0], v_cards[1], delay=1.5)
    
    # Capturar 01_dashboard_principal.png
    print("1. Capturando 01_dashboard_principal.png...")
    capture("01_dashboard_principal.png")
    
    # 2. Modal detalle siembra (tocar icono info en la primera tarjeta)
    print("2. Capturando 10_modal_detalle_siembra.png...")
    items = dump_ui()
    info_btn = find_bounds("info", items) or find_bounds("detalle", items)
    if info_btn:
        tap(info_btn[0], info_btn[1], delay=1.5)
    else:
        tap(2010, 830, delay=1.5)
    capture("10_modal_detalle_siembra.png")
    back(delay=1.0)
    
    # 3. Modal bloqueo seguridad > 2 días (deslizar y buscar tarjeta de 4 días)
    print("3. Capturando 14_bloqueo_seguridad_2_dias.png...")
    swipe(1200, 850, 1200, 300, duration=400, delay=1.5)
    items = dump_ui()
    info_btn = find_bounds("info", items) or find_bounds("detalle", items)
    if info_btn:
        tap(info_btn[0], info_btn[1], delay=1.5)
    else:
        tap(2010, 830, delay=1.5)
    capture("14_bloqueo_seguridad_2_dias.png")
    back(delay=1.0)
    
    # Regresar arriba en dashboard
    swipe(1200, 300, 1200, 850, duration=350, delay=1.0)
    
    # 4. Configurar IP / Sincronización
    print("4. Capturando 15_configuracion_sincronizacion.png...")
    items = dump_ui()
    ip_btn = find_bounds("Configurar IP", items)
    if ip_btn:
        tap(ip_btn[0], ip_btn[1], delay=1.5)
    else:
        tap(1804, 145, delay=1.5)
    capture("15_configuracion_sincronizacion.png")
    back(delay=1.0)
    
    # 5. Panel de Administrador
    print("5. Capturando 11_panel_administracion.png...")
    items = dump_ui()
    admin_btn = find_bounds("Panel de Administrador", items)
    if admin_btn:
        tap(admin_btn[0], admin_btn[1], delay=1.5)
    else:
        tap(2072, 145, delay=1.5)
    
    # Confirmar PIN
    items = dump_ui()
    conf_pin = find_bounds("INGRESAR", items) or find_bounds("CONFIRMAR", items) or find_bounds("Aceptar", items)
    if conf_pin:
        tap(conf_pin[0], conf_pin[1], delay=2.0)
    else:
        tap(1400, 750, delay=2.0)
    
    capture("11_panel_administracion.png")
    
    # 6. Rendimiento Podio dentro de Admin
    print("6. Capturando 12_ranking_rendimiento_podio.png...")
    items = dump_ui()
    rend_btn = find_bounds("Rendimiento", items) or find_bounds("Productividad", items)
    if rend_btn:
        tap(rend_btn[0], rend_btn[1], delay=2.5)
    else:
        tap(600, 480, delay=2.5)
    capture("12_ranking_rendimiento_podio.png")
    back(delay=1.2)
    
    # 7. Reporte PDF dentro de Admin
    print("7. Capturando 13_dialogo_reporte_pdf.png...")
    items = dump_ui()
    rep_btn = find_bounds("Reporte", items) or find_bounds("PDF", items)
    if rep_btn:
        tap(rep_btn[0], rep_btn[1], delay=2.5)
    else:
        tap(1200, 480, delay=2.5)
    capture("13_dialogo_reporte_pdf.png")
    back(delay=1.2)
    back(delay=1.0) # Salir del panel admin a dashboard
    
    # 8. Menú de Cultivos (FAB +)
    print("8. Capturando 02_menu_cultivos.png...")
    tap(2172, 957, delay=1.8)
    capture("02_menu_cultivos.png")
    
    # 9. Lirios y Subgrupos
    print("9. Capturando 03_subgrupos_lirios.png...")
    items = dump_ui()
    lirios_btn = find_bounds("Lirios", items)
    if lirios_btn:
        tap(lirios_btn[0], lirios_btn[1], delay=1.5)
    else:
        tap(377, 460, delay=1.5)
    capture("03_subgrupos_lirios.png")
    
    # 10. Formulario Lirio LA
    print("10. Capturando 04_formulario_lirios_parrillas.png...")
    items = dump_ui()
    la_btn = find_bounds("Lirio LA", items)
    if la_btn:
        tap(la_btn[0], la_btn[1], delay=1.8)
    else:
        tap(400, 460, delay=1.8)
    
    items = dump_ui()
    parrillas = find_bounds("PARRILLAS", items) or find_bounds("Parrilla", items)
    if parrillas:
        tap(parrillas[0], parrillas[1], delay=0.8)
        subprocess.run(['adb', 'shell', 'input', 'text', '14'])
        time.sleep(0.8)
        subprocess.run(['adb', 'shell', 'input', 'keyevent', '111'])
        time.sleep(0.8)
    capture("04_formulario_lirios_parrillas.png")
    
    # 11. Canastas Modal
    print("11. Capturando 05_rendimiento_lirios_canastas_modal.png...")
    items = dump_ui()
    can_btn = find_bounds("Canasta", items)
    if can_btn:
        tap(can_btn[0], can_btn[1], delay=2.0)
    else:
        tap(2150, 150, delay=2.0)
    capture("05_rendimiento_lirios_canastas_modal.png")
    
    # 12. Diálogo Canasta Rápida (400, 425, 450)
    print("12. Capturando 16_dialogo_canasta_standard.png...")
    items = dump_ui()
    plus_can = find_bounds("+ Canasta", items) or find_bounds("Canasta", items)
    if plus_can:
        tap(plus_can[0], plus_can[1], delay=1.8)
    else:
        tap(1850, 450, delay=1.8)
    capture("16_dialogo_canasta_standard.png")
    back(delay=1.0)
    back(delay=1.0)
    
    # 13. Formulario Lirios Lotes Compra (scroll abajo)
    print("13. Capturando 06_formulario_lirios_lotes_compra.png...")
    swipe(1200, 900, 1200, 300, duration=400, delay=1.2)
    capture("06_formulario_lirios_lotes_compra.png")
    
    # Volver a menú de selección de cultivo
    back(delay=1.0)
    back(delay=1.0)
    
    # 14. Formulario Cremón Bilateral
    print("14. Capturando 07_formulario_cremon_bilateral.png...")
    items = dump_ui()
    crem_btn = find_bounds("Cremon", items)
    if crem_btn:
        tap(crem_btn[0], crem_btn[1], delay=1.8)
    else:
        tap(1000, 460, delay=1.8)
    capture("07_formulario_cremon_bilateral.png")
    
    # 15. Formulario Cremón Pasó al otro lado
    print("15. Capturando 08_formulario_cremon_paso_otro_lado.png...")
    items = dump_ui()
    paso_btn = find_bounds("Pasó al otro lado", items) or find_bounds("Paso", items)
    if paso_btn:
        tap(paso_btn[0], paso_btn[1], delay=1.5)
    else:
        swipe(1200, 850, 1200, 450, duration=350, delay=1.0)
        items = dump_ui()
        paso_btn = find_bounds("Pasó", items)
        if paso_btn:
            tap(paso_btn[0], paso_btn[1], delay=1.5)
    capture("08_formulario_cremon_paso_otro_lado.png")
    
    # Volver a menú de cultivo
    back(delay=1.0)
    
    # 16. Planta Madre
    print("16. Capturando 09_formulario_areas_especiales_planta_madre.png...")
    items = dump_ui()
    pm_btn = find_bounds("Planta Madre", items)
    if pm_btn:
        tap(pm_btn[0], pm_btn[1], delay=1.8)
    else:
        tap(2130, 762, delay=1.8)
    capture("09_formulario_areas_especiales_planta_madre.png")
    back(delay=1.0)
    back(delay=1.0)
    
    print("=== ¡TODAS LAS 16 CAPTURAS HORIZONTALES FINALIZADAS! ===")

if __name__ == "__main__":
    run_all_captures()

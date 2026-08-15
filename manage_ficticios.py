"""
Script para gestionar registros ficticios de siembra en la base de datos SQLite de la App Movil.
Permite:
  python manage_ficticios.py insertar -> Crea 8 registros ficticios de prueba y sincroniza limites a 2600.
  python manage_ficticios.py eliminar -> Elimina exactamente todos los registros ficticios.
  python manage_ficticios.py listar   -> Muestra los registros ficticios actuales.
"""

import sqlite3
import subprocess
import sys
import uuid

DB_LOCAL = 'siembras_local_temp.db'
PKG_NAME = 'com.example.app_movil'

# Registros ficticios diseñados con variedades, camas y operarios reales
REGISTROS_FICTICIOS = [
    {
        'uuid': 'ficticio-pompon-001',
        'fecha': '04/09/2026',
        'bloque_codigo': '001',
        'cama_id': 1,      # Cama 001 Bloque 001
        'variedad_id': 1262, # ROCK RD - POMPON (CHRYS)
        'operario_id': 5,    # BEATRIZ E. JARAMILLO
        'cantidad': 2450,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 14,
        'lote': 'LOT-FICTICIO-01',
        'proveedor': 'PROPAGADORA EL JARDIN',
        'cont': 'C-101',
        'observaciones': '[FICTICIO] Crisantemo Pompon - Vegetativo día 20/75',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-cremon-002',
        'fecha': '15/08/2026',
        'bloque_codigo': '001',
        'cama_id': 3,      # Cama 002 Bloque 001
        'variedad_id': 1660, # TORNADO RD - DISBUD CREMONS
        'operario_id': 7,    # LINA ISABEL VARGAS
        'cantidad': 2500,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 14,
        'lote': 'LOT-FICTICIO-02',
        'proveedor': 'FLORAL S.A.S',
        'cont': 'C-102',
        'observaciones': '[FICTICIO] Cremon Disbud Uniflor - Boton día 40/75',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-lirios-003',
        'fecha': '10/08/2026',
        'bloque_codigo': '002',
        'cama_id': 125,    # Cama 001 Bloque 002
        'variedad_id': 1637, # EL DIVO BV - LILIUM (LIRIOS)
        'operario_id': 17,   # YESENIA ESCOBAR
        'cantidad': 2200,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 12,
        'lote': 'LOT-FICTICIO-03',
        'proveedor': 'ONINGS HOLLAND',
        'cont': 'CAL-14/16',
        'observaciones': '[FICTICIO] Lirios LA Bulbos importados - Día 45/90',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-girasol-004',
        'fecha': '01/08/2026',
        'bloque_codigo': '003',
        'cama_id': 238,    # Cama 001 Bloque 003
        'variedad_id': 2235, # PROCUT ORANGE - SUNFLOWER
        'operario_id': 19,   # LUIS ANTONIO BRAVO
        'cantidad': 2550,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 16,
        'lote': 'LOT-FICTICIO-04',
        'proveedor': 'SAKATA SEED',
        'cont': 'C-201',
        'observaciones': '[FICTICIO] Girasol exportación - Día 54/65 (Cosecha próxima)',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-matsumoto-005',
        'fecha': '18/09/2026',
        'bloque_codigo': '002',
        'cama_id': 126,    # Cama 002 Bloque 002
        'variedad_id': 1085, # WHITE - MATSUMOTO (ASTER)
        'operario_id': 44,   # MARIA ISABEL ARISTIZABAL
        'cantidad': 2300,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 14,
        'lote': 'LOT-FICTICIO-05',
        'proveedor': 'BALL COLOMBIA',
        'cont': 'C-301',
        'observaciones': '[FICTICIO] Aster Matsumoto enraizamiento - Día 6/70',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-gerbera-006',
        'fecha': '25/06/2026',
        'bloque_codigo': '004',
        'cama_id': 359,    # Cama 001 Bloque 004
        'variedad_id': 1105, # RAVEL - GERBERA
        'operario_id': 5,    # BEATRIZ E. JARAMILLO
        'cantidad': 2400,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': 10,
        'lote': 'LOT-FICTICIO-06',
        'proveedor': 'HILVERDA KOOIJ',
        'cont': 'C-401',
        'observaciones': '[FICTICIO] Gerbera producción continua - Día 91/120',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-finalizada-cumplida-007',
        'fecha': '25/06/2026',
        'bloque_codigo': '001',
        'cama_id': 4,      # Cama 003 Bloque 001
        'variedad_id': 1264, # SALOON RD - POMPON (CHRYS)
        'operario_id': 7,    # LINA ISABEL VARGAS
        'cantidad': 2500,
        'estado': 'FINALIZADA',
        'fecha_fin': '15/09/2026', # 82 días cumplidos > 75 requerido
        'lineas': 14,
        'lote': 'LOT-FICTICIO-07',
        'proveedor': 'PROPAGADORA EL JARDIN',
        'cont': 'C-501',
        'observaciones': '[FICTICIO] Ciclo 100% cumplido y cosechado (Cama LIBRE)',
        'sincronizado': 0,
    },
    {
        'uuid': 'ficticio-finalizada-incompleta-008',
        'fecha': '04/09/2026',
        'bloque_codigo': '001',
        'cama_id': 5,      # Cama 004 Bloque 001
        'variedad_id': 2104, # AMPOSTA - ALSTROEMERIA (ciclo 85 días)
        'operario_id': 17,   # YESENIA ESCOBAR
        'cantidad': 2350,
        'estado': 'FINALIZADA',
        'fecha_fin': '20/09/2026', # 16 días < 85 días
        'lineas': 14,
        'lote': 'LOT-FICTICIO-08',
        'proveedor': 'FLORINCA LTDA',
        'cont': 'C-601',
        'observaciones': '[FICTICIO] Cierre anticipado - Cama protegida (faltan 65 días para nueva siembra)',
        'sincronizado': 0,
    }
]

def obtener_db_desde_emulador():
    """Descarga la base de datos actual del emulador a archivo local"""
    cmd = ['adb', 'exec-out', 'run-as', PKG_NAME, 'cat', 'databases/siembras_local.db']
    res = subprocess.run(cmd, capture_output=True)
    if res.returncode != 0 or len(res.stdout) == 0:
        print(f"Error al obtener db del emulador: {res.stderr.decode('utf-8', errors='ignore')}")
        return False
    with open(DB_LOCAL, 'wb') as f:
        f.write(res.stdout)
    return True

def enviar_db_al_emulador():
    """Envía la base de datos local modificada al emulador y limpia journals"""
    with open(DB_LOCAL, 'rb') as f:
        data = f.read()
    p = subprocess.Popen(
        ['adb', 'exec-in', 'run-as', PKG_NAME, 'sh', '-c', 'cat > databases/siembras_local.db'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    out, err = p.communicate(input=data)
    if p.returncode != 0:
        print(f"Error al enviar db: {err.decode('utf-8', errors='ignore')}")
        return False
    # Limpiar posibles archivos temporales de SQLite
    subprocess.run([
        'adb', 'shell',
        f'run-as {PKG_NAME} rm -f databases/siembras_local.db-journal databases/siembras_local.db-wal databases/siembras_local.db-shm'
    ], capture_output=True)
    return True

def insertar_ficticios():
    if not obtener_db_desde_emulador():
        return
    
    conn = sqlite3.connect(DB_LOCAL)
    c = conn.cursor()

    # 1. Asegurar sanitización de límites en tb_config_agronomica a 2600
    configs = [
        ('GENERAL', 2600, 75),
        ('POMPON', 2600, 75),
        ('CREMON', 2600, 75),
        ('LIRIOS', 2600, 90),
        ('LA', 2600, 90),
        ('LO', 2600, 90),
        ('OT', 2600, 90),
        ('MATSUMOTO', 2600, 70),
        ('GERBERA', 2500, 120),
        ('GIRASOL', 2600, 65),
        ('ALSTROEMERIA', 2600, 85),
    ]
    for cult, lim, cic in configs:
        c.execute("""
            INSERT INTO tb_config_agronomica (cultivo, limite_esquejes, dias_ciclo)
            VALUES (?, ?, ?)
            ON CONFLICT(cultivo) DO UPDATE SET limite_esquejes = excluded.limite_esquejes, dias_ciclo = excluded.dias_ciclo
        """, (cult, lim, cic))

    c.execute("UPDATE tb_config_agronomica SET limite_esquejes = 2600 WHERE limite_esquejes > 2600 AND cultivo != 'BANCOS'")
    c.execute("UPDATE tb_variedades SET limite_esquejes = 2600 WHERE limite_esquejes > 2600")

    # 2. Borrar primero cualquier registro ficticio previo para no duplicar
    c.execute("DELETE FROM tb_siembras WHERE lote LIKE 'LOT-FICTICIO%' OR observaciones LIKE '%[FICTICIO]%'")

    # 3. Insertar los registros ficticios
    insertados = 0
    for r in REGISTROS_FICTICIOS:
        c.execute("""
            INSERT INTO tb_siembras (
                uuid, fecha, bloque_codigo, cama_id, variedad_id, operario_id,
                cantidad, estado, fecha_fin, lineas, lote, proveedor, cont, observaciones, sincronizado
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            r['uuid'], r['fecha'], r['bloque_codigo'], r['cama_id'], r['variedad_id'], r['operario_id'],
            r['cantidad'], r['estado'], r['fecha_fin'], r['lineas'], r['lote'], r['proveedor'], r['cont'],
            r['observaciones'], r['sincronizado']
        ))
        insertados += 1

    conn.commit()
    conn.close()

    if enviar_db_al_emulador():
        print(f"EXITO: Se insertaron {insertados} registros ficticios de prueba en la base de datos.")
        listar_ficticios()

def eliminar_ficticios():
    if not obtener_db_desde_emulador():
        return
    
    conn = sqlite3.connect(DB_LOCAL)
    c = conn.cursor()

    count_before = c.execute("SELECT COUNT(*) FROM tb_siembras WHERE lote LIKE 'LOT-FICTICIO%' OR observaciones LIKE '%[FICTICIO]%'").fetchone()[0]
    c.execute("DELETE FROM tb_siembras WHERE lote LIKE 'LOT-FICTICIO%' OR observaciones LIKE '%[FICTICIO]%'")
    conn.commit()
    conn.close()

    if enviar_db_al_emulador():
        print(f"EXITO: Se eliminaron {count_before} registros ficticios de la base de datos.")

def listar_ficticios():
    if not obtener_db_desde_emulador():
        return
    
    conn = sqlite3.connect(DB_LOCAL)
    c = conn.cursor()

    rows = c.execute("""
        SELECT s.id_local, s.fecha, s.bloque_codigo, c.cama, v.nombre, s.cantidad, s.estado, s.observaciones
        FROM tb_siembras s
        LEFT JOIN tb_camas c ON s.cama_id = c.id
        LEFT JOIN tb_variedades v ON s.variedad_id = v.id
        WHERE s.lote LIKE 'LOT-FICTICIO%' OR s.observaciones LIKE '%[FICTICIO]%'
        ORDER BY s.id_local ASC
    """).fetchall()

    conn.close()

    print(f"\n--- REGISTROS FICTICIOS EN BASE DE DATOS ({len(rows)}) ---")
    for r in rows:
        print(f"ID #{r[0]} | Fecha: {r[1]} | Bloque: {r[2]} Cama: {r[3]} | Variedad: {r[4]} | Cant: {r[5]} | Estado: {r[6]} | {r[7]}")
    print("----------------------------------------------------------\n")

if __name__ == '__main__':
    accion = sys.argv[1] if len(sys.argv) > 1 else 'insertar'
    if accion == 'insertar':
        insertar_ficticios()
    elif accion == 'eliminar':
        eliminar_ficticios()
    elif accion == 'listar':
        listar_ficticios()
    else:
        print("Uso: python manage_ficticios.py [insertar | eliminar | listar]")

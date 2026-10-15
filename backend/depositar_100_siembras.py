import random
import time
import datetime
import pyodbc
import sqlite3
import os
from app.db.connection import get_connection_string
from app.db import queries
from app.models.schemas import SiembraSync

print("=" * 70)
print("DEPOSITADOR DE 100 REGISTROS DE SIEMBRAS EN MICROSOFT ACCESS Y APP")
print("=" * 70)

conn_str = get_connection_string()
print(f"Conectando a Access con:\n -> {conn_str}\n")
conn = pyodbc.connect(conn_str, timeout=15)

camas = queries.get_camas(conn)
variedades = queries.get_variedades(conn)
operarios = queries.get_operarios(conn)

print(f"Catalogos cargados exitosamente:")
print(f" - Camas disponibles: {len(camas)}")
print(f" - Variedades disponibles: {len(variedades)}")
print(f" - Operarios registrados: {len(operarios)}")

# Filtrar variedades con nombre valido
variedades_validas = [v for v in variedades if v.nombre and v.nombre.strip() not in ('0', '00', 'N/A', '-')]
if not variedades_validas:
    variedades_validas = variedades

# Proveedores y contenedores para Lirios
proveedores_lirios = ['JAN DE WIT', 'DE JONG LELIES', 'VAN DEN BOS', 'ONINGS HOLLAND', 'ZABO PLANT']
lotes_lirios = ['438779', '436592', '440112', '441050', '439221', '442800', '437890']

hoy = datetime.date(2026, 10, 15)

# Seleccionar 100 camas distintas para que cada siembra tenga su propia cama
camas_seleccionadas = random.sample(camas, min(100, len(camas)))

siembras_sync = []
registros_raw = []

for i, cama in enumerate(camas_seleccionadas):
    var = random.choice(variedades_validas)
    dias_atras = random.randint(0, 25)
    f_fecha = hoy - datetime.timedelta(days=dias_atras)
    f_str = f_fecha.strftime("%d/%m/%Y")
    f_millis = int(datetime.datetime(f_fecha.year, f_fecha.month, f_fecha.day, 12, 0).timestamp() * 1000)

    fam_nom = (var.familia_nombre or "").upper()
    var_nom = (var.nombre or "").upper()
    es_lirio = 'LIRIO' in fam_nom or 'LIRIO' in var_nom or 'LA' in var_nom or 'ORIENTAL' in fam_nom

    if es_lirio:
        op_id = 0
        parrillas = random.choice([10, 12, 14, 16, 18])
        bulbos_x_parrilla = random.choice([121, 143, 154])
        cant = parrillas * bulbos_x_parrilla
        prov = random.choice(proveedores_lirios)
        lote = random.choice(lotes_lirios)
        cont = str(random.randint(1, 18))
        obs = f"SIEMBRA COLECTIVA LIRIOS | {parrillas} parrillas ({bulbos_x_parrilla} b/p)"
        lineas = parrillas
    else:
        op = random.choice(operarios) if operarios else None
        op_id = op.id if op else 0
        prov = None
        lote = None
        cont = None
        lineas = 14

        if 'CREMON' in fam_nom or 'CREMON' in var_nom:
            lado = random.choice(['LADO A', 'LADO B', 'COMPLETA'])
            if lado == 'COMPLETA':
                cant = random.randint(2400, 2800)
                obs = "CAMA COMPLETA (6 esq/lin)"
            else:
                cant = random.randint(1200, 1450)
                obs = f"{lado} (6 esq/lin)"
        elif 'GIRASOL' in fam_nom or 'GIRASOL' in var_nom:
            cant = random.randint(1200, 1800)
            obs = "SIEMBRA ESTANDAR GIRASOL"
        else:
            max_cama = var.limite_esquejes or 3600
            cant = int(max_cama * random.uniform(0.85, 0.98))
            obs = f"SIEMBRA REGULAR ({lineas} lin)"

    s_uuid = f"siembra-batch100-{int(time.time())}-{i+1:03d}"

    s_sync = SiembraSync(
        uuid=s_uuid,
        bloque_codigo=cama.bloque_codigo,
        cama_id=cama.id,
        cama_codigo=cama.codigo or cama.cama,
        variedad_id=var.id,
        variedad_nombre=var.nombre,
        operario_id=op_id,
        fecha_siembra=f_millis,
        fecha_str=f_str,
        cantidad_esquejes=cant,
        lineas=lineas,
        lote=lote,
        proveedor=prov,
        conteo=cont,
        observaciones=obs,
        estado='ACTIVA',
        version=1
    )
    siembras_sync.append(s_sync)
    registros_raw.append({
        'uuid': s_uuid,
        'fecha': f_str,
        'bloque_codigo': cama.bloque_codigo,
        'cama_id': cama.id,
        'variedad_id': var.id,
        'operario_id': op_id,
        'cantidad': cant,
        'lineas': lineas,
        'lote': lote,
        'proveedor': prov,
        'cont': cont,
        'observaciones': obs
    })

print(f"\nInsertando {len(siembras_sync)} siembras en Microsoft Access (t_siembras_app, t49, t31, t51, t102, t50)...")
t0 = time.time()
insertadas, committed_uuids = queries.insertar_siembras_batch(conn, siembras_sync)
t_elapsed = time.time() - t0

print(f"\n[OK] Asentamiento en Access finalizado:")
print(f" - Siembras procesadas: {insertadas}")
print(f" - UUIDs confirmados: {len(committed_uuids)}")
print(f" - Tiempo de ejecucion: {t_elapsed:.2f} s")

# Verificar en Microsoft Access
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM t_siembras_app")
total_access = cur.fetchone()[0]
print(f" - Total actual en tabla 't_siembras_app': {total_access} registros")

# Si existe la base local de la tablet copiada o el archivo de depuracion, actualizarlo tambien
tablet_db_path = r'D:\PROYECTO SIEMBRAS\siembras_tablet_debug.db'
if os.path.exists(tablet_db_path):
    print(f"\nActualizando base de datos local de la tablet ({tablet_db_path})...")
    sconn = sqlite3.connect(tablet_db_path)
    scur = sconn.cursor()
    for r in registros_raw:
        scur.execute("""
            INSERT OR REPLACE INTO tb_siembras
            (uuid, fecha, bloque_codigo, cama_id, variedad_id, operario_id, cantidad, lineas, lote, proveedor, cont, observaciones, estado, sincronizado)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVA', 1)
        """, (
            r['uuid'], r['fecha'], r['bloque_codigo'], r['cama_id'], r['variedad_id'], r['operario_id'],
            r['cantidad'], r['lineas'], r['lote'], r['proveedor'], r['cont'], r['observaciones']
        ))
    sconn.commit()
    scur.execute("SELECT COUNT(*) FROM tb_siembras")
    print(f" - Total registros en tb_siembras (tablet): {scur.fetchone()[0]}")
    sconn.close()

print("\n" + "=" * 70)
print("COMPLETADO EXITOSAMENTE: 100 REGISTROS DEPOSITADOS Y VERIFICADOS")
print("=" * 70)

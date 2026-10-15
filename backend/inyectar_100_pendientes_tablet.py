import sqlite3
import random
import time
import datetime
import json
import pyodbc
from app.db.connection import get_connection_string
from app.db import queries

print("=" * 70)
print("GENERANDO 100 SIEMBRAS PENDIENTES DIRECTAMENTE EN LA TABLET")
print("=" * 70)

# 1. Cargar catalogos reales desde Access
conn = pyodbc.connect(get_connection_string(), timeout=15)
camas = queries.get_camas(conn)
variedades = queries.get_variedades(conn)
operarios = queries.get_operarios(conn)

print(f"Catalogos cargados:")
print(f" - Camas disponibles: {len(camas)}")
print(f" - Variedades disponibles: {len(variedades)}")
print(f" - Operarios registrados: {len(operarios)}")

variedades_validas = [v for v in variedades if v.nombre and v.nombre.strip() not in ('0', '00', 'N/A', '-')]
if not variedades_validas:
    variedades_validas = variedades

proveedores_lirios = ['JAN DE WIT', 'DE JONG LELIES', 'VAN DEN BOS', 'ONINGS HOLLAND', 'ZABO PLANT']
lotes_lirios = ['438779', '436592', '440112', '441050', '439221', '442800', '437890']

hoy = datetime.date(2026, 10, 15)

# 2. Conectar a la base de datos de la tablet (d:\PROYECTO SIEMBRAS\tablet_siembras_local.db)
tablet_db_path = r'd:\PROYECTO SIEMBRAS\tablet_siembras_local.db'
json_backup_path = r'd:\PROYECTO SIEMBRAS\siembras_respaldo_persistente.json'

sconn = sqlite3.connect(tablet_db_path)
scur = sconn.cursor()

# Ver camas ya ocupadas localmente para no repetir
scur.execute("SELECT cama_id FROM tb_siembras WHERE estado = 'ACTIVA'")
camas_ocupadas = {r[0] for r in scur.fetchall()}

camas_disponibles = [c for c in camas if c.id not in camas_ocupadas]
if len(camas_disponibles) < 100:
    camas_disponibles = camas

camas_seleccionadas = random.sample(camas_disponibles, 100)

ts_base = int(time.time() * 1000)
nuevas_siembras = []

for i, cama in enumerate(camas_seleccionadas):
    var = random.choice(variedades_validas)
    dias_atras = random.randint(0, 15)
    f_fecha = hoy - datetime.timedelta(days=dias_atras)
    f_str = f_fecha.strftime("%d/%m/%Y")

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

    s_uuid = f"siembra-pend-{ts_base}-{i+1:03d}"

    scur.execute("""
        INSERT INTO tb_siembras 
        (uuid, fecha, bloque_codigo, variedad_id, cama_id, operario_id, cantidad, estado, fecha_fin, lineas, observaciones, corte, lote, proveedor, cont, sincronizado)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVA', NULL, ?, ?, NULL, ?, ?, ?, 0)
    """, (
        s_uuid, f_str, cama.bloque_codigo, var.id, cama.id, op_id, cant, lineas, obs, lote, prov, cont
    ))

    nuevas_siembras.append({
        'uuid': s_uuid,
        'fecha': f_str,
        'bloque_codigo': cama.bloque_codigo,
        'variedad_id': var.id,
        'cama_id': cama.id,
        'operario_id': op_id,
        'cantidad': cant,
        'estado': 'ACTIVA',
        'fecha_fin': None,
        'lineas': lineas,
        'observaciones': obs,
        'corte': None,
        'lote': lote,
        'proveedor': prov,
        'cont': cont,
        'sincronizado': 0
    })

sconn.commit()

# Consultar totales en la base de la tablet
scur.execute("SELECT COUNT(*), SUM(CASE WHEN sincronizado = 0 THEN 1 ELSE 0 END) FROM tb_siembras")
total_rows, total_pendientes = scur.fetchone()
print(f"\nBase local actualizada:")
print(f" - Total registros en tb_siembras: {total_rows}")
print(f" - Registros PENDIENTES DE SINCRONIZAR (sincronizado = 0): {total_pendientes}")

# Checkpoint para asegurar un solo archivo SQLite solido
scur.execute("PRAGMA wal_checkpoint(FULL);")
scur.execute("VACUUM;")
sconn.close()

# 3. Exportar tambien a JSON para el respaldo persistente en espejo
# Cargar siembras existentes y agregar las nuevas
with sqlite3.connect(tablet_db_path) as conn_all:
    conn_all.row_factory = sqlite3.Row
    c_all = conn_all.cursor()
    c_all.execute("SELECT * FROM tb_siembras")
    all_siembras = [dict(row) for row in c_all.fetchall()]

with open(json_backup_path, 'w', encoding='utf-8') as f_json:
    json.dump(all_siembras, f_json, ensure_ascii=False, indent=2)

print(f" - Respaldo persistente generado con {len(all_siembras)} siembras.")
print("=" * 70)

import sqlite3
import pyodbc
from app.db.connection import get_connection_string

sqlite_path = r'D:\PROYECTO SIEMBRAS\siembras_tablet_debug.db'
sqlite_conn = sqlite3.connect(sqlite_path)
cur = sqlite_conn.cursor()

cur.execute("SELECT id_local, uuid, fecha, bloque_codigo, cama_id, variedad_id, cantidad, sincronizado FROM tb_siembras")
tablet_siembras = cur.fetchall()

access_conn = pyodbc.connect(get_connection_string(), timeout=10)
acur = access_conn.cursor()
acur.execute("SELECT uuid FROM t_siembras_app")
access_uuids = set(r[0] for r in acur.fetchall())

print(f"Total siembras in tablet: {len(tablet_siembras)}")
print(f"Total siembras in Access: {len(access_uuids)}")

missing_in_access = []
for s in tablet_siembras:
    uuid = s[1]
    if uuid not in access_uuids:
        missing_in_access.append(s)

print(f"\nSiembras in Tablet MISSING from Access: {len(missing_in_access)}")
for m in missing_in_access:
    print("MISSING:", m)

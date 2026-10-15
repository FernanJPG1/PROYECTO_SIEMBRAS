import sqlite3
import pyodbc
import os
from app.db.connection import get_connection_string

print("=== TABLET LOCAL SQLITE ===")
sqlite_path = r'D:\PROYECTO SIEMBRAS\siembras_tablet_debug.db'
sqlite_conn = sqlite3.connect(sqlite_path)
cur = sqlite_conn.cursor()

# Get all table names
cur.execute("SELECT tbl_name, sql FROM sqlite_master WHERE type='table'")
tables = cur.fetchall()
for tname, tsql in tables:
    print(f"Table: {tname}")
    print(f"SQL: {tsql}\n")

cur.execute("SELECT * FROM tb_siembras ORDER BY rowid DESC LIMIT 5")
rows = cur.fetchall()
cur.execute("PRAGMA table_info(tb_siembras)")
cols = [c[1] for c in cur.fetchall()]
for r in rows:
    print("Tablet row:", dict(zip(cols, r)))

print("\n=== ENTERPRISE ACCESS DB (Z:) ===")
access_conn = pyodbc.connect(get_connection_string(), timeout=10)
acur = access_conn.cursor()
acur.execute("SELECT TOP 5 uuid, fecha_siembra, variedad_id, bloque_codigo, cama_codigo, estado FROM t_siembras_app ORDER BY fecha_siembra DESC")
for r in acur.fetchall():
    print("Access row:", r)

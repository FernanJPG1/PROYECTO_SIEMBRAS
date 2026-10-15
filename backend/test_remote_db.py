import os
import sys
import time
import pyodbc
from pathlib import Path
from dotenv import load_dotenv

# Asegurar codificación utf-8 en Windows terminal
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

load_dotenv()

def probar_conexion(ruta_bd: str = None):
    print("=" * 70)
    print("[DIAGNOSTICO] HERRAMIENTA DE PRUEBA DE BASE DE DATOS ACCESS")
    print("=" * 70)

    if not ruta_bd:
        ruta_bd = os.getenv("ACCESS_DB_PATH", r"D:\PROYECTO SIEMBRAS\bmempresarial2021.accdb")

    ruta_bd = ruta_bd.strip(' "\'')
    print(f"\n[1] Analizando ruta objetivo:")
    print(f"    -> Ruta configurada: {ruta_bd}")

    # 1. Comprobar existencia del archivo
    t0 = time.time()
    existe = os.path.exists(ruta_bd)
    t_check = (time.time() - t0) * 1000

    if not existe:
        print(f"\n[ERROR] No se puede acceder a la ruta o el archivo no existe.")
        print(f"   Tiempo de respuesta: {t_check:.1f} ms")
        print("\nPosibles causas:")
        print(" - La VPN no esta conectada o la IP remota no responde.")
        print(" - La carpeta compartida requiere credenciales de Windows.")
        print(" - La ruta esta mal escrita o la letra de unidad (ej: Z:) no esta montada.")
        return False

    tam_mb = os.path.getsize(ruta_bd) / (1024 * 1024)
    print(f"    [OK] Archivo localizado exitosamente ({tam_mb:.1f} MB)")
    print(f"    [OK] Latencia de acceso al sistema de archivos: {t_check:.1f} ms")

    # 2. Comprobar permisos de escritura (Esencial para Access y el archivo .laccdb)
    carpeta = os.path.dirname(os.path.abspath(ruta_bd)) if not ruta_bd.startswith(r"\\") else os.path.dirname(ruta_bd)
    print(f"\n[2] Verificando permisos de escritura en la carpeta ({carpeta}):")
    archivo_prueba = os.path.join(carpeta, "__test_permiso_escritura.tmp")
    try:
        with open(archivo_prueba, "w") as f:
            f.write("test")
        os.remove(archivo_prueba)
        print("    [OK] Permiso de ESCRITURA confirmado (Access podra generar el candado .laccdb)")
    except Exception as e:
        print(f"    [AVISO] No se pudo escribir en la carpeta: {e}")
        print("    Nota: Microsoft Access requiere permisos de lectura y escritura para operar.")

    # 3. Comprobar Driver ODBC
    print("\n[3] Verificando controladores ODBC instalados:")
    drivers = [d for d in pyodbc.drivers() if "Access" in d]
    if not drivers:
        print("    [ERROR] No esta instalado el controlador 'Microsoft Access Driver (*.mdb, *.accdb)'")
        return False
    print(f"    [OK] Driver disponible: {drivers[0]}")

    # 4. Probar Conexión ODBC
    print("\n[4] Iniciando prueba de conexion ODBC...")
    conn_str = (
        f"DRIVER={{Microsoft Access Driver (*.mdb, *.accdb)}};"
        f"DBQ={ruta_bd};"
        f"Exclusive=0;"
        f"ExtendedAnsiSQL=1;"
    )

    try:
        t_inicio_conn = time.time()
        conn = pyodbc.connect(conn_str, timeout=15)
        t_conn = (time.time() - t_inicio_conn) * 1000
        print(f"    [OK] Conexion establecida con exito en {t_conn:.1f} ms")

        # 5. Ejecutar consultas de prueba y medir velocidad
        print("\n[5] Midiendo rendimiento de consultas:")
        cursor = conn.cursor()

        # Listar tablas
        t_inicio_tablas = time.time()
        tablas = [row.table_name for row in cursor.tables(tableType='TABLE')]
        t_tablas = (time.time() - t_inicio_tablas) * 1000
        print(f"    [OK] Inspeccion de catalogo de tablas ({len(tablas)} tablas encontradas): {t_tablas:.1f} ms")

        # Contar registros en una tabla típica
        tablas_a_probar = ['t17_mbloques', 't159_moperarios', 't_siembras_app']
        for tbl in tablas_a_probar:
            if any(t.lower() == tbl.lower() for t in tablas):
                t_inicio_q = time.time()
                cursor.execute(f"SELECT COUNT(*) FROM [{tbl}]")
                total = cursor.fetchone()[0]
                t_q = (time.time() - t_inicio_q) * 1000
                print(f"    [OK] Conteo en [{tbl}]: {total} registros en {t_q:.1f} ms")

        conn.close()
        print("\n" + "=" * 70)
        print("RESULTADO: LA CONEXION ES TOTALMENTE VIABLE Y FUNCIONAL")
        if t_conn > 2000:
            print("[AVISO DE VELOCIDAD] La conexion tardo mas de 2 segundos.")
            print("   Se recomienda mantener conexiones estables o evaluar enlaces de baja latencia.")
        else:
            print(f"[VELOCIDAD OPTIMA] Tiempo de conexion {t_conn:.1f} ms")
        print("=" * 70)
        return True

    except Exception as e:
        print(f"\n[ERROR] conectando por ODBC:")
        print(f"   Detalle: {e}")
        return False

if __name__ == "__main__":
    ruta = sys.argv[1] if len(sys.argv) > 1 else None
    probar_conexion(ruta)

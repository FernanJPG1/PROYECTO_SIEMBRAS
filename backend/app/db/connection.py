# ============================================================================
# ARCHIVO: backend/app/db/connection.py
# ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
# Imagínate que este archivo es EL GUARDIÁN Y PORTERO DE LA BASE DE DATOS EMPRESARIAL.
#
# En el computador de la oficina o servidor remoto vive el archivo de Microsoft Access
# con todas las cuentas de la finca. Si varias personas intentan modificarlo al mismo
# tiempo de forma desordenada, el archivo se podría dañar.
#
# Este archivo realiza 4 labores de protección:
# 1. EL MODO COMPARTIDO (Exclusive=0):
#    Abre el archivo permitiendo que los usuarios de oficina lo tengan abierto
#    mientras los celulares mandan datos por VPN, sin que nadie se estorbe.
#
# 2. EL TORNIQUETE DE SEGURIDAD (db_lock):
#    Si varios supervisores sincronizan en el mismo segundo, el portero los atiende
#    en fila ordenada (un hilo a la vez) para máxima estabilidad.
#
# 3. REUTILIZACIÓN DE CONEXIÓN DE ALTA VELOCIDAD:
#    Mantiene el canal ODBC caliente para que las consultas por VPN respondan
#    en apenas 200 ms en lugar de renegociar 6 segundos en cada petición.
#
# 4. AUTO-ENLACE DE UNIDAD DE RED:
#    Si la unidad Z: no está montada tras reiniciar Windows, la reconecta automáticamente.
# ============================================================================

import pyodbc
import threading
from typing import Generator, Optional
import logging
import os
import shutil
from pathlib import Path
from datetime import datetime
from app.core.config import settings

logger = logging.getLogger(__name__)

# Torniquete de seguridad: atiende una petición a la vez para no dañar Access
db_lock = threading.Lock()

# Caché de conexión persistente y verificación de esquema
_cached_conn: Optional[pyodbc.Connection] = None
_schema_verified: bool = False

REMOTE_UNC_SHARE = r"\\192.168.1.4\Users2\vortiz\Desktop\BD practica"
LOCAL_FALLBACK_DB = r"D:\PROYECTO SIEMBRAS\bmempresarial2021.accdb"

def verify_and_ensure_drive():
    """
    Verifica si la ruta de la base de datos es accesible.
    Si apunta a Z: y la unidad se desconectó, intenta re-montarla de forma rápida y no bloqueante.
    """
    db_path = settings.ACCESS_DB_PATH.strip(' "\'')
    try:
        if os.path.exists(db_path):
            return
    except Exception:
        pass

    if db_path.upper().startswith("Z:"):
        # Comprobación de socket de 800 ms para saber si el host remoto responde antes de llamar net use
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.8)
            res = sock.connect_ex(('192.168.1.4', 445))
            sock.close()
            if res == 0:
                logger.info(f"Unidad Z: no detectada pero host accesible. Montando con {REMOTE_UNC_SHARE}...")
                os.system(f'net use Z: "{REMOTE_UNC_SHARE}" /persistent:yes >nul 2>&1')
            else:
                logger.debug("Host remoto 192.168.1.4 inaccesible (VPN desconectada). Omitiendo net use.")
        except Exception as e:
            logger.debug(f"Aviso comprobando host remoto: {e}")

def get_connection_string() -> str:
    """
    Construye la llave de conexión para abrir Microsoft Access de forma compartida y segura.
    Incluye fallback automático a la base de datos local en disco si la remota no está disponible.
    """
    verify_and_ensure_drive()
    db_path = settings.ACCESS_DB_PATH.strip(' "\'')

    final_path = ""
    if db_path.startswith(r"\\") or db_path.startswith("//"):
        final_path = db_path.replace("/", "\\")
    elif ":" in db_path:
        # Si la unidad Z: no existe en el momento, intentar fallback al UNC remoto
        if db_path.upper().startswith("Z:") and not os.path.exists(db_path):
            fallback_unc = os.path.join(REMOTE_UNC_SHARE, os.path.basename(db_path))
            try:
                if os.path.exists(fallback_unc):
                    logger.info(f"Usando ruta UNC de respaldo: {fallback_unc}")
                    return (
                        f"DRIVER={{Microsoft Access Driver (*.mdb, *.accdb)}};"
                        f"DBQ={fallback_unc};"
                        f"Exclusive=0;"
                        f"ExtendedAnsiSQL=1;"
                    )
            except Exception:
                pass
        final_path = os.path.abspath(db_path)
    else:
        final_path = os.path.abspath(os.path.join(os.getcwd(), db_path))

    # Fallback transparente a base de datos local si la ruta configurada no existe
    if not os.path.exists(final_path) and os.path.exists(LOCAL_FALLBACK_DB):
        logger.info(f"Ruta remota ({final_path}) no accesible sin VPN. Usando base de datos empresarial local: {LOCAL_FALLBACK_DB}")
        final_path = LOCAL_FALLBACK_DB

    return (
        f"DRIVER={{Microsoft Access Driver (*.mdb, *.accdb)}};"
        f"DBQ={final_path};"
        f"Exclusive=0;"
        f"ExtendedAnsiSQL=1;"
    )

def safe_backup_database():
    """
    Genera un respaldo preventivo de la base de datos en segundo plano (asíncrono).
    En entornos VPN se recomienda AUTO_BACKUP_ON_SYNC=false para evitar transferir 825 MB por red.
    """
    if not settings.AUTO_BACKUP_ON_SYNC:
        return

    def _async_backup():
        try:
            db_path = settings.ACCESS_DB_PATH.strip(' "\'')
            if not os.path.exists(db_path):
                return

            db_dir = os.path.dirname(os.path.abspath(db_path))
            backup_dir = os.path.join(db_dir, "backups_seguridad")
            os.makedirs(backup_dir, exist_ok=True)

            hora_actual = datetime.now().strftime("%Y%m%d_%H")
            stem = os.path.splitext(os.path.basename(db_path))[0]
            backup_name = f"{stem}_backup_{hora_actual}.accdb"
            backup_path = os.path.join(backup_dir, backup_name)

            if not os.path.exists(backup_path):
                shutil.copy2(db_path, backup_path)
                logger.info(f"✓ Respaldo de seguridad creado: {backup_path}")

                backups = [os.path.join(backup_dir, f) for f in os.listdir(backup_dir) if f.endswith(".accdb")]
                backups.sort(key=os.path.getmtime, reverse=True)
                for old in backups[5:]:
                    try:
                        os.remove(old)
                    except Exception:
                        pass
        except Exception as e:
            logger.warning(f"Aviso: no se pudo generar copia de respaldo automática: {e}")

    threading.Thread(target=_async_backup, daemon=True, name="DB-Backup-Worker").start()

def ensure_database_schema(conn: pyodbc.Connection):
    """
    Garantiza que la base de datos cuente con la tabla 't_siembras_app'
    indispensable para el registro y auditoría móvil de siembras.
    Se ejecuta una sola vez al inicio para no añadir latencia a cada consulta.
    """
    global _schema_verified
    if _schema_verified:
        return

    try:
        cursor = conn.cursor()
        tables = [row.table_name.lower() for row in cursor.tables(tableType='TABLE')]
        
        if 't_siembras_app' not in tables:
            logger.info("Detectada nueva base de datos sin tabla 't_siembras_app'. Inicializando...")
            cursor.execute("""
                CREATE TABLE t_siembras_app (
                    uuid VARCHAR(100) PRIMARY KEY,
                    fecha_siembra DATETIME,
                    fecha_fin DATETIME,
                    bloque_codigo VARCHAR(50),
                    cama_id INTEGER,
                    cama_codigo VARCHAR(50),
                    variedad_id INTEGER,
                    operario_id INTEGER,
                    cantidad_esquejes INTEGER,
                    lineas INTEGER,
                    lote VARCHAR(100),
                    proveedor VARCHAR(100),
                    conteo VARCHAR(100),
                    observaciones LONGCHAR,
                    estado VARCHAR(50)
                )
            """)
            conn.commit()
            logger.info("✓ Tabla 't_siembras_app' creada exitosamente.")
        _schema_verified = True
    except Exception as e:
        logger.error(f"Error verificando o creando esquema en la base de datos: {e}")

def invalidate_connection():
    """
    Cierra forzosamente la conexión en caché y la descarta.
    Esencial cuando el enlace de red SMB / VPN se interrumpió y el handle quedó stale.
    """
    global _cached_conn
    if _cached_conn is not None:
        try:
            _cached_conn.close()
        except Exception:
            pass
        _cached_conn = None

def get_or_create_connection() -> pyodbc.Connection:
    """
    Mantiene una conexión ODBC caliente para que las consultas por VPN sean instantáneas (200 ms).
    Si la conexión se corta por inactividad de red o VPN, la reconecta de forma transparente.
    Prueba con una tabla física real (t17_mbloques) para asegurar que el descriptor de archivo no esté huérfano.
    """
    global _cached_conn

    # 1. Comprobar si la conexión existente sigue viva consultando una tabla física real
    if _cached_conn is not None:
        try:
            cursor = _cached_conn.cursor()
            cursor.execute("SELECT TOP 1 t17_codigo FROM t17_mbloques")
            cursor.fetchone()
            return _cached_conn
        except Exception as ex_ping:
            logger.warning(f"Aviso: Conexión previa a Access inválida o desconectada de red ({ex_ping}). Reconectando...")
            invalidate_connection()

    # 2. Conectar de forma limpia
    conn_str = get_connection_string()
    logger.info(f"Estableciendo enlace ODBC con Microsoft Access...")
    _cached_conn = pyodbc.connect(conn_str, timeout=15)
    ensure_database_schema(_cached_conn)
    return _cached_conn

def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    Inyector de dependencias para FastAPI.
    Entrega la conexión protegida por el torniquete (db_lock) y la mantiene caliente.
    """
    global _cached_conn
    db_lock.acquire()
    conn = None
    try:
        conn = get_or_create_connection()
        yield conn
    except Exception as e:
        logger.error(f"Error en sesión con la base de datos: {e}")
        # Descartar conexión dañada si hubo error
        invalidate_connection()
        raise
    finally:
        # Mantenemos la conexión activa en caché para la próxima petición
        db_lock.release()

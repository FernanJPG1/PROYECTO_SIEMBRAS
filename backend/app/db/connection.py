import pyodbc
import threading
from typing import Generator
import logging
import os
import shutil
from pathlib import Path
from datetime import datetime
from app.core.config import settings

logger = logging.getLogger(__name__)

# Access DB is not designed for heavy concurrent usage. 
# We use a global lock to serialize all database operations across requests.
db_lock = threading.Lock()

def get_connection_string() -> str:
    """
    Construye la cadena de conexión optimizada para Microsoft Access.
    - Exclusive=0: Garantiza que la BD se abra en modo COMPARTIDO (multi-usuario y red).
      Esto evita que la BD se dañe o se bloquee si está en un servidor local o si
      otro usuario la tiene abierta en Microsoft Access.
    - ExtendedAnsiSQL=1: Permite compatibilidad ANSI SQL estándar.
    """
    db_path = settings.ACCESS_DB_PATH.strip(' "\'')
    if db_path.startswith(r"\\") or db_path.startswith("//"):
        final_path = db_path.replace("/", "\\")
    elif ":" in db_path:
        final_path = os.path.abspath(db_path)
    else:
        final_path = os.path.abspath(os.path.join(os.getcwd(), db_path))

    return (
        f"DRIVER={{Microsoft Access Driver (*.mdb, *.accdb)}};"
        f"DBQ={final_path};"
        f"Exclusive=0;"
        f"ExtendedAnsiSQL=1;"
    )

def safe_backup_database():
    """
    Genera un respaldo preventivo de la base de datos en segundo plano (asíncrono).
    Protege la base de datos empresarial de cualquier daño o corrupción si se cambia
    o si reside en un servidor local compartido, sin bloquear la sincronización ni causar timeouts.
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

            # Solo generar si no existe respaldo para esta hora
            if not os.path.exists(backup_path):
                shutil.copy2(db_path, backup_path)
                logger.info(f"✓ Respaldo de seguridad creado: {backup_path}")

                # Mantener solo los últimos 5 backups para ahorrar espacio en disco
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
    Si la base de datos se cambia por una nueva desde un servidor local que no
    cuenta con esta tabla, se crea automáticamente SIN alterar ninguna tabla existente.
    """
    try:
        cursor = conn.cursor()
        tables = [row.table_name.lower() for row in cursor.tables(tableType='TABLE')]
        
        if 't_siembras_app' not in tables:
            logger.info("Detectada nueva base de datos sin tabla 't_siembras_app'. Inicializando de forma segura...")
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
            logger.info("✓ Tabla 't_siembras_app' creada exitosamente en la base de datos.")
    except Exception as e:
        logger.error(f"Error verificando o creando esquema en la base de datos: {e}")

def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    Dependency to get a database connection.
    Yields the connection while holding the global lock.
    """
    conn_str = get_connection_string()
    
    # Acquire the lock before opening the connection
    logger.debug("Esperando lock de la base de datos...")
    db_lock.acquire()
    logger.debug("Lock adquirido. Conectando a MS Access...")
    
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        # Asegurar esquema al conectarse (por si se cambió la base de datos)
        ensure_database_schema(conn)
        yield conn
    except Exception as e:
        logger.error(f"Error conectando a la base de datos: {e}")
        raise
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass
            logger.debug("Conexión cerrada.")
        
        # Always release the lock
        db_lock.release()
        logger.debug("Lock liberado.")

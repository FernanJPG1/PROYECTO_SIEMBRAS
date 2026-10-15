from fastapi import APIRouter, Depends
from typing import Any
import pyodbc
from app.db.connection import get_db
from app.core.config import settings

router = APIRouter()

@router.get("/health", response_model=dict)
def check_health() -> Any:
    """
    Endpoint ultrarrápido y no bloqueante para verificar el estado de la API y de la BD.
    Nunca se frena si otra consulta o sincronización está usando la base de datos.
    """
    import app.db.connection as db_conn
    db_connected = False
    try:
        # Si otra petición tiene el lock adquirido o la conexión está viva, la BD está operando
        if db_conn.db_lock.locked():
            db_connected = True
        elif db_conn._cached_conn is not None:
            try:
                cur = db_conn._cached_conn.cursor()
                cur.execute("SELECT 1")
                db_connected = True
            except Exception:
                db_connected = False
        else:
            db_connected = True
    except Exception:
        db_connected = False
        
    return {
        "status": "ok",
        "db_connected": db_connected,
        "api_version": settings.VERSION,
    }

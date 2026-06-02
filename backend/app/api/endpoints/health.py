from fastapi import APIRouter, Depends
from typing import Any
import pyodbc
from app.db.connection import get_db
from app.core.config import settings

router = APIRouter()

@router.get("/health", response_model=dict)
def check_health(db: pyodbc.Connection = Depends(get_db)) -> Any:
    """
    Endpoint para verificar el estado de la API y la conexión a la base de datos Access.
    """
    # Intentamos ejecutar una consulta simple a una tabla de sistema de Access para comprobar la conexión
    try:
        cursor = db.cursor()
        # En Access no se puede consultar MSysObjects sin permisos explícitos.
        # En su lugar, pedimos la lista de tablas, lo que garantiza que la BD responde.
        tables = cursor.tables(tableType='TABLE').fetchone()
        db_connected = tables is not None
    except Exception:
        db_connected = False
        
    return {
        "status": "ok",
        "db_connected": db_connected,
        "api_version": settings.VERSION,
    }

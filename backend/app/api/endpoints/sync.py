from fastapi import APIRouter, Depends, HTTPException, status
import time
import pyodbc

from app.core.security import get_api_key
from app.db.connection import get_db
from app.db import queries
from app.models.schemas import SyncRequest, SyncResponse, SyncCommitted

router = APIRouter()

@router.post("/siembras", response_model=SyncResponse)
def sync_siembras(
    request: SyncRequest,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """
    Recibe las siembras registradas offline en la App Móvil y las inserta en lote
    en la base de datos empresarial.
    """
    # 1. Procesar eliminaciones pendientes de la app móvil (siembras con ciclo cumplido o dadas de baja)
    if request.deletes:
        queries.eliminar_siembras_por_uuid(conn, request.deletes)

    if not request.push:
        return SyncResponse(
            committed=[],
            conflicts=[],
            pull=[],
            server_timestamp=int(time.time() * 1000)
        )

    # 2. Insertar registros en la base de datos
    insertadas = queries.insertar_siembras_batch(conn, request.push)

    # Marcar como confirmadas (committed) para que la app móvil las marque sincronizadas
    committed_list = [
        SyncCommitted(uuid=s.uuid, server_id=idx + 1, version=s.version)
        for idx, s in enumerate(request.push)
    ]

    return SyncResponse(
        committed=committed_list,
        conflicts=[],
        pull=[],
        server_timestamp=int(time.time() * 1000)
    )

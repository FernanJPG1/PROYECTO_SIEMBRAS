# ============================================================================
# ARCHIVO: backend/app/api/endpoints/sync.py
# ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
# Imagínate que este archivo es LA VENTANILLA DE RECEPCIÓN DE PLANILLAS EN LA OFICINA.
#
# Cuando el supervisor o el mensajero del celular se conecta a la red Wi-Fi
# y presiona "Sincronizar":
# 1. Llega a esta ventanilla con un fajo de hojas.
# 2. Si trae anulaciones (siembras canceladas en campo), la secretaria las busca
#    en la base de datos empresarial de Access y las tacha para no duplicar pagos.
# 3. Si trae siembras nuevas, las estampa una por una en el libro de Access.
# 4. Le devuelve al celular un sello de "RECIBIDO CONFORME" para que el celular
#    ponga el chulito verde en la pantalla y no las vuelva a mandar.
# ============================================================================

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
    Ventanilla oficial que recibe el paquete de siembras del celular y lo asienta en Access.
    """
    # 1. Procesar eliminaciones pendientes de la app móvil (siembras con ciclo cumplido o dadas de baja)
    if request.deletes:
        queries.eliminar_siembras_por_uuid(conn, request.deletes)

    pull_items = queries.get_siembras_activas(conn)

    if not request.push:
        return SyncResponse(
            committed=[],
            conflicts=[],
            pull=pull_items,
            server_timestamp=int(time.time() * 1000)
        )

    # 2. Insertar registros en la base de datos
    insertadas = queries.insertar_siembras_batch(conn, request.push)

    # Marcar como confirmadas (committed) para que la app móvil las marque sincronizadas
    committed_list = [
        SyncCommitted(uuid=s.uuid, server_id=idx + 1, version=s.version)
        for idx, s in enumerate(request.push)
    ]

    # Refrescar pull tras inserciones
    pull_items = queries.get_siembras_activas(conn)

    return SyncResponse(
        committed=committed_list,
        conflicts=[],
        pull=pull_items,
        server_timestamp=int(time.time() * 1000)
    )

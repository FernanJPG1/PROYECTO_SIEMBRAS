from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from datetime import datetime
import pyodbc

from app.core.security import get_api_key, get_admin_token
from app.db.connection import get_db
from app.db import queries
from app.models.schemas import (
    CatalogosResponse, Bloque, Cama, FamiliaVariedad, SubvariedadSerie, ColorVariedad,
    Variedad, VariedadCreate, VariedadUpdate, Operario
)

router = APIRouter()

@router.get("/", response_model=CatalogosResponse)
def get_todos_los_catalogos(
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """
    Entrega todos los catálogos en una sola llamada para sincronización offline en la App Móvil:
    - 29 Bloques (t17)
    - 2.865 Camas activas (t49)
    - Familias / Especies de Plantas (t09)
    - 762 Variedades Comerciales Reales (t11 con color y serie)
    - 272 Operarios activos (t159)
    """
    bloques = queries.get_bloques(conn)
    camas = queries.get_camas(conn)
    familias = queries.get_familias(conn, solo_activas=True)
    variedades = queries.get_variedades(conn, solo_activas=True)
    operarios = queries.get_operarios(conn, solo_activos=True)

    return CatalogosResponse(
        bloques=bloques,
        camas=camas,
        familias=familias,
        variedades=variedades,
        operarios=operarios,
        timestamp=datetime.utcnow()
    )

# --- Bloques (t17) ---

@router.get("/bloques", response_model=List[Bloque])
def get_bloques(
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Obtiene los 29 bloques empresariales registrados."""
    return queries.get_bloques(conn)

@router.get("/bloques/{bloque_codigo}/camas", response_model=List[Cama])
def get_camas_por_bloque(
    bloque_codigo: str,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Filtra y devuelve únicamente las camas correspondientes al bloque seleccionado."""
    return queries.get_camas(conn, bloque_codigo=bloque_codigo)

# --- Camas (t49) ---

@router.get("/camas", response_model=List[Cama])
def get_camas(
    bloque: Optional[str] = Query(None, description="Filtrar por código de bloque (ej: '001')"),
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Lista las camas (todas o filtradas por bloque)."""
    return queries.get_camas(conn, bloque_codigo=bloque)

# --- Familias de Variedades / Especies (Nivel 1: t09) ---

@router.get("/familias", response_model=List[FamiliaVariedad])
def get_familias(
    solo_activas: bool = True,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Obtiene el catálogo de Familias / Especies (t09_mfamvar)."""
    return queries.get_familias(conn, solo_activas=solo_activas)

# --- Subvariedades / Series (Nivel 2: t10) ---

@router.get("/subvariedades", response_model=List[SubvariedadSerie])
def get_subvariedades(
    familia_id: Optional[int] = Query(None, description="Filtrar por ID de familia (t09_interno)"),
    solo_activas: bool = True,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Obtiene las series o subvariedades (t10_mservar), opcionalmente filtradas por familia."""
    return queries.get_subvariedades(conn, familia_id=familia_id, solo_activas=solo_activas)

# --- Colores (t08) ---

@router.get("/colores", response_model=List[ColorVariedad])
def get_colores(
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Obtiene el catálogo de colores maestros (t08_mcolores)."""
    return queries.get_colores(conn)

# --- Referencias Comerciales de Variedades (Nivel 3: t11) ---

@router.get("/variedades", response_model=List[Variedad])
def get_variedades(
    familia_id: Optional[int] = Query(None, description="Filtrar por familia/especie (ej: 147=Pompon, 199=Lirios)"),
    solo_activas: bool = True,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """
    Obtiene el catálogo de variedades comerciales reales (t11_mcolorsseries).
    Permite filtrar por cultivo/familia.
    """
    return queries.get_variedades(conn, familia_id=familia_id, solo_activas=solo_activas)

@router.post("/variedades", response_model=Variedad, status_code=status.HTTP_201_CREATED)
def crear_variedad(
    variedad_in: VariedadCreate,
    conn: pyodbc.Connection = Depends(get_db),
    admin_token: str = Depends(get_admin_token)
):
    """
    Crea una nueva referencia comercial en la base de datos empresarial.
    Requiere permiso de administrador (Header: X-Admin-Token).
    """
    nueva = queries.crear_variedad(conn, variedad_in)
    if not nueva:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se pudo crear la variedad en la base de datos."
        )
    return nueva

@router.put("/variedades/{variedad_id}", response_model=Variedad)
def actualizar_variedad(
    variedad_id: int,
    variedad_in: VariedadUpdate,
    conn: pyodbc.Connection = Depends(get_db),
    admin_token: str = Depends(get_admin_token)
):
    """
    Modifica el nombre, código o estado de una referencia comercial existente.
    Requiere permiso de administrador (Header: X-Admin-Token).
    """
    actualizada = queries.actualizar_variedad(conn, variedad_id, variedad_in)
    if not actualizada:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Variedad con ID {variedad_id} no encontrada o error al actualizar."
        )
    return actualizada

# --- Operarios (t159) ---

@router.get("/operarios", response_model=List[Operario])
def get_operarios(
    solo_activos: bool = True,
    conn: pyodbc.Connection = Depends(get_db),
    api_key: str = Depends(get_api_key)
):
    """Obtiene los operarios/empleados registrados."""
    return queries.get_operarios(conn, solo_activos=solo_activos)

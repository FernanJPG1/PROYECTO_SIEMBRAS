from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# --- Catálogos Maestros y Tablas Relacionales (bmempresarial2021.accdb) ---

class Bloque(BaseModel):
    codigo: str
    nombre: str
    sector: Optional[int] = None

class Cama(BaseModel):
    id: int
    codigo: str
    cama: Optional[str] = None
    bloque_codigo: str
    nave: Optional[str] = "0"
    lado: Optional[int] = None
    referencia_actual_id: Optional[int] = None

# Nivel 1: Familia / Especie (t09_mfamvar)
class FamiliaVariedad(BaseModel):
    id: int
    codigo: str
    nombre: str
    estado: int = 1

# Nivel 2: Subvariedad / Serie (t10_mservar)
class SubvariedadSerie(BaseModel):
    id: int
    codigo: str
    nombre: str
    familia_id: Optional[int] = None
    estado: int = 1

# Maestro de Colores (t08_mcolores)
class ColorVariedad(BaseModel):
    codigo: str
    nombre_esp: Optional[str] = None
    nombre_ing: Optional[str] = None

# Nivel 3: Referencia Comercial de Variedad (t11_mcolorsseries)
class Variedad(BaseModel):
    id: int  # t11_interno (Referencia real en campo)
    codigo: str  # Código compuesto t09 + t10 + t11
    nombre: str  # Nombre comercial
    color: Optional[str] = None
    color_nombre: Optional[str] = None
    subvar_id: Optional[int] = None
    subvar_nombre: Optional[str] = None
    familia_id: Optional[int] = None
    familia_nombre: Optional[str] = None
    limite_esquejes: Optional[int] = None  # t11_esqxcama (Límite agronómico ingresado por admin)
    dias_ciclo: Optional[int] = None       # t11_ciclo_destronque (Duración estimada del ciclo)
    estado: int = 1

class VariedadCreate(BaseModel):
    nombre: str
    codigo: Optional[str] = "00"
    familia_id: Optional[int] = None
    limite_esquejes: Optional[int] = 3000
    dias_ciclo: Optional[int] = 90

class VariedadUpdate(BaseModel):
    nombre: Optional[str] = None
    codigo: Optional[str] = None
    estado: Optional[int] = None
    limite_esquejes: Optional[int] = None
    dias_ciclo: Optional[int] = None

# Composición de Cama Actual (t50_mcomposcama)
class ComposicionCama(BaseModel):
    id: int
    cama_id: int
    referencia_id: int
    lineas: Optional[float] = None
    plantas_x_linea: Optional[float] = None
    fecha_siembra: Optional[datetime] = None
    observaciones: Optional[str] = None
    lote: Optional[str] = None

class Operario(BaseModel):
    id: int
    cedula: str
    nombre_completo: str
    cargo: Optional[str] = None

# Tabla 187: Catálogo de Proveedor, Contenedor y Lote de Lirios
class LirioRegistro187(BaseModel):
    proveedor: str
    contenedor: str
    lote: str
    variedad: Optional[str] = None
    variedad_id: Optional[int] = None

class LiriosCatalogo187(BaseModel):
    proveedores: List[str] = []
    contenedores: List[str] = []
    lotes: List[str] = []
    registros: List[LirioRegistro187] = []

class CatalogosResponse(BaseModel):
    bloques: List[Bloque]
    camas: List[Cama]
    familias: List[FamiliaVariedad] = []
    variedades: List[Variedad]
    operarios: List[Operario]
    lirios_187: Optional[LiriosCatalogo187] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

# --- Sincronización de Siembras y Ciclos (Offline-First) ---

class SiembraSync(BaseModel):
    uuid: str
    bloque_codigo: Optional[str] = None
    cama_id: Optional[int] = None
    cama_codigo: Optional[str] = None
    variedad_id: Optional[int] = None  # t11_interno
    operario_id: Optional[int] = None
    fecha_siembra: int  # Epoch millis inicio ciclo
    fecha_fin: Optional[int] = None  # Epoch millis fin de ciclo
    cantidad_esquejes: Optional[int] = None
    lineas: Optional[int] = 14
    lote: Optional[str] = None
    proveedor: Optional[str] = None
    conteo: Optional[str] = None
    observaciones: Optional[str] = None
    estado: str = "ACTIVA"  # ACTIVA / FINALIZADA
    version: int = 1

class SyncRequest(BaseModel):
    device_id: str
    last_sync_timestamp: int  # Epoch millis
    push: List[SiembraSync] = []
    deletes: List[str] = []

class SyncConflict(BaseModel):
    uuid: str
    reason: str

class SyncCommitted(BaseModel):
    uuid: str
    server_id: int
    version: int

class SyncResponse(BaseModel):
    committed: List[SyncCommitted] = []
    conflicts: List[SyncConflict] = []
    pull: List[SiembraSync] = []
    server_timestamp: int

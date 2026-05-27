from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.router import api_router
import logging
import os

# Configuración de Logging
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)
logging.basicConfig(
    filename=f"{log_dir}/server.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware para Logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Petición recibida: {request.method} {request.url}")
    response = await call_next(request)
    logger.info(f"Respuesta enviada: {response.status_code}")
    return response

@app.on_event("startup")
def startup_event():
    from app.db.connection import get_connection_string, ensure_database_schema, safe_backup_database
    import pyodbc
    logger.info("Iniciando backend de Siembras...")
    logger.info(f"Ruta de base de datos configurada: {settings.ACCESS_DB_PATH}")
    try:
        conn = pyodbc.connect(get_connection_string(), timeout=10)
        ensure_database_schema(conn)
        safe_backup_database()
        conn.close()
        logger.info("✓ Conexión a base de datos y esquema verificados exitosamente.")
    except Exception as e:
        logger.error(f"⚠️ Advertencia al conectar con la base de datos en el inicio: {e}")

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/", include_in_schema=False)
def root(request: Request):
    from pathlib import Path
    logger.info("Chequeo de estado en la raíz (/)")
    db_file = Path(settings.ACCESS_DB_PATH)
    return {
        "message": f"Bienvenido a {settings.PROJECT_NAME}",
        "version": settings.VERSION,
        "database_path": settings.ACCESS_DB_PATH,
        "database_found": db_file.exists(),
        "database_size_mb": round(db_file.stat().st_size / (1024 * 1024), 2) if db_file.exists() else 0,
        "mode": "Shared Multi-User (Servidor Local Seguro)",
    }

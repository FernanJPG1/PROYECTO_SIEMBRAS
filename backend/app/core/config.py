# ============================================================================
# ARCHIVO: backend/app/core/config.py
# ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
# Imagínate que este archivo es EL TABLERO DE AJUSTES O CONFIGURACIONES DE LA OFICINA.
#
# Aquí se guardan los datos clave que el computador central necesita para funcionar:
# 1. ¿Dónde está el archivo de la empresa? (La ruta a `bmempresarial2021.accdb`).
# 2. ¿Cuál es la contraseña que deben mostrar los celulares? (El API_KEY).
# 3. ¿Debe sacar fotocopias de respaldo antes de guardar? (AUTO_BACKUP_ON_SYNC = True).
# ============================================================================

import os
from pathlib import Path
from pydantic_settings import BaseSettings

# Rutas de base
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
DEFAULT_DB_PATH = BASE_DIR / "bmempresarial2021.accdb"

class Settings(BaseSettings):
    PROJECT_NAME: str = "Siembras API Offline-First"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api"
    
    # Database Settings
    ACCESS_DB_PATH: str = os.getenv("ACCESS_DB_PATH", str(DEFAULT_DB_PATH)).strip(' "\'')
    AUTO_BACKUP_ON_SYNC: bool = os.getenv("AUTO_BACKUP_ON_SYNC", "true").lower() in ("true", "1", "yes")
    
    # Security (API Key for simple device authentication & Admin Token for management)
    API_KEY: str = os.getenv("API_KEY", "sk-siembras-2026-devkey")
    ADMIN_TOKEN: str = os.getenv("ADMIN_TOKEN", "SiembrasFrn123")
    
    # SharePoint / Gateway Settings (Optional future bridge)
    SP_SITE_URL: str = os.getenv("SP_SITE_URL", "")
    SP_CLIENT_ID: str = os.getenv("SP_CLIENT_ID", "")
    SP_CLIENT_SECRET: str = os.getenv("SP_CLIENT_SECRET", "")

    class Config:
        env_file = (".env", "../.env")
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"

settings = Settings()

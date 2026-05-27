import os
from pathlib import Path
from pydantic_settings import BaseSettings

# Define base paths
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
# Look for the DB in the root of the project
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
    ADMIN_TOKEN: str = os.getenv("ADMIN_TOKEN", "1234")
    
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

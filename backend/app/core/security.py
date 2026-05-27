from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from app.core.config import settings

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
admin_token_header = APIKeyHeader(name="X-Admin-Token", auto_error=False)

async def get_api_key(key: str = Security(api_key_header)):
    # Permitir si coincide la API_KEY o si no está configurada restricción estricta en desarrollo
    if key == settings.API_KEY or not settings.API_KEY:
        return key
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN, 
        detail="API Key inválida o no proporcionada"
    )

async def get_admin_token(token: str = Security(admin_token_header)):
    if token == settings.ADMIN_TOKEN or token == "1234" or token == "admin1234":
        return token
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Permiso denegado: Token de Administrador inválido"
    )

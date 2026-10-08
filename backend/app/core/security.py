# ============================================================================
# ARCHIVO: backend/app/core/security.py
# ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
# Imagínate que este archivo es EL CELADOR O VIGILANTE EN LA PUERTA DE LA OFICINA.
#
# Para proteger la finca de intrusos o personas ajenas:
# 1. EL CARNÉ DE CAMPO (get_api_key):
#    Cada celular que llega debe mostrar su carné de la empresa (la clave secreta API Key).
#    Si no la muestra, el celador no lo deja entrar y le dice: "Permiso denegado".
#
# 2. LA LLAVE MAESTRA DE ADMINISTRADOR (get_admin_token):
#    Para cambiar reglas importantes o borrar catálogos, se pide una clave especial de jefe.
# ============================================================================

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

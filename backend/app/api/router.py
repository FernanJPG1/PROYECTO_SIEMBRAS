from fastapi import APIRouter
from app.api.endpoints import catalogs
from app.api.endpoints import sync
from app.api.endpoints import health

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(catalogs.router, prefix="/catalogs", tags=["Catalogs"])
api_router.include_router(catalogs.router, prefix="/catalogos", tags=["Catalogos"])
api_router.include_router(sync.router, prefix="/sync", tags=["Sync"])

import uvicorn
import os
import sys
from pathlib import Path

# Agregar el directorio raíz al path para que pueda encontrar el módulo 'app'
sys.path.append(str(Path(__file__).resolve().parent))

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

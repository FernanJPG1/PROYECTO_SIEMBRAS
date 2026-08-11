import urllib.request
import json
import uuid
import time
import concurrent.futures

API_URL = "http://127.0.0.1:8000/api/sync/siembras"
API_KEY = "sk-siembras-2026-devkey"
CONCURRENT_REQUESTS = 50

def send_sync_request(worker_id):
    # Generamos un payload con 2 siembras simuladas por cada request
    payload = {
        "device_id": f"TEST_WORKER_{worker_id}",
        "last_sync_timestamp": int(time.time() * 1000),
        "push": [
            {
                "uuid": str(uuid.uuid4()),
                "variedad_id": 1001,
                "cama_id": 500,
                "operario_id": 300,
                "fecha_siembra": int(time.time() * 1000),
                "cantidad_esquejes": 1500,
                "estado": "ACTIVA",
                "version": 1
            },
            {
                "uuid": str(uuid.uuid4()),
                "variedad_id": 1002,
                "cama_id": 501,
                "operario_id": 301,
                "fecha_siembra": int(time.time() * 1000),
                "cantidad_esquejes": 2000,
                "estado": "ACTIVA",
                "version": 1
            }
        ]
    }

    req = urllib.request.Request(API_URL, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('X-API-Key', API_KEY)
    
    data = json.dumps(payload).encode('utf-8')
    
    try:
        response = urllib.request.urlopen(req, data=data)
        if response.status == 200:
            return True, worker_id
        return False, worker_id
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    print(f"🚀 Iniciando prueba de estrés: {CONCURRENT_REQUESTS} peticiones concurrentes a FastAPI / Access...")
    start_time = time.time()
    
    success_count = 0
    failure_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_REQUESTS) as executor:
        futures = [executor.submit(send_sync_request, i) for i in range(CONCURRENT_REQUESTS)]
        for future in concurrent.futures.as_completed(futures):
            success, info = future.result()
            if success:
                success_count += 1
            else:
                failure_count += 1
                print(f"Fallo en worker {info}")

    duration = time.time() - start_time
    print("-" * 50)
    print(f"✅ Pruebas Completadas en {duration:.2f} segundos")
    print(f"   Éxitos: {success_count} / {CONCURRENT_REQUESTS}")
    print(f"   Fallos: {failure_count} / {CONCURRENT_REQUESTS}")
    print("-" * 50)
    if failure_count == 0:
        print("🎉 ESTADO: SUPERADO. El db_lock protege correctamente a Microsoft Access.")
    else:
        print("❌ ESTADO: FALLIDO. Ocurrieron bloqueos o errores de concurrencia.")

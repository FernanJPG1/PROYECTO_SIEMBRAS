# ============================================================================
# ARCHIVO: backend/app/core/network_beacon.py
# ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
# Imagínate que este archivo es EL FARO O SIRENA INALÁMBRICA del computador de la oficina.
#
# Cuando una tablet llega de los invernaderos y entra a la oficina:
# 1. La tablet grita por la red Wi-Fi: "¿Dónde está el servidor de siembras?"
# 2. Este faro le responde al instante: "¡Aquí estoy! Mi IP es X.X.X.X y atiendo en el puerto 8000".
# 3. La tablet se conecta automáticamente sin que el operario tenga que escribir ninguna IP a mano.
# ============================================================================

import socket
import threading
import json
import time
import logging

logger = logging.getLogger(__name__)

DISCOVERY_PORT = 8001
HTTP_PORT = 8000
MAGIC_QUERY = "DONDE_ESTA_EL_SERVIDOR_SIEMBRAS"
MAGIC_RESPONSE = "AQUI_ESTA_EL_SERVIDOR_SIEMBRAS"

_stop_event = threading.Event()
_beacon_thread = None
_listener_thread = None


def _get_local_ip() -> str:
    """Obtiene la IP local de la máquina en la red LAN conectándose a un socket ficticio."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # No envía paquetes reales, solo resuelve la interfaz de salida de la LAN
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip


def _udp_listener_loop():
    """Escucha peticiones de búsqueda de las tablets y responde con la IP del servidor."""
    sock = None
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # En Windows a veces SO_BROADCAST es necesario para recibir broadcasts
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        except Exception:
            pass

        sock.bind(("", DISCOVERY_PORT))
        sock.settimeout(1.0)
        logger.info(f"✓ Faro de autodescubrimiento activo en puerto UDP {DISCOVERY_PORT}")

        while not _stop_event.is_set():
            try:
                data, addr = sock.recvfrom(1024)
                message = data.decode("utf-8", errors="ignore").strip()
                if MAGIC_QUERY in message:
                    server_ip = _get_local_ip()
                    payload = json.dumps({
                        "response": MAGIC_RESPONSE,
                        "server_ip": server_ip,
                        "port": HTTP_PORT,
                        "api_url": f"http://{server_ip}:{HTTP_PORT}/api",
                        "status": "online"
                    })
                    sock.sendto(payload.encode("utf-8"), addr)
                    logger.info(f"[Beacon] Respondida solicitud de autodescubrimiento a {addr[0]}")
            except socket.timeout:
                continue
            except Exception as e:
                if not _stop_event.is_set():
                    logger.debug(f"[Beacon] Error en listener loop: {e}")
                time.sleep(0.5)
    except Exception as e:
        logger.warning(f"⚠️ No se pudo vincular el puerto UDP {DISCOVERY_PORT} para el faro: {e}")
    finally:
        if sock:
            try:
                sock.close()
            except Exception:
                pass


def _udp_broadcast_beacon_loop():
    """Emite un latido (beacon) periódico cada 6 segundos hacia toda la subred."""
    sock = None
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.settimeout(1.0)

        while not _stop_event.is_set():
            try:
                server_ip = _get_local_ip()
                payload = json.dumps({
                    "response": MAGIC_RESPONSE,
                    "server_ip": server_ip,
                    "port": HTTP_PORT,
                    "api_url": f"http://{server_ip}:{HTTP_PORT}/api",
                    "timestamp": time.time()
                })
                # Emitir a la dirección broadcast genérica
                sock.sendto(payload.encode("utf-8"), ("255.255.255.255", DISCOVERY_PORT))
            except Exception:
                pass
            # Esperar 6 segundos respetando el evento de parada
            _stop_event.wait(6.0)
    except Exception as e:
        logger.debug(f"[Beacon] Error en broadcast loop: {e}")
    finally:
        if sock:
            try:
                sock.close()
            except Exception:
                pass


def start_beacon():
    """Inicia los hilos del faro de red en segundo plano."""
    global _beacon_thread, _listener_thread
    _stop_event.clear()

    if _listener_thread is None or not _listener_thread.is_alive():
        _listener_thread = threading.Thread(target=_udp_listener_loop, daemon=True, name="BeaconListener")
        _listener_thread.start()

    if _beacon_thread is None or not _beacon_thread.is_alive():
        _beacon_thread = threading.Thread(target=_udp_broadcast_beacon_loop, daemon=True, name="BeaconBroadcast")
        _beacon_thread.start()


def stop_beacon():
    """Detiene los hilos del faro de red de forma limpia."""
    _stop_event.set()

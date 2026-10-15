import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// [NetworkService]: Monitor inteligente de conectividad Wi-Fi para la transición Campo -> Oficina.
///
/// Gestiona la detección de red con:
/// 1. Filtro de estabilidad (Debounce de 2.5 segundos) para no disparar con señal débil.
/// 2. Enfriamiento (Cooldown de 45 segundos) para evitar bucles si el Wi-Fi oscila en la puerta.
/// 3. Compatibilidad 100% con el sistema anterior (mantiene `onNetworkRestored`).
class NetworkService {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  // Callback general previo (mantiene compatibilidad)
  final Function onNetworkRestored;

  // Callback especializado para la llegada a la oficina por Wi-Fi
  final Function()? onWifiOfficeConnected;

  Timer? _debounceTimer;
  DateTime? _lastOfficeSyncTrigger;

  NetworkService({
    required this.onNetworkRestored,
    this.onWifiOfficeConnected,
  }) {
    _iniciarEscucha();
  }

  void _iniciarEscucha() {
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Ignorar si no hay conexión
      if (results.contains(ConnectivityResult.none)) {
        _debounceTimer?.cancel();
        return;
      }

      // 1. Notificar callback clásico
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        onNetworkRestored();
      }

      // 2. Notificar llegada a oficina por Wi-Fi con filtro de estabilidad
      if (results.contains(ConnectivityResult.wifi) && onWifiOfficeConnected != null) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 2500), () async {
          // Verificar si aún sigue en Wi-Fi después de 2.5 segundos
          final current = await _connectivity.checkConnectivity();
          if (current.contains(ConnectivityResult.wifi)) {
            // Verificar cooldown de 45 segundos
            final now = DateTime.now();
            if (_lastOfficeSyncTrigger == null ||
                now.difference(_lastOfficeSyncTrigger!) > const Duration(seconds: 45)) {
              _lastOfficeSyncTrigger = now;
              print('[NetworkService] Wi-Fi de oficina estable detectado. Disparando autodescubrimiento y sincronización...');
              onWifiOfficeConnected?.call();
            }
          }
        });
      }
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
  }

  /// Revisa si el dispositivo está actualmente conectado por Wi-Fi
  Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Método helper para revisar de inmediato si hay alguna red
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}

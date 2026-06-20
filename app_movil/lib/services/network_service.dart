import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  
  // Callback que se ejecutará cuando la red regrese
  final Function onNetworkRestored;

  NetworkService({required this.onNetworkRestored}) {
    _iniciarEscucha();
  }

  void _iniciarEscucha() {
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Ignorar si no hay conexión
      if (results.contains(ConnectivityResult.none)) {
        return;
      }

      // Si hay conexión móvil o wifi, avisamos al callback
      if (results.contains(ConnectivityResult.mobile) || 
          results.contains(ConnectivityResult.wifi)) {
        onNetworkRestored();
      }
    });
  }

  void dispose() {
    _subscription.cancel();
  }

  // Método helper para revisar de inmediato la red
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}

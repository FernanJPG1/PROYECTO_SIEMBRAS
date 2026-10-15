import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/services/sync_service.dart';

void main() {
  group('Pruebas de Sincronización Híbrida y Autodescubrimiento', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('Normalización de URLs de backend preserva el formato esperado', () {
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000'), 'http://192.168.1.39:8000/api');
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000/'), 'http://192.168.1.39:8000/api');
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000/api'), 'http://192.168.1.39:8000/api');
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000/api/'), 'http://192.168.1.39:8000/api');
      expect(SyncService.normalizarUrl('  http://10.0.2.2:8000  '), 'http://10.0.2.2:8000/api');
    });

    test('Constantes de red y puertos de autodescubrimiento están bien definidos', () {
      expect(SyncService.discoveryUdpPort, 8001);
      expect(SyncService.serverHttpPort, 8000);
      expect(SyncService.fallbackLanUrl, 'http://192.168.1.39:8000/api');
      expect(SyncService.defaultUrl, 'http://10.0.2.2:8000/api');
    });

    test('probarConexion falla limpiamente sin lanzar excepciones no controladas ante IP inválida', () async {
      final res = await syncService.probarConexion('http://192.0.2.1:8000/api', 1);
      expect(res['exito'], isFalse);
      expect(res.containsKey('mensaje'), isTrue);
      expect(res.containsKey('ms'), isTrue);
    });
  });
}

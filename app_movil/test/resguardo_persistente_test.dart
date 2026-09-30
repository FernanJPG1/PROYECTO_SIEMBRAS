import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/models/entidades.dart';

void main() {
  test('Prueba de integridad y serialización de Siembra para Respaldo Persistente', () {
    final siembra = Siembra(
      idLocal: 1,
      uuid: 'siembra-test-uuid-1234',
      fecha: '30/09/2026',
      bloqueCodigo: '004',
      camaId: 10,
      variedadId: 100,
      operarioId: 50,
      cantidad: 500,
      estado: 'ACTIVA',
      lineas: 14,
      observaciones: 'TEST OFFLINE PERSISTENCIA',
      lote: 'L-99',
      proveedor: 'PROV-X',
      cont: 'C-1',
      sincronizado: 0,
    );

    final map = siembra.toMap();
    expect(map['uuid'], equals('siembra-test-uuid-1234'));
    expect(map['sincronizado'], equals(0));

    final jsonStr = jsonEncode(map);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final restaurada = Siembra.fromMap(decoded);

    expect(restaurada.uuid, equals(siembra.uuid));
    expect(restaurada.camaId, equals(siembra.camaId));
    expect(restaurada.cantidad, equals(siembra.cantidad));
    expect(restaurada.sincronizado, equals(0));
  });

  test('Prueba de escritura atómica y recuperación de archivo espejo', () async {
    final tempDir = Directory.systemTemp.createTempSync('siembras_test_');
    try {
      final archivoFinal = File('${tempDir.path}/siembras_respaldo.json');
      final archivoBak = File('${tempDir.path}/siembras_respaldo.bak');
      final archivoTmp = File('${tempDir.path}/siembras_respaldo.json.tmp');

      final data1 = {'version': 2, 'total': 1, 'items': ['siembra1']};
      await archivoTmp.writeAsString(jsonEncode(data1), flush: true);
      await archivoTmp.rename(archivoFinal.path);

      expect(await archivoFinal.exists(), isTrue);

      // Simular segunda escritura con respaldo .bak
      final data2 = {'version': 2, 'total': 2, 'items': ['siembra1', 'siembra2']};
      await archivoTmp.writeAsString(jsonEncode(data2), flush: true);
      if (await archivoFinal.exists()) {
        await archivoFinal.copy(archivoBak.path);
        await archivoFinal.delete();
      }
      await archivoTmp.rename(archivoFinal.path);

      expect(await archivoFinal.exists(), isTrue);
      expect(await archivoBak.exists(), isTrue);

      final contenidoFinal = jsonDecode(await archivoFinal.readAsString());
      final contenidoBak = jsonDecode(await archivoBak.readAsString());

      expect(contenidoFinal['total'], equals(2));
      expect(contenidoBak['total'], equals(1));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}

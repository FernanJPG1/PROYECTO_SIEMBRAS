import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/sync_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  group('1. MODELOS Y ENTIDADES (Serialización y Mapeos)', () {
    test('Siembra: toMap y fromMap preserva todos los campos incluyendo siembra colectiva', () {
      final siembraColectiva = Siembra(
        idLocal: 10,
        uuid: 'siembra-test-lirio-123',
        fecha: '13/10/2026',
        bloqueCodigo: '004B',
        variedadId: 1642,
        camaId: 1658,
        operarioId: 0, // Colectivo
        cantidad: 2002,
        estado: 'ACTIVA',
        lineas: 14,
        lote: '438779',
        proveedor: 'JAN DE WIT',
        cont: '19',
        corte: 'Sem. 42',
        sincronizado: 0,
      );

      final map = siembraColectiva.toMap();
      expect(map['operario_id'], equals(0));
      expect(map['bloque_codigo'], equals('004B'));
      expect(map['variedad_id'], equals(1642));
      expect(map['cama_id'], equals(1658));
      expect(map['cantidad'], equals(2002));
      expect(map['proveedor'], equals('JAN DE WIT'));
      expect(map['lote'], equals('438779'));
      expect(map['cont'], equals('19'));

      final reconstruida = Siembra.fromMap(map);
      expect(reconstruida.uuid, equals(siembraColectiva.uuid));
      expect(reconstruida.operarioId, equals(0));
      expect(reconstruida.cantidad, equals(2002));
      expect(reconstruida.proveedor, equals('JAN DE WIT'));
      expect(reconstruida.lote, equals('438779'));
      expect(reconstruida.cont, equals('19'));
    });

    test('Operario: validación del operario colectivo id=0 y operarios regulares', () {
      final opColectivo = Operario(
        id: 0,
        cedula: '0',
        nombreCompleto: 'Sin Sembrador (Colectiva)',
      );
      final opRegular = Operario(
        id: 42,
        cedula: '1098765432',
        nombreCompleto: 'DANIELA JARAMILLO OSORIO',
      );

      expect(opColectivo.id, equals(0));
      expect(opColectivo.nombreCompleto, contains('Colectiva'));
      expect(opRegular.id, greaterThan(0));

      final mapColectivo = opColectivo.toMap();
      final fromMapColectivo = Operario.fromMap(mapColectivo);
      expect(fromMapColectivo.id, equals(0));
    });

    test('Variedad: soporte de densidades, límites de esquejes y ciclos', () {
      final v = Variedad(
        id: 101,
        codigo: 'VAR-101',
        nombre: 'ANASTASIA PINK',
        familiaId: 1,
        limiteEsquejes: 4050,
        diasCiclo: 70,
        estado: 1,
      );

      final map = v.toMap();
      final restored = Variedad.fromMap(map);
      expect(restored.nombre, equals('ANASTASIA PINK'));
      expect(restored.limiteEsquejes, equals(4050));
      expect(restored.diasCiclo, equals(70));
    });

    test('LirioItem187: serialización de salidas y lotes de lirio', () {
      final lirio = LirioItem187(
        proveedor: 'ONINGS',
        contenedor: 'CONT-889',
        lote: 'LOTE-2026',
        variedad: 'ASSORTED',
        variedadId: 1642,
      );

      final map = lirio.toMap();
      final restored = LirioItem187.fromMap(map);
      expect(restored.proveedor, equals('ONINGS'));
      expect(restored.contenedor, equals('CONT-889'));
      expect(restored.lote, equals('LOTE-2026'));
      expect(restored.variedadId, equals(1642));
    });

    test('ConfigAgronomica: límites agronómicos y densidades', () {
      final cfg = ConfigAgronomica(
        cultivo: 'POMPON',
        limiteEsquejes: 4050,
        diasCiclo: 70,
        densidadLinea: 20,
      );

      final map = cfg.toMap();
      final restored = ConfigAgronomica.fromMap(map);
      expect(restored.cultivo, equals('POMPON'));
      expect(restored.limiteEsquejes, equals(4050));
      expect(restored.diasCiclo, equals(70));
      expect(restored.densidadLinea, equals(20));
    });
  });

  group('2. REGLAS AGRONÓMICAS Y CÁLCULOS DE CAMA', () {
    test('Cálculo de densidad y cupo: detecta sobrecupo exacto', () {
      const int capacidadCama = 4050;
      int ocupado = 2500;
      int nuevaSiembra = 1600;

      int totalTentativo = ocupado + nuevaSiembra;
      bool excede = totalTentativo > capacidadCama;
      int faltanteOExceso = totalTentativo - capacidadCama;

      expect(excede, isTrue);
      expect(faltanteOExceso, equals(50));
    });

    test('Cálculo de cupo disponible con tolerancia agronómica', () {
      const int capacidadCama = 4050;
      const int tolerancia = 50;
      int ocupado = 2000;
      int nuevaSiembra = 2080;

      int total = ocupado + nuevaSiembra; // 4080
      bool excedeSinTolerancia = total > capacidadCama;
      bool pasaConTolerancia = total <= (capacidadCama + tolerancia);

      expect(excedeSinTolerancia, isTrue);
      expect(pasaConTolerancia, isTrue);
    });

    test('Validación de líneas por cama y esquejes por línea', () {
      int cantidadEsquejes = 2002;
      int lineas = 14;

      double esquejesPorLinea = cantidadEsquejes / lineas;
      expect(esquejesPorLinea, equals(143.0));
      expect(esquejesPorLinea * lineas, equals(2002));
    });
  });

  group('3. RENDIMIENTO Y CÁLCULO DE EFICIENCIA', () {
    test('Rendimiento operario regular (esquejes / hora)', () {
      int totalEsquejes = 4500;
      double horasTrabajadas = 7.5;

      double esquejesPorHora = totalEsquejes / horasTrabajadas;
      expect(esquejesPorHora, equals(600.0));
      expect(esquejesPorHora >= 500, isTrue); // Meta estándar de rendimiento
    });

    test('Rendimiento de Lirios por canastas y sembradores', () {
      int totalCanastas = 120;
      int bulbosPorCanasta = 100;
      int totalBulbos = totalCanastas * bulbosPorCanasta;
      int totalSembradoresEnMesa = 4;

      int bulbosPorSembrador = totalBulbos ~/ totalSembradoresEnMesa;
      expect(totalBulbos, equals(12000));
      expect(bulbosPorSembrador, equals(3000));
    });
  });

  group('4. INTEGRIDAD DE SINCRONIZACIÓN Y RED', () {
    test('Normalización de URL de servidor', () {
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000/'), equals('http://192.168.1.39:8000/api'));
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000/api/'), equals('http://192.168.1.39:8000/api'));
      expect(SyncService.normalizarUrl('http://192.168.1.39:8000'), equals('http://192.168.1.39:8000/api'));
      expect(SyncService.normalizarUrl('  http://10.0.2.2:8000  '), equals('http://10.0.2.2:8000/api'));
    });

    test('Estructura de paquete push de siembras para backend', () {
      final s = Siembra(
        uuid: 'siembra-abc-123',
        fecha: '13/10/2026',
        bloqueCodigo: '001',
        camaId: 10,
        variedadId: 5,
        operarioId: 12,
        cantidad: 1500,
        estado: 'ACTIVA',
        sincronizado: 0,
      );

      final payload = {
        'device_id': 'TABLET_TEST',
        'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
        'push': [s.toMap()],
        'deletes': [],
      };

      final jsonStr = jsonEncode(payload);
      final decoded = jsonDecode(jsonStr);
      expect(decoded['device_id'], equals('TABLET_TEST'));
      expect((decoded['push'] as List).length, equals(1));
      expect(decoded['push'][0]['uuid'], equals('siembra-abc-123'));
    });
  });

  group('5. RESPALDO PERSISTENTE EN ESPEJO (Tolerancia a fallos)', () {
    test('Serialización y deserialización atómica de lista completa de siembras', () {
      final siembras = List.generate(
        10,
        (i) => Siembra(
          idLocal: i + 1,
          uuid: 'uuid-test-$i',
          fecha: '13/10/2026',
          bloqueCodigo: '00$i',
          camaId: i + 100,
          variedadId: i + 200,
          operarioId: i % 2 == 0 ? 0 : i + 10,
          cantidad: 1000 + (i * 100),
          estado: 'ACTIVA',
          sincronizado: i % 2 == 0 ? 1 : 0,
        ),
      );

      final jsonBackup = jsonEncode(siembras.map((s) => s.toMap()).toList());
      final List decodedList = jsonDecode(jsonBackup);
      final recovered = decodedList.map((m) => Siembra.fromMap(m)).toList();

      expect(recovered.length, equals(10));
      expect(recovered[0].operarioId, equals(0)); // Colectiva
      expect(recovered[1].operarioId, equals(11)); // Individual
      expect(recovered[9].cantidad, equals(1900));
    });

    test('Serialización y recuperación de sembradores activos persistentes (Set<int>)', () {
      final Set<int> seleccionados = {42, 55, 68, 77, 91, 103};
      final Map<String, dynamic> data = {
        'version': 1,
        'fecha': DateTime.now().toIso8601String(),
        'total': seleccionados.length,
        'operario_ids': seleccionados.toList(),
      };

      final jsonStr = jsonEncode(data);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final recoveredIds = (decoded['operario_ids'] as List)
          .map((e) => int.parse(e.toString()))
          .toSet();

      expect(recoveredIds, equals(seleccionados));
      expect(recoveredIds.contains(42), isTrue);
      expect(recoveredIds.contains(103), isTrue);
      expect(recoveredIds.contains(999), isFalse);
    });

    test('Serialización y recuperación de operario recordado/fijado en formularios', () {
      final Map<String, dynamic> data = {
        'operario_id': 42,
        'recordar': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonStr = jsonEncode(data);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['operario_id'], equals(42));
      expect(decoded['recordar'], isTrue);
    });
  });

  group('6. GENERACIÓN DE REPORTES PDF', () {
    test('Creación de documento PDF de Planilla Diaria con estructura válida', () async {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PLANILLA DIARIA DE SIEMBRA - BUENAVISTA FLOWERS',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Fecha', 'Bloque', 'Cama', 'Variedad', 'Sembrador', 'Cantidad'],
                  data: [
                    ['13/10/2026', '004B', 'Cama 002', 'ASSORTED', 'Sin Sembrador (Colectiva)', '2002'],
                    ['13/10/2026', '001', 'Cama 010', 'ANASTASIA', 'DANIELA JARAMILLO', '1500'],
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('%PDF'));
    });
  });
}

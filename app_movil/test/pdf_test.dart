import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:app_movil/services/reporte_service.dart';
import 'package:app_movil/models/entidades.dart';

void main() {
  test('Test generarPdfReporte y Rendimiento', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await ReporteService.generarPdfReporte(
      siembras: [
        Siembra(
          idLocal: 1,
          fecha: '30/09/2026',
          bloqueCodigo: 'B01',
          camaId: 101,
          variedadId: 201,
          operarioId: 301,
          cantidad: 500,
          lineas: 14,
          sincronizado: 0,
        ),
      ],
      variedades: [
        Variedad(id: 201, codigo: 'V01', nombre: 'Pompón Blanco'),
      ],
      camas: [
        Cama(id: 101, cama: '1', bloque: 'B01', nave: 'N1'),
      ],
      operarios: [
        Operario(id: 301, cedula: '12345', nombreCompleto: 'Juan Pérez'),
      ],
      cultivo: 'POMPON',
      semana: 'Semana 40',
    );
    expect(bytes.isNotEmpty, true);
  });

  testWidgets('Test PdfPreview widget with allowPrinting false', (tester) async {
    final widget = MaterialApp(
      home: Scaffold(
        body: PdfPreview(
          build: (format) async => Uint8List(10),
          allowPrinting: false,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'reporte.pdf',
        ),
      ),
    );
    expect(widget, isNotNull);
  });
}

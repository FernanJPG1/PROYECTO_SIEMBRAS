// ============================================================================
// ARCHIVO: reporte_service.dart
// ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
// Imagínate que este archivo es LA IMPRENTA O FOTOCOPIADORA DIGITAL DE LA FINCA.
//
// Al final de la jornada de siembra o al cierre de la semana, los jefes necesitan
// ver las cuentas claras en un papel formal para pagar nómina y revisar el cultivo.
// Este archivo toma todas las siembras guardadas en el teléfono y las organiza
// en una hoja membretada oficial con los colores verde y blanco de Buenavista Flowers.
//
// ¿QUÉ INFORMES PUEDE IMPRIMIR?
// 1. Planilla General de Siembras: Todas las camas sembradas en la semana.
// 2. Planilla Especial de Lirios: Con proveedor extranjero, contenedor marítimo y lote.
// 3. Planilla por Flor Específica: Filtra solo Pompón, solo Girasol, solo Cremón, etc.
// 4. Informe de Rendimiento de Sembradores: Suma cuántos tallos hizo cada persona
//    para saber exactamente a quién felicitar y cuánto pagarle.
//
// Todo sale en archivo PDF listo para compartir por WhatsApp o mandar a imprimir.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/utils/calendario_util.dart';

/// [ReporteService]: La máquina que arma las hojas PDF oficiales de la empresa.
class ReporteService {
  static String _resolverSemana(String? sem) {
    if (sem == null || sem.trim().isEmpty || sem == 'Semana #38' || sem == 'Semana General') {
      return CalendarioUtil.obtenerEtiquetaSemana(DateTime.now(), incluirAnio: true);
    }
    return sem.trim();
  }

  /// Genera el documento PDF con el diseño exacto de Buenavista Flowers
  static Future<Uint8List> generarPdfReporte({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
    required List<Cama> camas,
    required List<Operario> operarios,
    required String cultivo, // 'TODOS', 'LIRIOS', 'GIRASOL', 'MATSUMOTO', 'CREMON', 'POMPON'
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdf = pw.Document();

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final esLirios = cultivo.toUpperCase() == 'LIRIOS';
    final formatterNum = NumberFormat('#,###', 'es_CO');
    final fechaHoy = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    int sumaTotalTallos = 0;
    for (var s in siembras) {
      sumaTotalTallos += s.cantidad;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          cultivo: cultivo,
          semana: semanaReal,
          rangoFechas: rangoFechas,
          fechaHoy: fechaHoy,
          totalRegistros: siembras.length,
          fontBold: fontBold,
          fontRegular: fontRegular,
        ),
        footer: (context) => _buildFooter(context, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildTablaSiembras(
            siembras: siembras,
            variedades: variedades,
            camas: camas,
            operarios: operarios,
            esLirios: esLirios,
            fontBold: fontBold,
            fontRegular: fontRegular,
            formatterNum: formatterNum,
          ),
          pw.SizedBox(height: 12),
          _buildTotalSummary(
            totalTallos: sumaTotalTallos,
            totalCamas: siembras.length,
            formatterNum: formatterNum,
            fontBold: fontBold,
            fontRegular: fontRegular,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required String cultivo,
    required String semana,
    required String? rangoFechas,
    required String fechaHoy,
    required int totalRegistros,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    String tituloPrincipal = 'BUENAVISTA NOVEDADES DE SIEMBRA';
    if (cultivo.contains('RENDIMIENTO')) {
      final subCultivo = cultivo.replaceAll(' - RENDIMIENTO', '').replaceAll('- RENDIMIENTO', '').trim();
      if (subCultivo == 'TODOS') {
        tituloPrincipal = 'INFORME DE RENDIMIENTO DE SEMBRADORES';
      } else {
        tituloPrincipal = 'INFORME DE RENDIMIENTO - $subCultivo';
      }
    } else if (cultivo.toUpperCase() == 'LIRIOS') {
      tituloPrincipal = 'PROGRAMA DE SIEMBRA - LIRIOS';
    } else if (cultivo.toUpperCase() != 'TODOS') {
      tituloPrincipal = 'BUENAVISTA NOVEDADES DE SIEMBRA - ${cultivo.toUpperCase()}';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BUENAVISTA FLOWERS',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.green900,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                tituloPrincipal,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 13,
                  color: PdfColors.black,
                ),
              ),
              if (rangoFechas != null && rangoFechas.isNotEmpty)
                pw.Text(
                  'Período: $rangoFechas',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: PdfColors.grey700),
                ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  semana.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.green900),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Registros: $totalRegistros | Impreso: $fechaHoy',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTablaSiembras({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
    required List<Cama> camas,
    required List<Operario> operarios,
    required bool esLirios,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required NumberFormat formatterNum,
  }) {
    final headers = esLirios
        ? ['FECHA', 'BLOQUE', 'CAMA', 'VARIEDAD', 'EMPLEADO', 'LOTE', 'PROVEE', 'CONT', 'CANTIDAD', 'OBSERVACIONES']
        : ['FECHA', 'BLOQUE', 'CAMA', 'VARIEDAD', 'EMPLEADO', '#LINEAS', 'CANTIDAD', 'LOTE', 'PROVEE', 'CONT', 'CLON / OBS'];

    final dataRows = siembras.map((s) {
      final va = variedades.firstWhere(
        (v) => v.id == s.variedadId,
        orElse: () => Variedad(id: 0, codigo: '', nombre: s.variedadId.toString()),
      );
      final ca = camas.firstWhere(
        (c) => c.id == s.camaId,
        orElse: () => Cama(id: 0, cama: s.camaId.toString(), bloque: s.bloqueCodigo ?? '', nave: ''),
      );
      final op = operarios.firstWhere(
        (o) => o.id == s.operarioId,
        orElse: () => Operario(id: 0, cedula: '', nombreCompleto: s.operarioId.toString()),
      );

      final lineasStr = s.lineas != null ? s.lineas.toString() : '-';
      final loteStr = (s.lote != null && s.lote!.isNotEmpty)
          ? s.lote!
          : (va.codigo.isNotEmpty ? va.codigo : '-');
      final proveeStr = (s.proveedor != null && s.proveedor!.isNotEmpty) ? s.proveedor! : '-';
      final contStr = (s.cont != null && s.cont!.isNotEmpty) ? s.cont! : '-';
      final obsesStr = (s.observaciones != null && s.observaciones!.isNotEmpty) ? s.observaciones! : '-';

      if (esLirios) {
        return [
          s.fecha,
          s.bloqueCodigo ?? ca.bloque,
          ca.cama,
          va.nombre,
          op.nombreCompleto,
          loteStr,
          proveeStr,
          contStr,
          formatterNum.format(s.cantidad),
          obsesStr,
        ];
      } else {
        return [
          s.fecha,
          s.bloqueCodigo ?? ca.bloque,
          ca.cama,
          va.nombre,
          op.nombreCompleto,
          lineasStr,
          formatterNum.format(s.cantidad),
          loteStr,
          proveeStr,
          contStr,
          obsesStr,
        ];
      }
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: dataRows,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(
        font: fontBold,
        fontSize: 9,
        color: PdfColors.green900,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE8F5E9),
      ),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFCF8)),
      cellStyle: pw.TextStyle(
        font: fontRegular,
        fontSize: 8.5,
        color: PdfColors.black,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: esLirios
          ? {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.center,
              6: pw.Alignment.centerLeft,
              7: pw.Alignment.center,
              8: pw.Alignment.centerRight,
              9: pw.Alignment.centerLeft,
            }
          : {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
              8: pw.Alignment.centerLeft,
              9: pw.Alignment.center,
              10: pw.Alignment.centerLeft,
            },
    );
  }

  static pw.Widget _buildTotalSummary({
    required int totalTallos,
    required int totalCamas,
    required NumberFormat formatterNum,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF1F8E9),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.green800, width: 1.2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL REGISTROS: $totalCamas CAMAS SEMBRADAS',
            style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.green900),
          ),
          pw.Row(
            children: [
              pw.Text(
                'CANTIDAD TOTAL SEMBRADA: ',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.green900),
              ),
              pw.Text(
                '${formatterNum.format(totalTallos)} TALLOS / BULBOS',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 13,
                  color: PdfColors.green900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTablaRendimientoOperarios({
    required List<Siembra> siembras,
    required List<Operario> operarios,
    List<Variedad>? variedades,
    required NumberFormat formatterNum,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    final rendimientos = RendimientoOperario.calcular(
      siembras: siembras,
      operarios: operarios,
      variedades: variedades,
    );

    if (rendimientos.isEmpty) {
      return pw.SizedBox();
    }

    final headers = [
      'POS',
      'CÉDULA',
      'SEMBRADOR / OPERARIO',
      'CAMAS',
      'TALLOS SEMBRADOS',
      'PROM. TALLOS/CAMA',
      'DÍAS',
      'PROM. TALLOS/DÍA',
      '% RENDIMIENTO',
    ];

    final dataRows = rendimientos.map((r) {
      return [
        '#${r.posicion}',
        r.operario.cedula.isNotEmpty ? r.operario.cedula : '-',
        r.operario.nombreCompleto,
        formatterNum.format(r.totalCamas),
        formatterNum.format(r.totalTallos),
        formatterNum.format(r.promedioTallosPorCama.round()),
        '${r.diasTrabajados}',
        formatterNum.format(r.promedioTallosPorDia.round()),
        '${r.porcentajeTotal.toStringAsFixed(1)}%',
      ];
    }).toList();

    final topSembrador = rendimientos.first;
    final totalTallos = siembras.fold<int>(0, (sum, s) => sum + s.cantidad);
    final promGeneral = rendimientos.isNotEmpty ? (totalTallos / rendimientos.length).round() : 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE8F5E9),
            border: pw.Border(left: pw.BorderSide(color: PdfColors.green800, width: 3.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TABLA DE RENDIMIENTO Y PRODUCTIVIDAD POR SEMBRADOR',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.green900,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'Total Sembradores Activos: ${rendimientos.length}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.green800,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: dataRows,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          headerStyle: pw.TextStyle(
            font: fontBold,
            fontSize: 8.5,
            color: PdfColors.green900,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF1F8E9),
          ),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFCF8)),
          cellStyle: pw.TextStyle(
            font: fontRegular,
            fontSize: 8,
            color: PdfColors.black,
          ),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.center,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.center,
            7: pw.Alignment.centerRight,
            8: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF9FBE7),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.lime800, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LÍDER DE SIEMBRA: ${topSembrador.operario.nombreCompleto} (${formatterNum.format(topSembrador.totalTallos)} tallos | ${topSembrador.porcentajeTotal.toStringAsFixed(1)}% del total)',
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.green900),
              ),
              pw.Text(
                'Promedio General por Sembrador: ${formatterNum.format(promGeneral)} tallos',
                style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Genera un informe PDF exclusivo centrado en el Rendimiento de los Sembradores
  static Future<Uint8List> generarPdfReporteRendimiento({
    required List<Siembra> siembras,
    required List<Operario> operarios,
    List<Variedad>? variedades,
    required String cultivo,
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdf = pw.Document();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final formatterNum = NumberFormat('#,###', 'es_CO');
    final fechaHoy = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    int sumaTotalTallos = 0;
    for (var s in siembras) {
      sumaTotalTallos += s.cantidad;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          cultivo: '$cultivo - RENDIMIENTO',
          semana: semanaReal,
          rangoFechas: rangoFechas,
          fechaHoy: fechaHoy,
          totalRegistros: siembras.length,
          fontBold: fontBold,
          fontRegular: fontRegular,
        ),
        footer: (context) => _buildFooter(context, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildTotalSummary(
            totalTallos: sumaTotalTallos,
            totalCamas: siembras.length,
            formatterNum: formatterNum,
            fontBold: fontBold,
            fontRegular: fontRegular,
          ),
          pw.SizedBox(height: 14),
          _buildTablaRendimientoOperarios(
            siembras: siembras,
            operarios: operarios,
            variedades: variedades,
            formatterNum: formatterNum,
            fontBold: fontBold,
            fontRegular: fontRegular,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Guarda el archivo PDF generado en la carpeta Descargas o Documentos del dispositivo
  static Future<String?> guardarPdfEnDescargas({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    try {
      Directory? dir;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (extDirs != null && extDirs.isNotEmpty) {
            dir = extDirs.first;
          }
        } catch (_) {}

        if (dir == null) {
          try {
            final publicDownload = Directory('/storage/emulated/0/Download');
            if (await publicDownload.exists()) {
              final testFile = File('${publicDownload.path}/.test_tmp');
              await testFile.writeAsString('ok');
              await testFile.delete();
              dir = publicDownload;
            }
          } catch (_) {}
        }

        if (dir == null) {
          try {
            dir = await getExternalStorageDirectory();
          } catch (_) {}
        }
      }

      dir ??= await getApplicationDocumentsDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final nombreLimpio = nombreArchivo.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
      final file = File('${dir.path}/$nombreLimpio');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('[ReporteService] Error guardando PDF en descargas: $e');
    }
    return null;
  }

  /// Abre el servicio de impresión nativo del sistema (Android / Windows / iOS)
  static Future<void> imprimirReporteRendimiento({
    required List<Siembra> siembras,
    required List<Operario> operarios,
    required String cultivo,
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdfBytes = await generarPdfReporteRendimiento(
      siembras: siembras,
      operarios: operarios,
      cultivo: cultivo,
      semana: semanaReal,
      rangoFechas: rangoFechas,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rendimiento_Sembradores_${cultivo}_$semanaReal.pdf',
    );
  }

  /// Comparte o exporta el archivo PDF de rendimiento a través de aplicaciones del sistema (Archivos, WhatsApp, Drive, etc.)
  static Future<void> compartirPdfRendimiento({
    required List<Siembra> siembras,
    required List<Operario> operarios,
    required String cultivo,
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdfBytes = await generarPdfReporteRendimiento(
      siembras: siembras,
      operarios: operarios,
      cultivo: cultivo,
      semana: semanaReal,
      rangoFechas: rangoFechas,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Rendimiento_Sembradores_${cultivo}_$semanaReal.pdf',
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font fontRegular) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount} - Proyecto Siembras Buenavista Flowers',
        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  /// Abre el diálogo nativo del sistema operativo (Android / Windows / iOS) para imprimir directamente
  static Future<void> imprimirReporte({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
    required List<Cama> camas,
    required List<Operario> operarios,
    required String cultivo,
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdfBytes = await generarPdfReporte(
      siembras: siembras,
      variedades: variedades,
      camas: camas,
      operarios: operarios,
      cultivo: cultivo,
      semana: semanaReal,
      rangoFechas: rangoFechas,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Reporte_Siembras_${cultivo}_$semanaReal.pdf',
    );
  }

  /// Comparte o exporta el archivo PDF de siembras a través de aplicaciones del sistema (Archivos, WhatsApp, Drive, etc.)
  static Future<void> compartirPdf({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
    required List<Cama> camas,
    required List<Operario> operarios,
    required String cultivo,
    String? semana,
    String? rangoFechas,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final pdfBytes = await generarPdfReporte(
      siembras: siembras,
      variedades: variedades,
      camas: camas,
      operarios: operarios,
      cultivo: cultivo,
      semana: semanaReal,
      rangoFechas: rangoFechas,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Reporte_Siembras_${cultivo}_$semanaReal.pdf',
    );
  }

  /// Clasifica una siembra en un cultivo canónico según la variedad o las observaciones
  static String clasificarCultivo({
    required Siembra siembra,
    required List<Variedad> variedades,
  }) {
    final va = variedades.firstWhere(
      (v) => v.id == siembra.variedadId,
      orElse: () => Variedad(id: 0, codigo: '', nombre: ''),
    );
    final obs = (siembra.observaciones ?? '').toUpperCase();
    final fam = (va.familiaNombre ?? '').toUpperCase();
    final famId = va.familiaId;

    if (fam.contains('LILIUM') || fam.contains('LIRIO') || obs.contains('LIRIO') || [199, 204, 309, 255].contains(famId)) {
      return 'LIRIOS';
    }
    if (fam.contains('SUNFLOWER') || obs.contains('GIRASOL') || famId == 213) {
      return 'GIRASOL';
    }
    if (fam.contains('MATSUMOTO') || obs.contains('MATSUMOTO') || [114, 118, 262].contains(famId)) {
      return 'MATSUMOTO';
    }
    if (fam.contains('CREMON') || fam.contains('FUJI') || obs.contains('CREMON') || [193, 200, 148].contains(famId)) {
      return 'CREMON';
    }
    if (fam.contains('POMPON') || obs.contains('POMPON') || famId == 147) {
      return 'POMPON';
    }
    if (fam.isNotEmpty) {
      return fam;
    }
    return 'OTROS';
  }

  /// Agrupa una lista de siembras por su cultivo canónico
  static Map<String, List<Siembra>> agruparSiembrasPorCultivo({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
  }) {
    final Map<String, List<Siembra>> agrupados = {};
    for (var s in siembras) {
      final c = clasificarCultivo(siembra: s, variedades: variedades);
      agrupados.putIfAbsent(c, () => []).add(s);
    }
    return agrupados;
  }

  /// Genera y guarda en Descargas un PDF independiente para cada cultivo que tenga siembras
  static Future<Map<String, String>> guardarPdfsSeparadosPorCultivo({
    required List<Siembra> siembras,
    required List<Variedad> variedades,
    required List<Cama> camas,
    required List<Operario> operarios,
    String? semana,
    String? rangoFechas,
    bool esRendimiento = false,
  }) async {
    final semanaReal = _resolverSemana(semana);
    final agrupados = agruparSiembrasPorCultivo(siembras: siembras, variedades: variedades);
    final Map<String, String> resultados = {};

    for (var entry in agrupados.entries) {
      final cult = entry.key;
      final listaCultivo = entry.value;
      if (listaCultivo.isEmpty) continue;

      Uint8List bytes;
      String nombreBase;
      if (esRendimiento) {
        bytes = await generarPdfReporteRendimiento(
          siembras: listaCultivo,
          operarios: operarios,
          cultivo: cult,
          semana: semanaReal,
          rangoFechas: rangoFechas,
        );
        nombreBase = 'Rendimiento_Sembradores_${cult}_${semanaReal.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
      } else {
        bytes = await generarPdfReporte(
          siembras: listaCultivo,
          variedades: variedades,
          camas: camas,
          operarios: operarios,
          cultivo: cult,
          semana: semanaReal,
          rangoFechas: rangoFechas,
        );
        nombreBase = 'Reporte_Siembras_${cult}_${semanaReal.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
      }

      final ruta = await guardarPdfEnDescargas(bytes: bytes, nombreArchivo: nombreBase);
      if (ruta != null) {
        resultados[cult] = ruta;
      }
    }
    return resultados;
  }
}


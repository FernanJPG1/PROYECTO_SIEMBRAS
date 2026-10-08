// ============================================================================
// ARCHIVO: reporte_dialog.dart
// ¿QUÉ ES ESTA VENTANA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta ventana es EL CENTRO DE IMPRESIÓN Y FOTOCOPIADO DE LA FINCA.
//
// Cuando el supervisor necesita sacar las hojas oficiales para mandar a la gerencia,
// abre esta ventana para elegir cómo quiere su informe:
// 1. ¿De qué flor? (Todas juntas, solo Pompón, solo Lirios, solo Girasoles, etc.).
// 2. ¿De qué fecha o semana? (Semana #40, o de lunes a viernes).
// 3. ¿En hojas separadas? (Opción de separar cada flor en su propia página).
//
// Al tocar 'Generar PDF', la máquina digital fabrica el documento membretado
// y lo abre en pantalla grande para revisarlo y mandarlo por WhatsApp.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/reporte_service.dart';
import 'package:app_movil/screens/rendimiento_dialog.dart';
import 'package:app_movil/screens/pdf_viewer_screen.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';

class ReporteDialog extends StatefulWidget {
  final List<Siembra> siembras;
  final List<Variedad> variedades;
  final List<Cama> camas;
  final List<Operario> operarios;

  const ReporteDialog({
    super.key,
    required this.siembras,
    required this.variedades,
    required this.camas,
    required this.operarios,
  });

  @override
  State<ReporteDialog> createState() => _ReporteDialogState();
}

class _ReporteDialogState extends State<ReporteDialog> {
  String _cultivoSeleccionado = 'TODOS';
  late final TextEditingController _semanaController;
  DateTimeRange? _rangoFechas;
  bool _generando = false;
  int _anioSemanas = DateTime.now().year;
  bool _separarPorCultivo = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final semActual = CalendarioUtil.obtenerSemanaUS(now);
    final rangoActual = CalendarioUtil.obtenerRangoFechasSemanaUS(now.year, semActual);

    // Verificar si hay registros en la semana actual
    final hayEnSemanaActual = widget.siembras.any((s) {
      final f = CalendarioUtil.parsearFecha(s.fecha);
      if (f == null) return false;
      return !f.isBefore(rangoActual.start) && !f.isAfter(rangoActual.end);
    });

    if (hayEnSemanaActual || widget.siembras.isEmpty) {
      _semanaController = TextEditingController(text: 'Semana #$semActual - ${now.year}');
      _rangoFechas = rangoActual;
    } else {
      // Si la semana actual no tiene datos pero hay registros, buscar la más reciente
      DateTime? ultimaFecha;
      for (final s in widget.siembras) {
        final f = CalendarioUtil.parsearFecha(s.fecha);
        if (f != null) {
          if (ultimaFecha == null || f.isAfter(ultimaFecha)) {
            ultimaFecha = f;
          }
        }
      }
      if (ultimaFecha != null) {
        final semUltima = CalendarioUtil.obtenerSemanaUS(ultimaFecha);
        _anioSemanas = ultimaFecha.year;
        _semanaController = TextEditingController(text: 'Semana #$semUltima - ${ultimaFecha.year}');
        _rangoFechas = CalendarioUtil.obtenerRangoFechasSemanaUS(ultimaFecha.year, semUltima);
      } else {
        _semanaController = TextEditingController(text: 'Todas las Semanas');
        _rangoFechas = null;
      }
    }
  }

  @override
  void dispose() {
    _semanaController.dispose();
    super.dispose();
  }

  final List<String> _opcionesCultivo = [
    'TODOS',
    'LIRIOS',
    'GIRASOL',
    'MATSUMOTO',
    'CREMON',
    'POMPON',
  ];

  List<Siembra> _filtrarSiembras() {
    return widget.siembras.where((s) {
      // Filtro por cultivo
      if (_cultivoSeleccionado != 'TODOS') {
        final c = ReporteService.clasificarCultivo(siembra: s, variedades: widget.variedades);
        if (c != _cultivoSeleccionado) return false;
      }

      // Filtro por fecha si hay rango seleccionado
      if (_rangoFechas != null) {
        try {
          final f = CalendarioUtil.parsearFecha(s.fecha);
          if (f != null) {
            final fDate = DateTime(f.year, f.month, f.day);
            final ini = DateTime(_rangoFechas!.start.year, _rangoFechas!.start.month, _rangoFechas!.start.day);
            final fin = DateTime(_rangoFechas!.end.year, _rangoFechas!.end.month, _rangoFechas!.end.day, 23, 59, 59);
            if (fDate.isBefore(ini) || fDate.isAfter(fin)) {
              return false;
            }
          }
        } catch (_) {}
      }

      return true;
    }).toList();
  }

  Future<void> _seleccionarRangoFechas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _rangoFechas,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7CB342),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _rangoFechas = picked;
        final semInicio = CalendarioUtil.obtenerSemanaUS(picked.start);
        final semFin = CalendarioUtil.obtenerSemanaUS(picked.end);
        if (semInicio == semFin) {
          _semanaController.text = 'Semana #$semInicio - ${picked.start.year}';
        } else {
          _semanaController.text = 'Semana #$semInicio a #$semFin - ${picked.start.year}';
        }
      });
    }
  }

  void _seleccionarSemanaUS() {
    final semanas = CalendarioUtil.obtenerListaSemanasDelAnio(_anioSemanas);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (Responsive.isLandscape(context) ? 0.90 : 0.75),
            maxWidth: 600,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, color: Color(0xFF558B2F)),
                      SizedBox(width: 8),
                      Text(
                        'Semanas Calendario EE. UU.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF33691E)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.all_inclusive, size: 16, color: Color(0xFF558B2F)),
                        label: const Text('Todo el Historial', style: TextStyle(color: Color(0xFF558B2F), fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _semanaController.text = 'Todas las Semanas';
                            _rangoFechas = null;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.today, size: 16, color: Color(0xFF558B2F)),
                        label: const Text('Semana Actual', style: TextStyle(color: Color(0xFF558B2F), fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          final now = DateTime.now();
                          final sem = CalendarioUtil.obtenerSemanaUS(now);
                          final r = CalendarioUtil.obtenerRangoFechasSemanaUS(now.year, sem);
                          setState(() {
                            _semanaController.text = 'Semana #$sem - ${now.year}';
                            _rangoFechas = r;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                itemCount: semanas.length,
                itemBuilder: (c, idx) {
                  final item = semanas[idx];
                  final semNum = item['semana'] as int;
                  final r = item['rango'] as DateTimeRange;
                  final now = DateTime.now();
                  final esActual = (now.year == _anioSemanas && CalendarioUtil.obtenerSemanaUS(now) == semNum);

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: esActual ? const Color(0xFF558B2F) : const Color(0xFFF1F8E9),
                      child: Text(
                        '$semNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: esActual ? Colors.white : const Color(0xFF33691E),
                        ),
                      ),
                    ),
                    title: Text(
                      item['etiquetaCompleta'] as String,
                      style: TextStyle(
                        fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                        color: esActual ? const Color(0xFF33691E) : Colors.black87,
                      ),
                    ),
                    trailing: esActual
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCEDC8), borderRadius: BorderRadius.circular(6)),
                            child: const Text('ACTUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF33691E))),
                          )
                        : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        _semanaController.text = 'Semana #$semNum - $_anioSemanas';
                        _rangoFechas = r;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _verPdf() {
    final filtradas = _filtrarSiembras();
    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra que coincidan con los filtros seleccionados.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final semanaTexto = _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim();
    final rangoTexto = _rangoFechas != null
        ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
        : null;

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS') {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: filtradas,
        variedades: widget.variedades,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        final nombreLimpio = 'Reporte_Siembras_${cultUnico}_${semanaTexto.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              titulo: 'Reporte - $cultUnico',
              nombreArchivo: nombreLimpio,
              generadorPdf: () => ReporteService.generarPdfReporte(
                siembras: agrupados[cultUnico]!,
                variedades: widget.variedades,
                camas: widget.camas,
                operarios: widget.operarios,
                cultivo: cultUnico,
                semana: semanaTexto,
                rangoFechas: rangoTexto,
              ),
            ),
          ),
        );
      } else {
        _mostrarSelectorCultivoVisualizar(agrupados, semanaTexto, rangoTexto);
      }
      return;
    }

    final nombreLimpio = 'Reporte_Siembras_${_cultivoSeleccionado}_${semanaTexto.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          titulo: 'Reporte - $_cultivoSeleccionado',
          nombreArchivo: nombreLimpio,
          generadorPdf: () => ReporteService.generarPdfReporte(
            siembras: filtradas,
            variedades: widget.variedades,
            camas: widget.camas,
            operarios: widget.operarios,
            cultivo: _cultivoSeleccionado,
            semana: semanaTexto,
            rangoFechas: rangoTexto,
          ),
        ),
      ),
    );
  }

  void _mostrarSelectorCultivoVisualizar(
    Map<String, List<Siembra>> agrupados,
    String semanaTexto,
    String? rangoTexto,
  ) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Visualizar por Cultivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo que desea previsualizar:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
              ...agrupados.entries.map((entry) {
                final cult = entry.key;
                final list = entry.value;
                final tallos = list.fold<int>(0, (sum, s) => sum + s.cantidad);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(cult.substring(0, cult.length >= 2 ? 2 : 1), style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${list.length} camas • ${fNum.format(tallos)} tallos', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF2E7D32)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final nombreLimpio = 'Reporte_Siembras_${cult}_${semanaTexto.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            titulo: 'Reporte - $cult',
                            nombreArchivo: nombreLimpio,
                            generadorPdf: () => ReporteService.generarPdfReporte(
                              siembras: list,
                              variedades: widget.variedades,
                              camas: widget.camas,
                              operarios: widget.operarios,
                              cultivo: cult,
                              semana: semanaTexto,
                              rangoFechas: rangoTexto,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarPdfDescargas() async {
    final filtradas = _filtrarSiembras();
    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra que coincidan con los filtros seleccionados.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _generando = true);

    try {
      final semanaTexto = _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim();
      final rangoTexto = _rangoFechas != null
          ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
          : null;

      if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS') {
        final resultados = await ReporteService.guardarPdfsSeparadosPorCultivo(
          siembras: filtradas,
          variedades: widget.variedades,
          camas: widget.camas,
          operarios: widget.operarios,
          semana: semanaTexto,
          rangoFechas: rangoTexto,
          esRendimiento: false,
        );

        if (!mounted) return;
        if (resultados.isNotEmpty) {
          final nombres = resultados.keys.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Se guardaron ${resultados.length} PDFs por cultivo en Descargas:\n$nombres'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudieron guardar los reportes por cultivo'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final pdfBytes = await ReporteService.generarPdfReporte(
        siembras: filtradas,
        variedades: widget.variedades,
        camas: widget.camas,
        operarios: widget.operarios,
        cultivo: _cultivoSeleccionado,
        semana: semanaTexto,
        rangoFechas: rangoTexto,
      );

      final nombreLimpio = 'Reporte_Siembras_${_cultivoSeleccionado}_${semanaTexto.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
      final ruta = await ReporteService.guardarPdfEnDescargas(
        bytes: pdfBytes,
        nombreArchivo: nombreLimpio,
      );

      if (!mounted) return;
      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Archivo PDF generado y guardado en Descargas:\n$nombreLimpio'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        await ReporteService.compartirPdf(
          siembras: filtradas,
          variedades: widget.variedades,
          camas: widget.camas,
          operarios: widget.operarios,
          cultivo: _cultivoSeleccionado,
          semana: semanaTexto,
          rangoFechas: rangoTexto,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _exportarPdf() async {
    final filtradas = _filtrarSiembras();
    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra que coincidan con los filtros seleccionados.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final semanaTexto = _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim();
    final rangoTexto = _rangoFechas != null
        ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
        : null;

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS') {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: filtradas,
        variedades: widget.variedades,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        setState(() => _generando = true);
        try {
          await ReporteService.compartirPdf(
            siembras: agrupados[cultUnico]!,
            variedades: widget.variedades,
            camas: widget.camas,
            operarios: widget.operarios,
            cultivo: cultUnico,
            semana: semanaTexto,
            rangoFechas: rangoTexto,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al compartir PDF: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _generando = false);
        }
      } else {
        _mostrarSelectorCultivoCompartir(agrupados, semanaTexto, rangoTexto);
      }
      return;
    }

    setState(() => _generando = true);

    try {
      await ReporteService.compartirPdf(
        siembras: filtradas,
        variedades: widget.variedades,
        camas: widget.camas,
        operarios: widget.operarios,
        cultivo: _cultivoSeleccionado,
        semana: semanaTexto,
        rangoFechas: rangoTexto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _mostrarSelectorCultivoCompartir(
    Map<String, List<Siembra>> agrupados,
    String semanaTexto,
    String? rangoTexto,
  ) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Compartir por Cultivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo que desea compartir:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
              ...agrupados.entries.map((entry) {
                final cult = entry.key;
                final list = entry.value;
                final tallos = list.fold<int>(0, (sum, s) => sum + s.cantidad);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(cult.substring(0, cult.length >= 2 ? 2 : 1), style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${list.length} camas • ${fNum.format(tallos)} tallos', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.share, color: Color(0xFF2E7D32), size: 20),
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _generando = true);
                      try {
                        await ReporteService.compartirPdf(
                          siembras: list,
                          variedades: widget.variedades,
                          camas: widget.camas,
                          operarios: widget.operarios,
                          cultivo: cult,
                          semana: semanaTexto,
                          rangoFechas: rangoTexto,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al compartir $cult: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _generando = false);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirPdf() async {
    final filtradas = _filtrarSiembras();
    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra que coincidan con los filtros seleccionados.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final semanaTexto = _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim();
    final rangoTexto = _rangoFechas != null
        ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
        : null;

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS') {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: filtradas,
        variedades: widget.variedades,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        setState(() => _generando = true);
        try {
          await ReporteService.imprimirReporte(
            siembras: agrupados[cultUnico]!,
            variedades: widget.variedades,
            camas: widget.camas,
            operarios: widget.operarios,
            cultivo: cultUnico,
            semana: semanaTexto,
            rangoFechas: rangoTexto,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al enviar a impresión: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _generando = false);
        }
      } else {
        _mostrarSelectorCultivoImprimir(agrupados, semanaTexto, rangoTexto);
      }
      return;
    }

    setState(() => _generando = true);

    try {
      await ReporteService.imprimirReporte(
        siembras: filtradas,
        variedades: widget.variedades,
        camas: widget.camas,
        operarios: widget.operarios,
        cultivo: _cultivoSeleccionado,
        semana: semanaTexto,
        rangoFechas: rangoTexto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar a impresión: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _mostrarSelectorCultivoImprimir(
    Map<String, List<Siembra>> agrupados,
    String semanaTexto,
    String? rangoTexto,
  ) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Imprimir por Cultivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo que desea enviar a impresión:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
              ...agrupados.entries.map((entry) {
                final cult = entry.key;
                final list = entry.value;
                final tallos = list.fold<int>(0, (sum, s) => sum + s.cantidad);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(cult.substring(0, cult.length >= 2 ? 2 : 1), style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${list.length} camas • ${fNum.format(tallos)} tallos', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.print, color: Color(0xFF2E7D32), size: 20),
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _generando = true);
                      try {
                        await ReporteService.imprimirReporte(
                          siembras: list,
                          variedades: widget.variedades,
                          camas: widget.camas,
                          operarios: widget.operarios,
                          cultivo: cult,
                          semana: semanaTexto,
                          rangoFechas: rangoTexto,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al imprimir $cult: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _generando = false);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorSemanaWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Semana (EE. UU.):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
            ),
            InkWell(
              onTap: _seleccionarSemanaUS,
              child: const Text(
                'Elegir semana',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF558B2F), decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _seleccionarSemanaUS,
          child: TextFormField(
            controller: _semanaController,
            enabled: false,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
            decoration: InputDecoration(
              hintText: 'Ej: Semana #40',
              suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF558B2F)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF9FBE7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC5E1A5)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorRangoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtro por Rango (Opcional):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _seleccionarRangoFechas,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Color(0xFF7CB342), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rangoFechas != null
                        ? '${DateFormat('dd/MM').format(_rangoFechas!.start)} - ${DateFormat('dd/MM').format(_rangoFechas!.end)}'
                        : 'Todas las fechas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _rangoFechas != null ? FontWeight.bold : FontWeight.normal,
                      color: _rangoFechas != null ? const Color(0xFF33691E) : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_rangoFechas != null)
                  GestureDetector(
                    onTap: () => setState(() => _rangoFechas = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtrarSiembras();
    final formatterNum = NumberFormat('#,###', 'es_CO');
    int totalTallos = 0;
    for (var s in filtradas) {
      totalTallos += s.cantidad;
    }

    final esMovil = Responsive.isMobile(context);
    final dialogMaxW = Responsive.dialogMaxWidth(context);
    final dialogMaxH = MediaQuery.sizeOf(context).height * (esMovil ? 0.94 : 0.90);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: esMovil ? 10 : 24,
        vertical: esMovil ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxW.clamp(320.0, 620.0),
          maxHeight: dialogMaxH,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(esMovil ? 14 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Encabezado del Diálogo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Color(0xFF33691E), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generar Reporte en PDF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Formato oficial Buenavista Flowers (Archivo PDF Digital)',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Selector 1: Tipo de Cultivo
            const Text(
              'Seleccione el Cultivo para el Reporte PDF:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF33691E)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _opcionesCultivo.map((c) {
                final isSelected = _cultivoSeleccionado == c;
                return ChoiceChip(
                  label: Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? Colors.white : const Color(0xFF33691E),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF7CB342),
                  backgroundColor: const Color(0xFFF1F8E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val) setState(() => _cultivoSeleccionado = c);
                  },
                );
              }).toList(),
            ),

            if (_cultivoSeleccionado == 'TODOS') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _separarPorCultivo ? const Color(0xFFE8F5E9) : const Color(0xFFF9FBE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _separarPorCultivo ? const Color(0xFF81C784) : const Color(0xFFC5E1A5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _separarPorCultivo ? Icons.folder_copy : Icons.file_copy_outlined,
                      color: _separarPorCultivo ? const Color(0xFF2E7D32) : const Color(0xFF558B2F),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Separar reporte por cultivo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _separarPorCultivo ? const Color(0xFF1B5E20) : const Color(0xFF33691E),
                            ),
                          ),
                          Text(
                            _separarPorCultivo
                                ? 'Genera archivos PDF individuales (uno por flor: Pompón, Lirios, etc.)'
                                : 'Genera un único archivo consolidado con todos los cultivos juntos',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _separarPorCultivo,
                      activeThumbColor: const Color(0xFF2E7D32),
                      onChanged: (val) => setState(() => _separarPorCultivo = val),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Selector 2: Semana y Rango de Fechas (Calendario EE. UU.)
            if (esMovil) ...[
              _buildSelectorSemanaWidget(),
              const SizedBox(height: 10),
              _buildSelectorRangoWidget(),
            ] else ...[
              Row(
                children: [
                  Expanded(flex: 3, child: _buildSelectorSemanaWidget()),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: _buildSelectorRangoWidget()),
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (filtradas.isEmpty && widget.siembras.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No hay registros para este filtro (${widget.siembras.length} siembras en total).',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          _cultivoSeleccionado = 'TODOS';
                          _rangoFechas = null;
                          _semanaController.text = 'Todas las Semanas';
                        });
                      },
                      child: const Text('Ver Todo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2E7D32))),
                    ),
                  ],
                ),
              ),
            ],

            // Resumen previo de datos
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC5E1A5)),
              ),
              child: esMovil
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Color(0xFF558B2F), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Camas en el reporte: ${filtradas.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${formatterNum.format(totalTallos)} tallos',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Color(0xFF558B2F), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Camas en el reporte: ${filtradas.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
                            ),
                          ],
                        ),
                        Text(
                          'Total: ${formatterNum.format(totalTallos)} tallos',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 12),

            // Card Resumen de Rendimiento de Sembradores
            Builder(
              builder: (ctx) {
                final rendimientos = RendimientoOperario.calcular(
                  siembras: filtradas,
                  operarios: widget.operarios,
                  variedades: widget.variedades,
                );

                if (rendimientos.isEmpty) {
                  return const SizedBox();
                }

                final top = rendimientos.first;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFF59D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9C4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFD54F)),
                            ),
                            child: const Icon(Icons.leaderboard, color: Color(0xFFF57F17), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rendimiento: ${rendimientos.length} sembradores',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF795548)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RendimientoDialog(
                                  siembras: filtradas,
                                  operarios: widget.operarios,
                                  variedades: widget.variedades,
                                  camas: widget.camas,
                                  cultivo: _cultivoSeleccionado,
                                  semana: _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim(),
                                  rangoFechas: _rangoFechas != null
                                      ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
                                      : null,
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Ver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF57F17))),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward, size: 14, color: Color(0xFFF57F17)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🥇 Líder: ${top.operario.nombreCompleto} (${formatterNum.format(top.totalTallos)} tallos | ${top.porcentajeTotal.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // Botones de Acción
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.leaderboard, size: 18, color: Color(0xFFF57F17)),
                  label: const Text('Rendimiento', style: TextStyle(color: Color(0xFFF57F17), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFB300)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RendimientoDialog(
                        siembras: filtradas,
                        operarios: widget.operarios,
                        variedades: widget.variedades,
                        camas: widget.camas,
                        cultivo: _cultivoSeleccionado,
                        semana: _semanaController.text.trim().isEmpty ? 'Semana General' : _semanaController.text.trim(),
                        rangoFechas: _rangoFechas != null
                            ? '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'
                            : null,
                      ),
                    );
                  },
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 17),
                      label: const Text('Guardar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF558B2F),
                        side: const BorderSide(color: Color(0xFF7CB342)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _generando ? null : _guardarPdfDescargas,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.share, size: 17),
                      label: const Text('Compartir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF558B2F),
                        side: const BorderSide(color: Color(0xFF7CB342)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _generando ? null : _exportarPdf,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print, size: 17),
                      label: const Text('Imprimir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF558B2F),
                        side: const BorderSide(color: Color(0xFF7CB342)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _generando ? null : _imprimirPdf,
                    ),
                    ElevatedButton.icon(
                      icon: _generando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.visibility, color: Colors.white, size: 17),
                      label: Text(
                        _generando ? 'Generando...' : 'Ver PDF',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: _generando ? null : _verPdf,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/reporte_service.dart';
import 'package:app_movil/screens/rendimiento_dialog.dart';

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
  final TextEditingController _semanaController = TextEditingController(text: 'Semana #38');
  DateTimeRange? _rangoFechas;
  bool _generando = false;

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
        final va = widget.variedades.firstWhere(
          (v) => v.id == s.variedadId,
          orElse: () => Variedad(id: 0, codigo: '', nombre: ''),
        );
        final nombreCult = _cultivoSeleccionado.toUpperCase();
        final obs = (s.observaciones ?? '').toUpperCase();
        final fam = (va.familiaNombre ?? '').toUpperCase();

        bool coincide = false;
        if (nombreCult == 'LIRIOS') {
          coincide = fam.contains('LILIUM') || fam.contains('LIRIO') || obs.contains('LIRIO') || [199, 204, 309, 255].contains(va.familiaId);
        } else if (nombreCult == 'GIRASOL') {
          coincide = fam.contains('SUNFLOWER') || obs.contains('GIRASOL') || va.familiaId == 213;
        } else if (nombreCult == 'MATSUMOTO') {
          coincide = fam.contains('MATSUMOTO') || obs.contains('MATSUMOTO') || [114, 118, 262].contains(va.familiaId);
        } else if (nombreCult == 'CREMON') {
          coincide = fam.contains('CREMON') || fam.contains('FUJI') || obs.contains('CREMON') || [193, 200, 148].contains(va.familiaId);
        } else if (nombreCult == 'POMPON') {
          coincide = (fam.contains('POMPON') || obs.contains('POMPON') || va.familiaId == 147) &&
              !fam.contains('CREMON') && !obs.contains('CREMON');
        }

        if (!coincide) return false;
      }

      // Filtro por fecha si hay rango seleccionado
      if (_rangoFechas != null) {
        try {
          DateTime f;
          if (s.fecha.contains('/')) {
            final p = s.fecha.split('/');
            f = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
          } else {
            f = DateTime.parse(s.fecha);
          }
          if (f.isBefore(_rangoFechas!.start) || f.isAfter(_rangoFechas!.end.add(const Duration(days: 1)))) {
            return false;
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
      setState(() => _rangoFechas = picked);
    }
  }

  Future<void> _ejecutarAccion({required bool compartir}) async {
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

      if (compartir) {
        await ReporteService.compartirPdf(
          siembras: filtradas,
          variedades: widget.variedades,
          camas: widget.camas,
          operarios: widget.operarios,
          cultivo: _cultivoSeleccionado,
          semana: semanaTexto,
          rangoFechas: rangoTexto,
        );
      } else {
        await ReporteService.imprimirReporte(
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
        SnackBar(content: Text('Error al generar reporte: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtrarSiembras();
    final formatterNum = NumberFormat('#,###', 'es_CO');
    int totalTallos = 0;
    for (var s in filtradas) {
      totalTallos += s.cantidad;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(22),
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
                  child: const Icon(Icons.print, color: Color(0xFF33691E), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generar e Imprimir Reporte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Formato oficial Buenavista Flowers (PDF / Impresora)',
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
              'Seleccione el Cultivo a Imprimir:',
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

            const SizedBox(height: 14),

            // Selector 2: Semana y Rango de Fechas
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Número de Semana:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _semanaController,
                        decoration: InputDecoration(
                          hintText: 'Ej: Semana #38',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF9FBE7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
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
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Resumen previo de datos
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC5E1A5)),
              ),
              child: Row(
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD54F)),
                        ),
                        child: const Icon(Icons.leaderboard, color: Color(0xFFF57F17), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Rendimiento: ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF795548)),
                                ),
                                Text(
                                  '${rendimientos.length} sembradores evaluados',
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '🥇 Líder: ${top.operario.nombreCompleto} (${formatterNum.format(top.totalTallos)} tallos | ${top.porcentajeTotal.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFFF57F17)),
                        label: const Text('Ver Detalle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF57F17))),
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
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // Botones de Acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.leaderboard, size: 18, color: Color(0xFFF57F17)),
                  label: const Text('Rendimiento', style: TextStyle(color: Color(0xFFF57F17))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFB300)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Compartir PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF558B2F),
                        side: const BorderSide(color: Color(0xFF7CB342)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _generando ? null : () => _ejecutarAccion(compartir: true),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: _generando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.print, color: Colors.white, size: 20),
                      label: Text(
                        _generando ? 'Generando...' : 'Imprimir Reporte',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7CB342),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: _generando ? null : () => _ejecutarAccion(compartir: false),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

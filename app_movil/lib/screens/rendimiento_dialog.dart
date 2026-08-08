import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/reporte_service.dart';

class RendimientoDialog extends StatefulWidget {
  final List<Siembra> siembras;
  final List<Operario> operarios;
  final List<Variedad>? variedades;
  final List<Cama>? camas;
  final String cultivo;
  final String semana;
  final String? rangoFechas;

  const RendimientoDialog({
    super.key,
    required this.siembras,
    required this.operarios,
    this.variedades,
    this.camas,
    this.cultivo = 'TODOS',
    this.semana = 'Semana #38',
    this.rangoFechas,
  });

  @override
  State<RendimientoDialog> createState() => _RendimientoDialogState();
}

class _RendimientoDialogState extends State<RendimientoDialog> {
  String _filtroTexto = '';
  String _orden = 'TALLOS'; // 'TALLOS', 'CAMAS', 'PROMEDIO', 'NOMBRE'
  bool _generando = false;

  @override
  Widget build(BuildContext context) {
    final formatterNum = NumberFormat('#,###', 'es_CO');
    var rendimientos = RendimientoOperario.calcular(
      siembras: widget.siembras,
      operarios: widget.operarios,
    );

    // Filtrar por texto si hay búsqueda
    if (_filtroTexto.isNotEmpty) {
      final q = _filtroTexto.toLowerCase();
      rendimientos = rendimientos.where((r) {
        return r.operario.nombreCompleto.toLowerCase().contains(q) ||
            r.operario.cedula.contains(q);
      }).toList();
    }

    // Ordenamiento dinámico
    if (_orden == 'CAMAS') {
      rendimientos.sort((a, b) => b.totalCamas.compareTo(a.totalCamas));
    } else if (_orden == 'PROMEDIO') {
      rendimientos.sort((a, b) => b.promedioTallosPorCama.compareTo(a.promedioTallosPorCama));
    } else if (_orden == 'NOMBRE') {
      rendimientos.sort((a, b) => a.operario.nombreCompleto.compareTo(b.operario.nombreCompleto));
    } else {
      // Default: TALLOS
      rendimientos.sort((a, b) => b.totalTallos.compareTo(a.totalTallos));
    }

    final totalTallosGlobal = widget.siembras.fold<int>(0, (sum, s) => sum + s.cantidad);
    final totalCamasGlobal = widget.siembras.length;
    final promPorSembrador = rendimientos.isNotEmpty
        ? (totalTallosGlobal / rendimientos.length).round()
        : 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC5E1A5)),
                    ),
                    child: const Icon(Icons.leaderboard, color: Color(0xFF33691E), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rendimiento de Sembradores',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        Text(
                          'Métricas de productividad y ranking por operario | ${widget.cultivo}',
                          style: const TextStyle(fontSize: 12.5, color: Colors.grey),
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
              const Divider(height: 22),

              // KPI Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.people_alt,
                      label: 'Sembradores Activos',
                      value: '${rendimientos.length}',
                      color: const Color(0xFF33691E),
                      bg: const Color(0xFFF1F8E9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.grass,
                      label: 'Total Tallos Sembrados',
                      value: formatterNum.format(totalTallosGlobal),
                      color: const Color(0xFF2E7D32),
                      bg: const Color(0xFFE8F5E9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.view_week,
                      label: 'Total Camas',
                      value: formatterNum.format(totalCamasGlobal),
                      color: const Color(0xFF00796B),
                      bg: const Color(0xFFE0F2F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.speed,
                      label: 'Promedio / Sembrador',
                      value: '${formatterNum.format(promPorSembrador)} tallos',
                      color: const Color(0xFFEF6C00),
                      bg: const Color(0xFFFFF3E0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Buscador y Selector de Ordenamiento
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar sembrador por nombre o cédula...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF7CB342)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF9FBE7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFC5E1A5)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _filtroTexto = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _orden,
                    dropdownColor: Colors.white,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'TALLOS', child: Text('Más Tallos Sembrados')),
                      DropdownMenuItem(value: 'CAMAS', child: Text('Más Camas')),
                      DropdownMenuItem(value: 'PROMEDIO', child: Text('Mejor Promedio/Cama')),
                      DropdownMenuItem(value: 'NOMBRE', child: Text('Nombre (A-Z)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _orden = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de Sembradores con Rendimiento
              Expanded(
                child: rendimientos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'No se encontraron sembradores para este período o filtro.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: rendimientos.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final r = rendimientos[index];
                          final esTop1 = r.posicion == 1;
                          final esTop2 = r.posicion == 2;
                          final esTop3 = r.posicion == 3;

                          Color posColor = const Color(0xFF558B2F);
                          Color posBg = const Color(0xFFF1F8E9);
                          String medal = '';
                          if (esTop1) {
                            posColor = const Color(0xFFF57F17);
                            posBg = const Color(0xFFFFF9C4);
                            medal = '🥇';
                          } else if (esTop2) {
                            posColor = const Color(0xFF546E7A);
                            posBg = const Color(0xFFECEFF1);
                            medal = '🥈';
                          } else if (esTop3) {
                            posColor = const Color(0xFF8D6E63);
                            posBg = const Color(0xFFEFEBE9);
                            medal = '🥉';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: esTop1 ? const Color(0xFFFCFDF9) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: esTop1
                                    ? const Color(0xFFFFD54F)
                                    : Colors.grey.shade300,
                                width: esTop1 ? 1.8 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Badge Posición
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: posBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: posColor, width: 1.5),
                                  ),
                                  child: Text(
                                    medal.isNotEmpty ? medal : '#${r.posicion}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: medal.isNotEmpty ? 18 : 13,
                                      color: posColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nombre y Cédula
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.operario.nombreCompleto,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: Color(0xFF263238),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cédula: ${r.operario.cedula.isNotEmpty ? r.operario.cedula : "S/C"} | ${r.diasTrabajados} días activos',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),

                                // Métricas de rendimiento
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${formatterNum.format(r.totalTallos)} tallos',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                          Text(
                                            '${r.porcentajeTotal.toStringAsFixed(1)}% del total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (r.porcentajeTotal / 100).clamp(0.0, 1.0),
                                          minHeight: 7,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            esTop1
                                                ? const Color(0xFFFBC02D)
                                                : const Color(0xFF7CB342),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${r.totalCamas} camas',
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                                          Text(
                                            'Prom: ${formatterNum.format(r.promedioTallosPorCama.round())} tallos/cama',
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                                          Text(
                                            '${formatterNum.format(r.promedioTallosPorDia.round())} t/día',
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Botones de Acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Evaluación generada con ${widget.siembras.length} registros',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Compartir PDF Rendimiento'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF558B2F),
                          side: const BorderSide(color: Color(0xFF7CB342)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generando ? null : () => _exportarRendimiento(compartir: true),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: _generando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.print, color: Colors.white, size: 19),
                        label: Text(
                          _generando ? 'Generando...' : 'Imprimir Rendimiento',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7CB342),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generando ? null : () => _exportarRendimiento(compartir: false),
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

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarRendimiento({required bool compartir}) async {
    setState(() => _generando = true);
    try {
      if (compartir) {
        await ReporteService.compartirPdfRendimiento(
          siembras: widget.siembras,
          operarios: widget.operarios,
          cultivo: widget.cultivo,
          semana: widget.semana,
          rangoFechas: widget.rangoFechas,
        );
      } else {
        await ReporteService.imprimirReporteRendimiento(
          siembras: widget.siembras,
          operarios: widget.operarios,
          cultivo: widget.cultivo,
          semana: widget.semana,
          rangoFechas: widget.rangoFechas,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar PDF de rendimiento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }
}

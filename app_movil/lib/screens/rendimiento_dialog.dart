// ============================================================================
// ARCHIVO: rendimiento_dialog.dart
// ¿QUÉ ES ESTA VENTANA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta ventana es EL CUADERNO DE NÓMINA Y PREMIACIÓN DE LOS TRABAJADORES.
//
// Al final de la semana, el administrador abre esta ventana para:
// 1. 🥇 Ver el podio de sembradores: Ordena a los trabajadores de mayor a menor
//    según la cantidad de tallos sembrados.
// 2. 📊 Totalizar por persona: Cuántas camas hizo, cuántos tallos logró y su promedio diario.
// 3. 📄 Imprimir el Informe de Nómina en PDF: Para entregarlo a contabilidad y que
//    se pague a cada persona exactamente lo que trabajó, con transparencia total.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/reporte_service.dart';
import 'package:app_movil/screens/pdf_viewer_screen.dart';
import 'package:app_movil/screens/rendimiento_lirios_screen.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';

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
    this.semana = '',
    this.rangoFechas,
  });

  @override
  State<RendimientoDialog> createState() => _RendimientoDialogState();
}

class _RendimientoDialogState extends State<RendimientoDialog> {
  String _filtroTexto = '';
  String _orden = 'TALLOS'; // 'TALLOS', 'CAMAS', 'PROMEDIO', 'NOMBRE'
  bool _generando = false;
  late String _semanaActual;
  late String _cultivoSeleccionado;
  bool _separarPorCultivo = false;

  final List<String> _opcionesCultivo = [
    'TODOS',
    'LIRIOS',
    'GIRASOL',
    'MATSUMOTO',
    'CREMON',
    'POMPON',
  ];

  @override
  void initState() {
    super.initState();
    _cultivoSeleccionado = widget.cultivo.isNotEmpty ? widget.cultivo : 'TODOS';
    if (widget.semana.isNotEmpty && widget.semana != 'Semana #38' && widget.semana != 'Semana General') {
      _semanaActual = widget.semana;
    } else {
      _semanaActual = CalendarioUtil.obtenerEtiquetaSemana(DateTime.now(), incluirAnio: true);
    }
  }

  List<Siembra> _filtrarSiembras() {
    final validas = widget.siembras.where((s) {
      if (s.operarioId <= 0) return false;
      final obs = (s.observaciones ?? '').toUpperCase();
      final corte = (s.corte ?? '').toUpperCase();
      if (obs.contains('MADRE') || obs.contains('BANCO') || obs.contains('NÚCLEO') || obs.contains('NUCLEO') ||
          corte.contains('MADRE') || corte.contains('BANCO') || corte.contains('NÚCLEO') || corte.contains('NUCLEO')) {
        return false;
      }
      if (widget.variedades != null && widget.variedades!.isNotEmpty) {
        final v = widget.variedades!.firstWhere((varItem) => varItem.id == s.variedadId, orElse: () => Variedad(id: 0, codigo: '', nombre: ''));
        final fam = (v.familiaNombre ?? '').toUpperCase();
        final nom = v.nombre.toUpperCase();
        if (fam.contains('MADRE') || fam.contains('BANCO') || fam.contains('NÚCLEO') || fam.contains('NUCLEO') ||
            nom.contains('MADRE') || nom.contains('BANCO') || nom.contains('NÚCLEO') || nom.contains('NUCLEO')) {
          return false;
        }
      }
      return true;
    }).toList();

    if (_cultivoSeleccionado == 'TODOS' || widget.variedades == null || widget.variedades!.isEmpty) {
      return validas;
    }
    return validas.where((s) {
      final c = ReporteService.clasificarCultivo(siembra: s, variedades: widget.variedades!);
      return c == _cultivoSeleccionado;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formatterNum = NumberFormat('#,###', 'es_CO');
    final siembrasActivas = _filtrarSiembras();
    var rendimientos = RendimientoOperario.calcular(
      siembras: siembrasActivas,
      operarios: widget.operarios,
      variedades: widget.variedades,
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

    final totalTallosGlobal = siembrasActivas.fold<int>(0, (sum, s) => sum + s.cantidad);
    final totalCamasGlobal = siembrasActivas.length;
    final promPorSembrador = rendimientos.isNotEmpty
        ? (totalTallosGlobal / rendimientos.length).round()
        : 0;

    final esMovil = Responsive.isMobile(context);
    final dialogMaxW = Responsive.dialogMaxWidth(context);
    final dialogMaxH = MediaQuery.sizeOf(context).height * (esMovil ? 0.94 : 0.90);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: esMovil ? 8 : 20,
        vertical: esMovil ? 10 : 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxW.clamp(320.0, 840.0),
          maxHeight: dialogMaxH,
        ),
        child: Padding(
          padding: EdgeInsets.all(esMovil ? 10 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header fijo arriba
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rendimiento de Sembradores',
                          style: TextStyle(
                            fontSize: esMovil ? 16.5 : 19,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        Text(
                          'Productividad | $_cultivoSeleccionado | $_semanaActual',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
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
              const Divider(height: 16),

              // Área central 100% Scrollable con CustomScrollView para evitar bottom overflow
              Expanded(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Filtros de Cultivo, KPIs y Buscador dentro del área scrollable
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.variedades != null && widget.variedades!.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('Cultivo: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF33691E))),
                                ..._opcionesCultivo.map((c) {
                                  final isSelected = _cultivoSeleccionado == c;
                                  return ChoiceChip(
                                    label: Text(
                                      c,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isSelected ? Colors.white : const Color(0xFF33691E),
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF7CB342),
                                    backgroundColor: const Color(0xFFF1F8E9),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    onSelected: (val) {
                                      if (val) setState(() => _cultivoSeleccionado = c);
                                    },
                                  );
                                }),
                              ],
                            ),
                            if (_cultivoSeleccionado == 'TODOS') ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _separarPorCultivo ? const Color(0xFFE8F5E9) : const Color(0xFFF9FBE7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _separarPorCultivo ? const Color(0xFF81C784) : const Color(0xFFC5E1A5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _separarPorCultivo ? Icons.folder_copy : Icons.file_copy_outlined,
                                      color: _separarPorCultivo ? const Color(0xFF2E7D32) : const Color(0xFF558B2F),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Separar rendimiento en PDF independiente por cada cultivo',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: _separarPorCultivo ? const Color(0xFF1B5E20) : const Color(0xFF33691E),
                                        ),
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
                            if (_cultivoSeleccionado == 'LIRIOS') ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8E9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF81C784)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shopping_basket, color: Color(0xFF2E7D32), size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'En Lirios (LA, LO, OT), los rendimientos se registran por entrega de canastas a cada empleado.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) => const RendimientoLiriosScreen(subgrupoInicial: 'LA'),
                                          ),
                                        );
                                      },
                                      child: const Text('Abrir Canastas', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                          ],

                          // KPI Cards Row
                          if (esMovil)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildMetricCard(
                                        icon: Icons.people_alt,
                                        label: 'Sembradores',
                                        value: '${rendimientos.length}',
                                        color: const Color(0xFF33691E),
                                        bg: const Color(0xFFF1F8E9),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildMetricCard(
                                        icon: Icons.view_week,
                                        label: 'Total Camas',
                                        value: formatterNum.format(totalCamasGlobal),
                                        color: const Color(0xFF00796B),
                                        bg: const Color(0xFFE0F2F1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildMetricCard(
                                        icon: Icons.grass,
                                        label: 'Total Tallos',
                                        value: formatterNum.format(totalTallosGlobal),
                                        color: const Color(0xFF2E7D32),
                                        bg: const Color(0xFFE8F5E9),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildMetricCard(
                                        icon: Icons.speed,
                                        label: 'Promedio/Sembr.',
                                        value: formatterNum.format(promPorSembrador),
                                        color: const Color(0xFFEF6C00),
                                        bg: const Color(0xFFFFF3E0),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
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
                          if (esMovil)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Buscar sembrador...',
                                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF7CB342)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF33691E))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButton<String>(
                                        value: _orden,
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 12),
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
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
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
                        ],
                      ),
                    ),

                    // Lista de Sembradores con Rendimiento
                    if (rendimientos.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
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
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) {
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

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
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
                                child: esMovil
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Badge Posición
                                          Container(
                                            width: 38,
                                            height: 38,
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
                                                fontSize: medal.isNotEmpty ? 16 : 12,
                                                color: posColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.operario.nombreCompleto,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF263238),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Cédula: ${r.operario.cedula.isNotEmpty ? r.operario.cedula : "S/C"} | ${r.diasTrabajados} días',
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                                ),
                                                const SizedBox(height: 8),
                                                _buildMetricasOperario(r, esTop1, formatterNum),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
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
                                            child: _buildMetricasOperario(r, esTop1, formatterNum),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                          childCount: rendimientos.length,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Botones de Acción
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Text(
                    '${widget.siembras.length} registros',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: Text('Guardar', style: TextStyle(fontSize: esMovil ? 11 : 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF558B2F),
                          side: const BorderSide(color: Color(0xFF7CB342)),
                          padding: EdgeInsets.symmetric(horizontal: esMovil ? 8 : 12, vertical: esMovil ? 6 : 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generando ? null : _guardarPdfRendimientoDescargas,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 16),
                        label: Text('Compartir', style: TextStyle(fontSize: esMovil ? 11 : 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF558B2F),
                          side: const BorderSide(color: Color(0xFF7CB342)),
                          padding: EdgeInsets.symmetric(horizontal: esMovil ? 8 : 12, vertical: esMovil ? 6 : 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generando ? null : _exportarRendimientoPdf,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: Text('Imprimir', style: TextStyle(fontSize: esMovil ? 11 : 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF558B2F),
                          side: const BorderSide(color: Color(0xFF7CB342)),
                          padding: EdgeInsets.symmetric(horizontal: esMovil ? 8 : 12, vertical: esMovil ? 6 : 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generando ? null : _imprimirRendimientoPdf,
                      ),
                      ElevatedButton.icon(
                        icon: _generando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.visibility, color: Colors.white, size: 16),
                        label: Text(
                          _generando ? '...' : 'Ver PDF',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: esMovil ? 11 : 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: EdgeInsets.symmetric(horizontal: esMovil ? 10 : 16, vertical: esMovil ? 6 : 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: _generando ? null : _verPdfRendimiento,
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

  Widget _buildMetricasOperario(RendimientoOperario r, bool esTop1, NumberFormat formatterNum) {
    return Column(
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
              esTop1 ? const Color(0xFFFBC02D) : const Color(0xFF7CB342),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            Text(
              '${r.totalCamas} camas',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 11)),
            Text(
              'Prom: ${formatterNum.format(r.promedioTallosPorCama.round())} tallos/cama',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 11)),
            Text(
              '${formatterNum.format(r.promedioTallosPorDia.round())} t/día',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }

  void _verPdfRendimiento() {
    final activas = _filtrarSiembras();
    if (activas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra para evaluar el rendimiento.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS' && widget.variedades != null && widget.variedades!.isNotEmpty) {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: activas,
        variedades: widget.variedades!,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        final nombreLimpio = 'Rendimiento_Sembradores_${cultUnico}_${_semanaActual.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              titulo: 'Rendimiento - $cultUnico',
              nombreArchivo: nombreLimpio,
              generadorPdf: () => ReporteService.generarPdfReporteRendimiento(
                siembras: agrupados[cultUnico]!,
                operarios: widget.operarios,
                variedades: widget.variedades,
                cultivo: cultUnico,
                semana: _semanaActual,
                rangoFechas: widget.rangoFechas,
              ),
            ),
          ),
        );
      } else {
        _mostrarSelectorCultivoVisualizarRendimiento(agrupados);
      }
      return;
    }

    final nombreLimpio = 'Rendimiento_Sembradores_${_cultivoSeleccionado}_${_semanaActual.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          titulo: 'Rendimiento - $_cultivoSeleccionado',
          nombreArchivo: nombreLimpio,
          generadorPdf: () => ReporteService.generarPdfReporteRendimiento(
            siembras: activas,
            operarios: widget.operarios,
            variedades: widget.variedades,
            cultivo: _cultivoSeleccionado,
            semana: _semanaActual,
            rangoFechas: widget.rangoFechas,
          ),
        ),
      ),
    );
  }

  void _mostrarSelectorCultivoVisualizarRendimiento(Map<String, List<Siembra>> agrupados) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.leaderboard, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Rendimiento por Cultivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo para ver su reporte de rendimiento:', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF2E7D32)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final nombreLimpio = 'Rendimiento_Sembradores_${cult}_${_semanaActual.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            titulo: 'Rendimiento - $cult',
                            nombreArchivo: nombreLimpio,
                            generadorPdf: () => ReporteService.generarPdfReporteRendimiento(
                              siembras: list,
                              operarios: widget.operarios,
                              variedades: widget.variedades,
                              cultivo: cult,
                              semana: _semanaActual,
                              rangoFechas: widget.rangoFechas,
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

  Future<void> _guardarPdfRendimientoDescargas() async {
    final activas = _filtrarSiembras();
    if (activas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros de siembra para evaluar el rendimiento.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _generando = true);
    try {
      if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS' && widget.variedades != null && widget.variedades!.isNotEmpty) {
        final resultados = await ReporteService.guardarPdfsSeparadosPorCultivo(
          siembras: activas,
          variedades: widget.variedades!,
          camas: widget.camas ?? [],
          operarios: widget.operarios,
          semana: _semanaActual,
          rangoFechas: widget.rangoFechas,
          esRendimiento: true,
        );

        if (!mounted) return;
        if (resultados.isNotEmpty) {
          final nombres = resultados.keys.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Se guardaron ${resultados.length} PDFs de rendimiento por cultivo en Descargas:\n$nombres'),
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

      final pdfBytes = await ReporteService.generarPdfReporteRendimiento(
        siembras: activas,
        operarios: widget.operarios,
        variedades: widget.variedades,
        cultivo: _cultivoSeleccionado,
        semana: _semanaActual,
        rangoFechas: widget.rangoFechas,
      );

      final nombreLimpio = 'Rendimiento_Sembradores_${_cultivoSeleccionado}_${_semanaActual.replaceAll(RegExp(r'[\\/:*?"<>|# ]'), '_')}.pdf';
      final ruta = await ReporteService.guardarPdfEnDescargas(
        bytes: pdfBytes,
        nombreArchivo: nombreLimpio,
      );

      if (!mounted) return;
      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ PDF de rendimiento guardado en Descargas:\n$nombreLimpio'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        await _exportarRendimientoPdf();
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

  Future<void> _exportarRendimientoPdf() async {
    final activas = _filtrarSiembras();
    if (activas.isEmpty) return;

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS' && widget.variedades != null && widget.variedades!.isNotEmpty) {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: activas,
        variedades: widget.variedades!,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        setState(() => _generando = true);
        try {
          await ReporteService.compartirPdfRendimiento(
            siembras: agrupados[cultUnico]!,
            operarios: widget.operarios,
            cultivo: cultUnico,
            semana: _semanaActual,
            rangoFechas: widget.rangoFechas,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al exportar rendimiento: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _generando = false);
        }
      } else {
        _mostrarSelectorCultivoCompartirRendimiento(agrupados);
      }
      return;
    }

    setState(() => _generando = true);
    try {
      await ReporteService.compartirPdfRendimiento(
        siembras: activas,
        operarios: widget.operarios,
        cultivo: _cultivoSeleccionado,
        semana: _semanaActual,
        rangoFechas: widget.rangoFechas,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF de rendimiento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _mostrarSelectorCultivoCompartirRendimiento(Map<String, List<Siembra>> agrupados) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Compartir Rendimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo para compartir su rendimiento:', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                          await ReporteService.compartirPdfRendimiento(
                            siembras: list,
                            operarios: widget.operarios,
                            cultivo: cult,
                            semana: _semanaActual,
                            rangoFechas: widget.rangoFechas,
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

  Future<void> _imprimirRendimientoPdf() async {
    final activas = _filtrarSiembras();
    if (activas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de siembra para evaluar el rendimiento.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_separarPorCultivo && _cultivoSeleccionado == 'TODOS' && widget.variedades != null && widget.variedades!.isNotEmpty) {
      final agrupados = ReporteService.agruparSiembrasPorCultivo(
        siembras: activas,
        variedades: widget.variedades!,
      );
      if (agrupados.keys.length == 1) {
        final cultUnico = agrupados.keys.first;
        setState(() => _generando = true);
        try {
          await ReporteService.imprimirReporteRendimiento(
            siembras: agrupados[cultUnico]!,
            operarios: widget.operarios,
            cultivo: cultUnico,
            semana: _semanaActual,
            rangoFechas: widget.rangoFechas,
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
        _mostrarSelectorCultivoImprimirRendimiento(agrupados);
      }
      return;
    }

    setState(() => _generando = true);
    try {
      await ReporteService.imprimirReporteRendimiento(
        siembras: activas,
        operarios: widget.operarios,
        cultivo: _cultivoSeleccionado,
        semana: _semanaActual,
        rangoFechas: widget.rangoFechas,
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
  }

  void _mostrarSelectorCultivoImprimirRendimiento(Map<String, List<Siembra>> agrupados) {
    final fNum = NumberFormat('#,###', 'es_CO');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Imprimir Rendimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione el cultivo a enviar a impresión:', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                          await ReporteService.imprimirReporteRendimiento(
                            siembras: list,
                            operarios: widget.operarios,
                            cultivo: cult,
                            semana: _semanaActual,
                            rangoFechas: widget.rangoFechas,
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
}

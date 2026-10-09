// ============================================================================
// ARCHIVO: gestion_sembradores_dialog.dart
// ¿QUÉ ES ESTA VENTANA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta ventana es EL LIBRO DE ASIGNACIÓN DE PERSONAL DE SIEMBRA.
//
// En la empresa hay casi 300 empleados (oficina, empaque, compras, ventas, etc.),
// pero en campo solo un grupo específico se dedica a sembrar y recibir canastas.
//
// Desde este panel el administrador puede:
// 1. 🔍 Buscar a cualquier empleado por nombre o cédula.
// 2. 🔘 Habilitar o deshabilitar con un simple botón a quiénes están en siembra.
// 3. ⚡ Habilitar automáticamente a quienes ya tienen historial de siembras.
// 4. 🎯 Lograr que en los formularios de siembra y canastas de lirios solo
//    aparezcan los sembradores autorizados, evitando listas interminables.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/utils/responsive.dart';

class GestionSembradoresDialog extends StatefulWidget {
  const GestionSembradoresDialog({super.key});

  @override
  State<GestionSembradoresDialog> createState() => _GestionSembradoresDialogState();
}

class _GestionSembradoresDialogState extends State<GestionSembradoresDialog> {
  final DbRepository _db = DbRepository();

  List<Operario> _todosLosOperarios = [];
  Set<int> _seleccionados = {};
  Map<int, int> _conteoSiembras = {};
  String _filtroTexto = '';
  String _filtroPestana = 'TODOS'; // 'TODOS', 'SIEMBRA', 'NO_ASIGNADOS'
  bool _cargando = true;
  bool _guardando = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final todos = await _db.obtenerOperarios();
    final activos = await _db.obtenerIdsSembradoresActivos();
    final conteo = await _db.obtenerConteoSiembrasPorOperario();

    if (mounted) {
      setState(() {
        _todosLosOperarios = todos;
        _seleccionados = Set.from(activos);
        _conteoSiembras = conteo;
        _cargando = false;
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (_seleccionados.isEmpty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sin sembradores seleccionados'),
          content: const Text(
            'Si no seleccionas a ningún empleado, los formularios mostrarán temporalmente a todos para no bloquear el trabajo. ¿Deseas guardar así?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _guardando = true);
    try {
      await _db.guardarSembradoresBatch(_seleccionados);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Personal de siembra actualizado: ${_seleccionados.length} empleado(s) autorizados.',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando sembradores: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _activarConHistorial() {
    setState(() {
      for (final op in _todosLosOperarios) {
        if ((_conteoSiembras[op.id] ?? 0) > 0) {
          _seleccionados.add(op.id);
        }
      }
    });
  }

  void _seleccionarTodos() {
    setState(() {
      _seleccionados = _todosLosOperarios.map((o) => o.id).toSet();
    });
  }

  void _limpiarSeleccion() {
    setState(() {
      _seleccionados.clear();
    });
  }

  List<Operario> _filtrarLista() {
    return _todosLosOperarios.where((op) {
      // 1. Filtro por texto
      if (_filtroTexto.isNotEmpty) {
        final q = _filtroTexto.toLowerCase();
        final matchNombre = op.nombreCompleto.toLowerCase().contains(q);
        final matchCedula = op.cedula.toLowerCase().contains(q);
        if (!matchNombre && !matchCedula) return false;
      }

      // 2. Filtro por pestaña
      final estaSeleccionado = _seleccionados.contains(op.id);
      if (_filtroPestana == 'SIEMBRA' && !estaSeleccionado) {
        return false;
      }
      if (_filtroPestana == 'NO_ASIGNADOS' && estaSeleccionado) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = Responsive.isMobile(context);
    final esLandscape = Responsive.isLandscape(context);
    final dialogMaxW = esMovil ? double.infinity : (esLandscape ? 720.0 : 640.0);
    final dialogMaxH = MediaQuery.sizeOf(context).height * (esLandscape ? 0.95 : 0.88);

    final listaFiltrada = _filtrarLista();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: esMovil ? 10 : 24,
        vertical: esMovil ? 12 : 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxW,
          maxHeight: dialogMaxH,
        ),
        child: Padding(
          padding: EdgeInsets.all(esMovil ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC5E1A5)),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Color(0xFF2E7D32), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestión de Empleados de Siembra',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '${_seleccionados.length} de ${_todosLosOperarios.length} empleados autorizados para siembra',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
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

              const Divider(height: 18),

              // BARRA DE BÚSQUEDA Y PESTAÑAS RÁPIDAS
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar empleado por nombre o cédula...',
                        hintStyle: TextStyle(fontSize: esMovil ? 11.5 : 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342), size: 20),
                        suffixIcon: _filtroTexto.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filtroTexto = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF7CB342), width: 1.8),
                        ),
                      ),
                      onChanged: (val) => setState(() => _filtroTexto = val.trim()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // PESTAÑAS DE FILTRO Y ACCIONES RÁPIDAS
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 4,
                    children: [
                      _buildFiltroChip('TODOS', 'Todos (${_todosLosOperarios.length})'),
                      _buildFiltroChip('SIEMBRA', 'En Siembra (${_seleccionados.length})'),
                      _buildFiltroChip('NO_ASIGNADOS', 'Otros (${_todosLosOperarios.length - _seleccionados.length})'),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.history, size: 16, color: Color(0xFF33691E)),
                        label: const Text('Con Historial', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF33691E))),
                        onPressed: _activarConHistorial,
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _seleccionarTodos,
                        child: const Text('Todos', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _limpiarSeleccion,
                        child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // LISTA DE EMPLEADOS
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
                    : listaFiltrada.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No se encontraron empleados con los filtros aplicados.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: listaFiltrada.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final op = listaFiltrada[index];
                              final estaEnSiembra = _seleccionados.contains(op.id);
                              final conteo = _conteoSiembras[op.id] ?? 0;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (estaEnSiembra) {
                                      _seleccionados.remove(op.id);
                                    } else {
                                      _seleccionados.add(op.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: estaEnSiembra ? const Color(0xFFF1F8E9) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: estaEnSiembra ? const Color(0xFFAED581) : Colors.grey.shade300,
                                      width: estaEnSiembra ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar con iniciales
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: estaEnSiembra ? const Color(0xFF558B2F) : Colors.grey.shade400,
                                        child: Text(
                                          _obtenerIniciales(op.nombreCompleto),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Datos del empleado
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              op.nombreCompleto,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: estaEnSiembra ? const Color(0xFF1B5E20) : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(
                                                  'Cédula: ${op.cedula.isNotEmpty ? op.cedula : 'N/A'}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                if (conteo > 0) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.amber.shade400, width: 0.8),
                                                    ),
                                                    child: Text(
                                                      '$conteo siembras',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.amber.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Switch interactivo
                                      Switch.adaptive(
                                        value: estaEnSiembra,
                                        activeThumbColor: const Color(0xFF2E7D32),
                                        activeTrackColor: const Color(0xFFA5D6A7),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val) {
                                              _seleccionados.add(op.id);
                                            } else {
                                              _seleccionados.remove(op.id);
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              const Divider(height: 18),

              // BOTONES INFERIORES DE ACCIÓN
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_seleccionados.length} en siembra',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 13),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _guardando ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _guardando ? 'Guardando...' : 'Guardar y Aplicar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _guardando ? null : _guardarCambios,
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

  Widget _buildFiltroChip(String clave, String label) {
    final isSelected = _filtroPestana == clave;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF33691E),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF558B2F),
      backgroundColor: const Color(0xFFF1F8E9),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) {
        if (val) setState(() => _filtroPestana = clave);
      },
    );
  }

  String _obtenerIniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'OP';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }
}

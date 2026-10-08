// ============================================================================
// ARCHIVO: form_siembra_lirios_screen.dart
// ¿QUÉ ES ESTA PANTALLA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta pantalla es LA PLANILLA ESPECIAL PARA LA SIEMBRA DE LIRIOS.
//
// Los Lirios son flores muy especiales y distintas a los pompones:
// 1. NO SE SIEMBRAN POR RAMITAS (Esquejes), SINO POR BULBOS (como cebollitas).
// 2. Esos bulbos vienen en barco desde Holanda o Chile en contenedores refrigerados.
// 3. Por ley y por calidad, cada mata de lirio debe tener su historia completa:
//    - ¿Quién vendió el bulbo? (Proveedor: Onings, Vletter, etc.).
//    - ¿En qué barco o furgón llegó? (Contenedor).
//    - ¿Qué número de viaje trae? (Lote).
//
// Esta pantalla se conecta con la TABLA 187 de la oficina para que el supervisor
// solo tenga que tocar el contenedor y el lote con el dedo sin tener que escribirlo a mano.
//
// Además, tiene el botón de CANASTAS Y RENDIMIENTO DE LIRIOS para contar cuántos
// bultos sembró cada trabajador en la cuadrilla.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';
import 'package:app_movil/screens/rendimiento_lirios_screen.dart';
import 'package:app_movil/widgets/crear_variedad_dialog.dart';

class FormSiembraLiriosScreen extends StatefulWidget {
  final String subtipo; // 'Lirio LA', 'Lirio LO', 'Lirio OT'

  const FormSiembraLiriosScreen({
    super.key,
    this.subtipo = 'Lirio LA',
  });

  @override
  State<FormSiembraLiriosScreen> createState() => _FormSiembraLiriosScreenState();
}

class _FormSiembraLiriosScreenState extends State<FormSiembraLiriosScreen> {
  final _formKey = GlobalKey<FormState>();
  final DbRepository _db = DbRepository(); // El mayordomo que vigila las reglas del cultivo

  // Catálogos
  List<Bloque> _bloques = [];
  List<Cama> _camasDelBloque = [];
  List<Variedad> _variedades = [];
  List<Variedad> _todasLasVariedades = [];
  Map<int, ValidacionCicloResultado> _estadoCicloCamas = {};
  ConfigAgronomica? _configAgronomica;

  // Variables seleccionadas
  String? _fechaSeleccionada;
  Bloque? _bloqueSeleccionado;
  Cama? _camaSeleccionada;
  Variedad? _variedadSeleccionada;
  bool _cargandoCamas = false;
  bool _guardando = false;

  // Catálogo Tabla 187 (Lirios: Proveedor, Contenedor, Lote, Variedad)
  List<LirioItem187> _todosLirios187 = [];
  List<String> _proveedores187 = [];
  List<String> _contenedores187 = [];
  List<String> _lotes187 = [];

  // Selecciones de listas desplegables de Tabla 187
  String? _proveedorSeleccionado;
  String? _contenedorSeleccionado;
  String? _loteSeleccionado;

  // Controladores de texto según el wireframe
  final TextEditingController _lineasController = TextEditingController();
  final TextEditingController _tallosController = TextEditingController();
  final TextEditingController _conteoController = TextEditingController();
  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _loteController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  @override
  void dispose() {
    _lineasController.dispose();
    _tallosController.dispose();
    _conteoController.dispose();
    _proveedorController.dispose();
    _loteController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaSeleccionada =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _recalcularTallosPorLineas();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    final b = await _db.obtenerBloques();
    List<int> famIds = [199, 204, 309, 255];
    final sub = widget.subtipo.toLowerCase();
    if (sub.contains('la') || sub.contains('asiat')) {
      famIds = [199, 255];
    } else if (sub.contains('lo') || sub.contains('oriental')) {
      famIds = [204];
    } else if (sub.contains('ot')) {
      famIds = [309];
    }
    final allV = await _db.obtenerVariedades(soloActivas: true);
    final v = await _db.obtenerVariedadesPorFamilia(famIds, soloActivas: true);
    final cfg = await _db.obtenerConfigAgronomica(cultivo: widget.subtipo);

    // Cargar Catálogo Tabla 187 (Proveedor, Contenedor, Lote, Variedad)
    final lirios187 = await _db.obtenerRegistrosLirios187();
    final provs = await _db.obtenerProveedoresLirios();
    final conts = await _db.obtenerContenedoresLirios();
    final lots = await _db.obtenerLotesLirios();

    if (!mounted) return;
    setState(() {
      _bloques = b;
      _variedades = v.isNotEmpty ? v : allV;
      _todasLasVariedades = allV;
      _configAgronomica = cfg;
      _todosLirios187 = lirios187;
      _proveedores187 = provs;
      _contenedores187 = conts;
      _lotes187 = lots;
    });
  }

  Future<void> _recargarCiclosCamas() async {
    if (_bloqueSeleccionado == null || _fechaSeleccionada == null) return;
    final estados = await _db.obtenerEstadoCicloCamasPorBloque(
      _bloqueSeleccionado!.codigo,
      _fechaSeleccionada!,
    );
    if (!mounted) return;
    setState(() {
      _estadoCicloCamas = estados;
    });
  }

  Future<void> _onBloqueCambiado(Bloque? nuevoBloque) async {
    setState(() {
      _bloqueSeleccionado = nuevoBloque;
      _camaSeleccionada = null;
      _cargandoCamas = true;
    });

    if (nuevoBloque != null) {
      final camas = await _db.obtenerCamasPorBloque(nuevoBloque.codigo);
      final estados = await _db.obtenerEstadoCicloCamasPorBloque(
        nuevoBloque.codigo,
        _fechaSeleccionada ?? '',
      );
      if (!mounted) return;
      setState(() {
        _camasDelBloque = camas;
        _estadoCicloCamas = estados;
        _cargandoCamas = false;
      });
    } else {
      setState(() {
        _camasDelBloque = [];
        _estadoCicloCamas = {};
        _cargandoCamas = false;
      });
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
        _fechaSeleccionada =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
      await _recargarCiclosCamas();
    }
  }

  // === GETTERS Y HANDLERS TABLA 187 (Listas Desplegables Vinculadas) ===

  List<String> get _contenedoresFiltrados {
    if (_proveedorSeleccionado == null || _proveedorSeleccionado!.trim().isEmpty) {
      return _contenedores187;
    }
    final set = _todosLirios187
        .where((e) => e.proveedor == _proveedorSeleccionado)
        .map((e) => e.contenedor)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    set.sort((a, b) {
      final intA = int.tryParse(a);
      final intB = int.tryParse(b);
      if (intA != null && intB != null) return intA.compareTo(intB);
      return a.compareTo(b);
    });
    return set;
  }

  List<String> get _lotesFiltrados {
    final bool sinFiltros = (_proveedorSeleccionado == null || _proveedorSeleccionado!.trim().isEmpty) &&
        (_contenedorSeleccionado == null || _contenedorSeleccionado!.trim().isEmpty);
    if (sinFiltros && _lotes187.isNotEmpty) {
      return _lotes187;
    }
    Iterable<LirioItem187> items = _todosLirios187;
    if (_proveedorSeleccionado != null && _proveedorSeleccionado!.trim().isNotEmpty) {
      items = items.where((e) => e.proveedor == _proveedorSeleccionado);
    }
    if (_contenedorSeleccionado != null && _contenedorSeleccionado!.trim().isNotEmpty) {
      items = items.where((e) => e.contenedor == _contenedorSeleccionado);
    }
    final set = items
        .map((e) => e.lote)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  void _onProveedorCambiado(String? nuevoProveedor) {
    setState(() {
      _proveedorSeleccionado = nuevoProveedor;
      _proveedorController.text = nuevoProveedor ?? '';

      // Si el contenedor actual no pertenece al nuevo proveedor, resetearlo
      if (_contenedorSeleccionado != null && !_contenedoresFiltrados.contains(_contenedorSeleccionado)) {
        _contenedorSeleccionado = null;
        _conteoController.text = '';
      }

      // Si el lote actual no pertenece al nuevo proveedor, resetearlo
      if (_loteSeleccionado != null && !_lotesFiltrados.contains(_loteSeleccionado)) {
        _loteSeleccionado = null;
        _loteController.text = '';
      }
    });
  }

  void _onContenedorCambiado(String? nuevoContenedor) {
    setState(() {
      _contenedorSeleccionado = nuevoContenedor;
      _conteoController.text = nuevoContenedor ?? '';

      // Si no hay proveedor seleccionado, deducirlo si todos los items pertenecen al mismo proveedor
      if (_proveedorSeleccionado == null && nuevoContenedor != null) {
        final provs = _todosLirios187
            .where((e) => e.contenedor == nuevoContenedor)
            .map((e) => e.proveedor)
            .toSet();
        if (provs.length == 1) {
          _proveedorSeleccionado = provs.first;
          _proveedorController.text = provs.first;
        }
      }

      // Si el lote actual no pertenece a este contenedor, resetearlo
      if (_loteSeleccionado != null && !_lotesFiltrados.contains(_loteSeleccionado)) {
        _loteSeleccionado = null;
        _loteController.text = '';
      }
    });
  }

  void _onLoteCambiado(String? nuevoLote) {
    if (nuevoLote == null) {
      setState(() {
        _loteSeleccionado = null;
        _loteController.text = '';
      });
      return;
    }

    final match = _todosLirios187.firstWhere(
      (e) => e.lote == nuevoLote &&
          (_proveedorSeleccionado == null || e.proveedor == _proveedorSeleccionado) &&
          (_contenedorSeleccionado == null || e.contenedor == _contenedorSeleccionado),
      orElse: () => _todosLirios187.firstWhere(
        (e) => e.lote == nuevoLote,
        orElse: () => LirioItem187(proveedor: '', contenedor: '', lote: nuevoLote),
      ),
    );

    setState(() {
      _loteSeleccionado = nuevoLote;
      _loteController.text = nuevoLote;

      if (match.proveedor.isNotEmpty) {
        _proveedorSeleccionado = match.proveedor;
        _proveedorController.text = match.proveedor;
      }
      if (match.contenedor.isNotEmpty) {
        _contenedorSeleccionado = match.contenedor;
        _conteoController.text = match.contenedor;
      }

      // Auto-emparejar Variedad si está disponible en Tabla 187
      if (_variedadSeleccionada == null && (match.variedadId != null || match.variedad != null)) {
        Variedad? varMatch;
        if (match.variedadId != null) {
          try {
            varMatch = _todasLasVariedades.firstWhere((v) => v.id == match.variedadId);
          } catch (_) {}
        }
        if (varMatch == null && match.variedad != null) {
          final nomClean = match.variedad!.toLowerCase().replaceAll(' bn', '').trim();
          try {
            varMatch = _todasLasVariedades.firstWhere(
              (v) => v.nombre.toLowerCase().contains(nomClean) || nomClean.contains(v.nombre.toLowerCase()),
            );
          } catch (_) {}
        }
        if (varMatch != null) {
          _variedadSeleccionada = varMatch;
          _db.obtenerConfigAgronomicaParaVariedad(varMatch, cultivoFallback: 'LIRIOS').then((cfg) {
            if (mounted) {
              setState(() {
                _configAgronomica = cfg;
              });
              _recalcularTallosPorLineas();
            }
          });
        }
      }
    });
  }

  Future<void> _abrirBuscadorLotes() async {
    final lotesDisponibles = _lotesFiltrados;
    final String? seleccionado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lista = query.isEmpty
                ? lotesDisponibles
                : lotesDisponibles.where((l) => l.toLowerCase().contains(query.toLowerCase())).toList();

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.dialogMaxWidth(context),
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Buscar Lote - Tabla 187 (${lotesDisponibles.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF33691E)),
                          ),
                          if (_proveedorSeleccionado != null || _contenedorSeleccionado != null)
                            Text(
                              '${_proveedorSeleccionado ?? ""}${_contenedorSeleccionado != null ? " | Cont: $_contenedorSeleccionado" : ""}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Escribe para buscar número de lote...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF7CB342), width: 2),
                          ),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: lista.isEmpty
                            ? const Center(child: Text('No se encontraron lotes coincidentes'))
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: lista.length,
                                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final item = lista[i];
                                  final isSelected = _loteSeleccionado == item;
                                  final detalles = _todosLirios187.where((e) => e.lote == item).toList();
                                  final prov = detalles.isNotEmpty ? detalles.first.proveedor : '';
                                  final cont = detalles.isNotEmpty ? detalles.first.contenedor : '';
                                  final varNom = detalles.isNotEmpty && detalles.first.variedad != null
                                      ? detalles.first.variedad!
                                      : '';

                                  return InkWell(
                                    onTap: () => Navigator.pop(ctx, item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFF1F8E9)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF7CB342) : Colors.grey.shade300,
                                          width: isSelected ? 1.8 : 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF558B2F),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'LOTE $item',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (isSelected)
                                                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              if (prov.isNotEmpty)
                                                _buildMiniChip(Icons.business, 'Prov: $prov'),
                                              if (cont.isNotEmpty)
                                                _buildMiniChip(Icons.directions_boat, 'Cont: $cont'),
                                              if (varNom.isNotEmpty)
                                                _buildMiniChip(Icons.local_florist, varNom),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (seleccionado != null) {
      _onLoteCambiado(seleccionado);
    }
  }

  Future<void> _abrirBuscadorVariedades() async {
    final Variedad? seleccionada = await showModalBottomSheet<Variedad>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        bool verTodas = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final baseList = verTodas ? _todasLasVariedades : _variedades;
            final lista = query.isEmpty
                ? baseList
                : baseList.where((v) {
                    final q = query.toLowerCase();
                    return v.nombre.toLowerCase().contains(q) ||
                        v.codigo.toLowerCase().contains(q);
                  }).toList();

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.dialogMaxWidth(context),
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Catálogo: ${verTodas ? "Todas (${_todasLasVariedades.length})" : "Lirios (${_variedades.length})"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF33691E)),
                          ),
                          TextButton.icon(
                            icon: Icon(verTodas ? Icons.filter_alt : Icons.all_inclusive, size: 16, color: const Color(0xFF7CB342)),
                            label: Text(
                              verTodas ? 'Filtrar por Lirios' : 'Ver todo el catálogo',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF558B2F)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                verTodas = !verTodas;
                              });
                            },
                          ),
                        ],
                      ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Escribe para buscar variedad de Lirio...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF7CB342), width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => query = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Agregar Nueva Variedad / Prueba',
                        onPressed: () async {
                          final nueva = await showDialog<Variedad>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dCtx) => CrearVariedadDialog(
                              cultivoSugerido: widget.subtipo,
                              nombreInicial: query.isNotEmpty ? query : null,
                            ),
                          );
                          if (nueva != null) {
                            await _cargarCatalogos();
                            if (ctx.mounted) Navigator.pop(ctx, nueva);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: lista.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  query.isNotEmpty ? 'No se encontró "$query"' : 'No hay variedades registradas',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '¿Llegó una variedad de prueba no registrada en Access?',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(query.isNotEmpty ? 'Crear "$query" en SQLite' : 'Agregar Nueva Variedad'),
                                  onPressed: () async {
                                    final nueva = await showDialog<Variedad>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dCtx) => CrearVariedadDialog(
                                        cultivoSugerido: widget.subtipo,
                                        nombreInicial: query.isNotEmpty ? query : null,
                                      ),
                                    );
                                    if (nueva != null) {
                                      await _cargarCatalogos();
                                      if (ctx.mounted) Navigator.pop(ctx, nueva);
                                    }
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: lista.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = lista[i];
                              final isSelected = _variedadSeleccionada?.id == item.id;
                              return ListTile(
                                tileColor: isSelected
                                    ? const Color(0xFF7CB342).withValues(alpha: 0.15)
                                    : null,
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.nombre,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF33691E) : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (item.esTemporal || item.id < 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.shade400),
                                        ),
                                        child: Text(
                                          'PRUEBA',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text('Código: ${item.codigo}${item.colorNombre != null ? ' | Color: ${item.colorNombre}' : ''}${item.familiaNombre != null ? ' | ${item.familiaNombre}' : ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.esTemporal || item.id < 0)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                                        tooltip: 'Eliminar variedad temporal',
                                        onPressed: () async {
                                          final totalSiembras = await _db.contarSiembrasPorVariedad(item.id);
                                          if (!ctx.mounted) return;
                                          final confirmar = await showDialog<bool>(
                                            context: context,
                                            builder: (dCtx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, color: Colors.red.shade700),
                                                  const SizedBox(width: 8),
                                                  const Text('Eliminar Variedad'),
                                                ],
                                              ),
                                              content: Text(
                                                totalSiembras > 0
                                                    ? '¿Deseas eliminar "${item.nombre}"? Tiene $totalSiembras siembra(s) que también serán eliminadas.'
                                                    : '¿Estás seguro de eliminar la variedad temporal "${item.nombre}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dCtx, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red.shade700,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: () => Navigator.pop(dCtx, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmar == true) {
                                            await _db.eliminarVariedadTemporal(item.id, eliminarSiembrasAsociadas: true);
                                            await _cargarCatalogos();
                                            if (_variedadSeleccionada?.id == item.id) {
                                              setState(() => _variedadSeleccionada = null);
                                            }
                                            setModalState(() {});
                                          }
                                        },
                                      ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Color(0xFF7CB342)),
                                  ],
                                ),
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );

    if (seleccionada != null) {
      final cfgVar = await _db.obtenerConfigAgronomicaParaVariedad(seleccionada, cultivoFallback: 'LIRIOS');
      setState(() {
        _variedadSeleccionada = seleccionada;
        _configAgronomica = cfgVar;
      });
      _recalcularTallosPorLineas();
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
      if (seleccionada.esTemporal || seleccionada.id < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2E7D32),
              content: Text('Variedad de prueba "${seleccionada.nombre}" guardada localmente en SQLite. ¡Rendimiento listo para registrar!'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  int get _densidadParrilla {
    final sub = widget.subtipo.toUpperCase();
    if (sub.contains('LA') || sub.contains('ASIAT')) {
      return 143;
    }
    return 63; // LO, OT y Oriental
  }

  void _recalcularTallosPorLineas() {
    final int? p = int.tryParse(_lineasController.text.trim());
    if (p != null && p > 0) {
      final int factor = _densidadParrilla;
      setState(() {
        _tallosController.text = (p * factor).toString();
      });
    }
  }

  Future<void> _guardarSiembra() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_bloqueSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione un bloque')),
      );
      return;
    }

    if (_camaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una cama')),
      );
      return;
    }

    if (_variedadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una variedad')),
      );
      return;
    }

    // Validación de Trazabilidad Exclusiva de Lirios: Proveedor, Contenedor y Lote son OBLIGATORIOS
    final String? contVal = _contenedorSeleccionado ?? (_conteoController.text.trim().isNotEmpty ? _conteoController.text.trim() : null);
    final String? provVal = _proveedorSeleccionado ?? (_proveedorController.text.trim().isNotEmpty ? _proveedorController.text.trim() : null);
    final String? loteVal = _loteSeleccionado ?? (_loteController.text.trim().isNotEmpty ? _loteController.text.trim() : null);

    if (provVal == null || provVal.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El PROVEEDOR es obligatorio para siembras de Lirios.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (contVal == null || contVal.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El CONTENEDOR es obligatorio para siembras de Lirios.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (loteVal == null || loteVal.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El LOTE de importación es obligatorio para siembras de Lirios.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final int? tallos = int.tryParse(_tallosController.text.trim());
    if (tallos == null || tallos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese una cantidad válida de bulbos')),
      );
      return;
    }

    // Validación 1: Verificar restricciones de capacidad de cama y ciclo (sin operario individual)
    final validacionCiclo = await _db.validarCicloYCamaParaSiembra(
      _camaSeleccionada!.id,
      _fechaSeleccionada ?? '',
      nuevaCantidad: tallos,
      nuevaVariedadId: _variedadSeleccionada!.id,
      nuevoOperarioId: 0,
    );

    if (!validacionCiclo.esValido) {
      if (!mounted) return;
      final bool esLlena = validacionCiclo.esCamaLlena;
      final bool esExcesoCupo = validacionCiclo.esCamaCompartida;
      final String tituloDialog = esLlena
          ? 'Cama con Capacidad Completa'
          : (esExcesoCupo ? 'Cupo de Cama Excedido' : 'Restricción de Ciclo Agronómico');

      bool liberarYSembrar = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                esExcesoCupo ? Icons.warning_amber_rounded : Icons.block,
                color: esExcesoCupo ? Colors.orange.shade800 : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tituloDialog,
                  style: TextStyle(
                    color: esExcesoCupo ? Colors.orange.shade900 : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                validacionCiclo.mensaje,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: esExcesoCupo ? Colors.orange.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: esExcesoCupo ? Colors.orange.shade300 : Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Cama: ${_camaSeleccionada!.cama} (Bloque ${_bloqueSeleccionado!.codigo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (validacionCiclo.variedadesPresentes.isNotEmpty)
                      Text('• Variedades en cama: ${validacionCiclo.variedadesPresentes.join(", ")}'),
                    if (validacionCiclo.operariosPresentes.isNotEmpty)
                      Text('• Sembradores: ${validacionCiclo.operariosPresentes.join(", ")}'),
                    Text('• Ocupación actual: ${validacionCiclo.cantidadOcupada} de ${validacionCiclo.limiteMaximo} plantas'),
                    Text('• Cupo disponible restante: ${validacionCiclo.cupoDisponible} plantas', style: TextStyle(color: esExcesoCupo ? Colors.orange.shade900 : Colors.red, fontWeight: FontWeight.bold)),
                    if (validacionCiclo.diasFaltantes > 0)
                      Text('• Días faltantes según ciclo teórico: ${validacionCiclo.diasFaltantes} días', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (!esExcesoCupo) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFF2E7D32), size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '¿La flor de esta cama ya fue cortada por adelanto de ciclo natural? Puede liberarla y registrar la nueva siembra de inmediato.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(esExcesoCupo ? 'Corregir Cantidad' : 'Cancelar / Corregir', style: TextStyle(color: Colors.grey.shade700)),
            ),
            if (!esExcesoCupo)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: const Text(
                  'Liberar y Sembrar Ya',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () {
                  liberarYSembrar = true;
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      );

      if (liberarYSembrar) {
        // Liberar la cama por corte anticipado en 1 toque
        await _db.liberarCamaPorCorteAnticipado(
          _camaSeleccionada!.id,
          _fechaSeleccionada ?? '',
        );
      } else {
        return; // El usuario canceló o va a corregir cama
      }
    }

    // Validación 2: Verificar límite agronómico estricto fijado por el Administrador
    final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2916;
    if (tallos > limitePermitido) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Registro Bloqueado por Límite',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La cantidad ingresada ($tallos plantas) supera la restricción máxima de $limitePermitido plantas por cama configurada para ${_variedadSeleccionada?.nombre ?? widget.subtipo}.\n\n'
                'No se permite guardar este registro por restricción agronómica de densidad.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Cantidad ingresada: $tallos plantas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('• Restricción máxima permitida: $limitePermitido plantas', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    Text('• Exceso bloqueado: ${tallos - limitePermitido} plantas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Corregir Cantidad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return; // ESTRICTAMENTE BLOQUEADO
    }

    final int lineas = int.tryParse(_lineasController.text.trim()) ?? 0;

    setState(() => _guardando = true);

    try {
      final nuevaSiembra = Siembra(
        fecha: _fechaSeleccionada ?? '',
        bloqueCodigo: _bloqueSeleccionado!.codigo,
        camaId: _camaSeleccionada!.id,
        operarioId: 0,
        variedadId: _variedadSeleccionada!.id,
        cantidad: tallos,
        estado: 'ACTIVA',
        lineas: lineas,
        corte: CalendarioUtil.obtenerEtiquetaCorta(CalendarioUtil.parsearFecha(_fechaSeleccionada) ?? DateTime.now()),
        cont: _contenedorSeleccionado ?? (_conteoController.text.trim().isNotEmpty ? _conteoController.text.trim() : null),
        proveedor: _proveedorSeleccionado ?? (_proveedorController.text.trim().isNotEmpty ? _proveedorController.text.trim() : null),
        lote: _loteSeleccionado ?? (_loteController.text.trim().isNotEmpty ? _loteController.text.trim() : null),
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
        sincronizado: 0,
      );

      await _db.registrarSiembraOffline(nuevaSiembra);

      // Recargar estados de las camas del bloque para reflejar de inmediato la nueva ocupación y cupo
      await _recargarCiclosCamas();

      if (!mounted) return;

      final String nombreVariedad = _variedadSeleccionada?.nombre ?? 'Variedad';
      final String nombreCama = _camaSeleccionada?.cama ?? '';
      final infoCama = _camaSeleccionada != null ? _estadoCicloCamas[_camaSeleccionada!.id] : null;

      // Limpiar campos específicos de la variedad para el siguiente registro
      setState(() {
        _variedadSeleccionada = null;
        _tallosController.clear();
        _conteoController.clear();
        _observacionesController.clear();
        _loteController.clear();
        _proveedorController.clear();
        _proveedorSeleccionado = null;
        _contenedorSeleccionado = null;
        _loteSeleccionado = null;
        // Si la cama ya se llenó al 100%, deseleccionarla para que elijan otra cama disponible
        if (infoCama != null && infoCama.esCamaLlena) {
          _camaSeleccionada = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  infoCama != null && infoCama.esCamaLlena
                      ? '✓ $nombreVariedad guardada. ¡Cama $nombreCama al 100% de capacidad!'
                      : '✓ $nombreVariedad guardada con éxito en Cama $nombreCama. Puede continuar registrando.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF558B2F),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar siembra: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF33691E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCampoFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Fecha'),
        InkWell(
          onTap: _seleccionarFecha,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final fActual = CalendarioUtil.parsearFecha(_fechaSeleccionada) ?? DateTime.now();
                      final semTxt = CalendarioUtil.obtenerEtiquetaCorta(fActual);
                      return Text(
                        '${_fechaSeleccionada ?? 'dd/mm/aaaa'} ($semTxt)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const Icon(Icons.calendar_today, color: Color(0xFF7CB342), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoBloque() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Bloque'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Bloque>(
              isExpanded: true,
              hint: const Text('Seleccionar bloque...'),
              value: _bloqueSeleccionado,
              items: _bloques.map((b) {
                return DropdownMenuItem(
                  value: b,
                  child: Text(
                    '${b.codigo} - ${b.nombre}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onBloqueCambiado,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoCama() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Cama'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _bloqueSeleccionado == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Cama>(
              isExpanded: true,
              hint: Text(
                _cargandoCamas
                    ? 'Cargando...'
                    : (_bloqueSeleccionado == null ? 'Elija bloque' : 'Cama...'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              value: _camaSeleccionada,
              items: _camasDelBloque.map((c) {
                final info = _estadoCicloCamas[c.id];
                final bool esCompartida = info?.esCamaCompartida == true;
                final bool esLlena = info?.esCamaLlena == true || (info?.esCicloActivo == true && info?.esValido == false);
                final bool esIncompleta = info?.esCicloIncompleto == true;

                final String estadoTexto = esCompartida
                    ? '🟡 PARCIAL (${info!.cupoDisponible} disp)'
                    : (esLlena
                        ? '🔴 LLENA (${info!.cantidadOcupada}/${info.limiteMaximo})'
                        : (esIncompleta ? '🟠 CICLO (-${info!.diasFaltantes}d)' : '🟢 DISPONIBLE'));

                final Color estadoColor = esCompartida
                    ? const Color(0xFFE65100)
                    : (esLlena
                        ? Colors.red.shade800
                        : (esIncompleta ? Colors.orange.shade800 : Colors.green.shade800));

                final Color estadoBg = esCompartida
                    ? const Color(0xFFFFF8E1)
                    : (esLlena
                        ? Colors.red.shade50
                        : (esIncompleta ? Colors.orange.shade50 : Colors.green.shade50));

                final Color estadoBorder = esCompartida
                    ? const Color(0xFFFFB300)
                    : (esLlena
                        ? Colors.red.shade200
                        : (esIncompleta ? Colors.orange.shade300 : Colors.green.shade200));

                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cama ${c.cama}', style: const TextStyle(fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: estadoBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: estadoBorder),
                        ),
                        child: Text(
                          estadoTexto,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _bloqueSeleccionado == null
                  ? null
                  : (val) {
                      setState(() => _camaSeleccionada = val);
                    },
            ),
          ),
        ),
        if (_camaSeleccionada != null) ...[
          Builder(
            builder: (context) {
              final info = _estadoCicloCamas[_camaSeleccionada!.id];
              if (info == null) return const SizedBox.shrink();

              if (info.esCamaCompartida) {
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFB300)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group_work, color: Color(0xFFE65100), size: 14),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Cama Compartida (Multisembrador / Multi-variedad)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('• Ocupado: ${info.cantidadOcupada} de ${info.limiteMaximo} plantas (Cupo: ${info.cupoDisponible} disp)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      if (info.variedadesPresentes.isNotEmpty)
                        Text('• Variedades: ${info.variedadesPresentes.join(", ")}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                      if (info.operariosPresentes.isNotEmpty)
                        Text('• Sembradores: ${info.operariosPresentes.join(", ")}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    ],
                  ),
                );
              } else if (!info.esValido) {
                final esActiva = info.esCicloActivo;
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: esActiva ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: esActiva ? Colors.red.shade300 : Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(esActiva ? Icons.block : Icons.timelapse, color: esActiva ? Colors.red : Colors.orange.shade900, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              esActiva ? '🚫 CAPACIDAD COMPLETA EN CICLO' : '⚠️ CICLO INCOMPLETO',
                              style: TextStyle(
                                fontSize: 11,
                                color: esActiva ? Colors.red.shade900 : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        info.mensaje,
                        style: TextStyle(fontSize: 10.5, color: esActiva ? Colors.red.shade900 : Colors.brown.shade900),
                      ),
                      if (!info.esCamaCompartida) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 1,
                            ),
                            icon: const Icon(Icons.bolt, color: Colors.white, size: 16),
                            label: const Text(
                              '¿Cama ya cortada? Liberar Cama Ahora',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: () async {
                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.bolt, color: Color(0xFF2E7D32)),
                                      SizedBox(width: 8),
                                      Text('Liberar Cama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text(
                                    '¿Desea marcar como cortada la siembra previa en Cama ${_camaSeleccionada!.cama} y liberarla de inmediato para sembrar hoy?',
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Sí, Liberar Cama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmar == true) {
                                await _db.liberarCamaPorCorteAnticipado(_camaSeleccionada!.id, _fechaSeleccionada ?? '');
                                await _recargarCiclosCamas();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Cama ${_camaSeleccionada!.cama} liberada. Ya puede registrar la nueva siembra.'),
                                      backgroundColor: const Color(0xFF2E7D32),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCampoOperario() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC5E1A5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7CB342).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.all_inbox, color: Color(0xFF33691E), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIEMBRA COLECTIVA (SIN OPERARIO EN CAMA)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  'El rendimiento en Lirios se mide por entrega de canastas a los operarios.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            icon: const Icon(Icons.shopping_basket, size: 18),
            label: const Text(
              'Medir Canastas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RendimientoLiriosScreen(
                    subgrupoInicial: widget.subtipo,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCampoVariedad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Variedad'),
        InkWell(
          onTap: _abrirBuscadorVariedades,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _variedadSeleccionada != null
                    ? const Color(0xFF7CB342)
                    : Colors.grey.shade400,
                width: _variedadSeleccionada != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_florist, color: Color(0xFF7CB342), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _variedadSeleccionada != null
                        ? '${_variedadSeleccionada!.nombre} (${_variedadSeleccionada!.codigo})'
                        : 'Buscar variedad...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _variedadSeleccionada != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _variedadSeleccionada != null
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search, color: Color(0xFF7CB342)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoLineas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('# Parrillas'),
        TextFormField(
          controller: _lineasController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ej: 14',
            helperText: 'Dens: $_densidadParrilla bulbos/parrilla',
            helperStyle: const TextStyle(color: Color(0xFF558B2F), fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) {
            _recalcularTallosPorLineas();
          },
        ),
      ],
    );
  }

  Widget _buildCampoTallos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Bulbos x sembrar'),
        Builder(
          builder: (context) {
            final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2916;
            final int tallosActuales = int.tryParse(_tallosController.text.trim()) ?? 0;
            final bool excede = tallosActuales > limitePermitido;

            return TextFormField(
              controller: _tallosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Máx: $limitePermitido',
                helperText: excede
                    ? '⚠️ Excede límite de $limitePermitido bulbos'
                    : 'Máximo: $limitePermitido bulbos/cama',
                helperStyle: TextStyle(
                  color: excede ? Colors.red.shade800 : const Color(0xFF558B2F),
                  fontWeight: FontWeight.bold,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: excede ? Colors.red.shade50 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: excede ? Colors.red : Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: excede ? Colors.red : const Color(0xFF7CB342), width: 2),
                ),
              ),
              onChanged: (val) {
                setState(() {});
              },
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Obligatorio';
                }
                final int? cant = int.tryParse(val.trim());
                if (cant == null || cant <= 0) {
                  return 'Inválido';
                }
                if (cant > limitePermitido) {
                  return '❌ Máx: $limitePermitido (Ingresó: $cant)';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCampoProveedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Proveedor *'),
            if (_proveedorSeleccionado != null)
              InkWell(
                onTap: () => _onProveedorCambiado(null),
                child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _proveedorSeleccionado != null ? const Color(0xFF7CB342) : Colors.grey.shade400,
              width: _proveedorSeleccionado != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Proveedor...'),
              value: _proveedores187.contains(_proveedorSeleccionado) ? _proveedorSeleccionado : null,
              items: _proveedores187.map((p) {
                return DropdownMenuItem<String>(
                  value: p,
                  child: Text(
                    p,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onProveedorCambiado,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoContenedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Contenedor *'),
            if (_contenedorSeleccionado != null)
              InkWell(
                onTap: () => _onContenedorCambiado(null),
                child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _contenedorSeleccionado != null ? const Color(0xFF7CB342) : Colors.grey.shade400,
              width: _contenedorSeleccionado != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Contenedor...'),
              value: _contenedoresFiltrados.contains(_contenedorSeleccionado) ? _contenedorSeleccionado : null,
              items: _contenedoresFiltrados.map((c) {
                return DropdownMenuItem<String>(
                  value: c,
                  child: Text(
                    'Cont. $c',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onContenedorCambiado,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoLote() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Lote (Tabla 187) *'),
            Row(
              children: [
                if (_loteSeleccionado != null)
                  InkWell(
                    onTap: () => _onLoteCambiado(null),
                    child: const Text('Limpiar  ', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                InkWell(
                  onTap: _abrirBuscadorLotes,
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 14, color: Color(0xFF558B2F)),
                      SizedBox(width: 2),
                      Text('Buscar', style: TextStyle(fontSize: 11, color: Color(0xFF558B2F), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _loteSeleccionado != null ? const Color(0xFF7CB342) : Colors.grey.shade400,
              width: _loteSeleccionado != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                _lotesFiltrados.isEmpty
                    ? 'Sin lotes'
                    : 'Lote (${_lotesFiltrados.length})...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              value: _lotesFiltrados.contains(_loteSeleccionado) ? _loteSeleccionado : null,
              items: _lotesFiltrados.map((l) {
                return DropdownMenuItem<String>(
                  value: l,
                  child: Text(
                    l,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onLoteCambiado,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoObservaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildLabel('Observaciones'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _observacionesController,
          decoration: InputDecoration(
            hintText: 'Notas adicionales (opcional)...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerFormula() {
    if (_lineasController.text.trim().isEmpty) return const SizedBox.shrink();
    return Builder(builder: (context) {
      final int? p = int.tryParse(_lineasController.text.trim());
      final int factor = _densidadParrilla;
      final int total = (p ?? 0) * factor;
      final String varNombre = _variedadSeleccionada?.nombre ?? widget.subtipo;
      final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2916;
      final bool excede = total > limitePermitido;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: excede ? Colors.red.shade50 : const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: excede ? Colors.red.shade300 : const Color(0xFFC5E1A5)),
        ),
        child: Row(
          children: [
            Icon(excede ? Icons.warning_amber_rounded : Icons.calculate, color: excede ? Colors.red.shade800 : const Color(0xFF33691E), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '📐 Cálculo: ${p ?? 0} parrillas × $factor bulbos/parrilla = $total bulbos ($varNombre)${excede ? " ⚠️ (Supera límite de $limitePermitido)" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: excede ? Colors.red.shade800 : const Color(0xFF33691E),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMiniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }

  Widget _buildChipDetalle(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerLoteInfo() {
    if (_loteSeleccionado == null) return const SizedBox.shrink();
    return Builder(builder: (context) {
      final matches = _todosLirios187.where((e) => e.lote == _loteSeleccionado).toList();
      final p = matches.isNotEmpty ? matches.first.proveedor : (_proveedorSeleccionado ?? '');
      final c = matches.isNotEmpty ? matches.first.contenedor : (_contenedorSeleccionado ?? '');
      final v = matches.isNotEmpty ? matches.first.variedad : null;

      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF81C784), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DETALLES DE COMPRA (TABLA 187)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Lote $_loteSeleccionado',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChipDetalle(Icons.business, 'Proveedor', p.isNotEmpty ? p : 'Sin definir'),
                _buildChipDetalle(Icons.directions_boat, 'Contenedor', c.isNotEmpty ? c : 'Sin definir'),
                if (v != null && v.isNotEmpty)
                  _buildChipDetalle(Icons.local_florist, 'Variedad origen', v),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBotonesAccion(bool esMovil) {
    if (esMovil) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7CB342),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              onPressed: _guardando ? null : _guardarSiembra,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _guardando ? 'Guardando...' : 'Guardar Siembra',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7CB342),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 3,
          ),
          onPressed: _guardando ? null : _guardarSiembra,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.save, color: Colors.white),
          label: Text(
            _guardando ? 'Guardando...' : 'Guardar Siembra',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esMovil = Responsive.isMobile(context);
    final String tituloTexto = esMovil ? widget.subtipo : 'SIEMBRA ${widget.subtipo}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_florist, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tituloTexto.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: esMovil
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF33691E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 38),
                      icon: const Icon(Icons.shopping_basket, size: 20, color: Colors.white),
                      tooltip: 'Rendimiento Canastas',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RendimientoLiriosScreen(
                              subgrupoInicial: widget.subtipo,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF33691E),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.shopping_basket, size: 16, color: Colors.white),
                    label: const Text(
                      'CANASTAS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RendimientoLiriosScreen(
                            subgrupoInicial: widget.subtipo,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 6),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF33691E),
                elevation: 1,
                padding: EdgeInsets.symmetric(horizontal: esMovil ? 10 : 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _guardando ? null : _guardarSiembra,
              icon: _guardando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF33691E)),
                    )
                  : const Icon(Icons.check_circle, size: 18, color: Color(0xFF33691E)),
              label: Text(
                _guardando ? '...' : 'GUARDAR',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 24),
              tooltip: 'Volver al Inicio',
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: esMovil ? 14 : 24,
              vertical: 10,
            ),
            child: ResponsiveContentContainer(
              maxWidth: 960,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Informativo de Parámetros Agronómicos Fijados por el Administrador
                  Builder(
                    builder: (context) {
                      final cfg = _configAgronomica;
                      final int limite = _variedadSeleccionada?.limiteEsquejes ?? cfg?.limiteEsquejes ?? 2916;
                      final int dias = _variedadSeleccionada?.diasCiclo ?? cfg?.diasCiclo ?? 105;
                      final fInicio = parsearFechaSiembra(_fechaSeleccionada) ?? DateTime.now();
                      final semSiembra = CalendarioUtil.obtenerSemanaUS(fInicio);
                      final fEst = fInicio.add(Duration(days: dias));
                      final semCosecha = CalendarioUtil.obtenerSemanaUS(fEst);
                      final fEstStr = "${fEst.day.toString().padLeft(2, '0')}/${fEst.month.toString().padLeft(2, '0')}/${fEst.year}";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC5E1A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user, color: Color(0xFF558B2F), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Parámetros Agronómicos (${_variedadSeleccionada?.nombre ?? widget.subtipo}): Máx: $limite plant/cama | Ciclo: $dias d | Sem. Siembra: Sem $semSiembra | Cosecha Est.: $fEstStr (Sem. $semCosecha)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Fila 1: FECHA | BLOQUE | CAMA
                  if (esMovil) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCampoFecha()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCampoBloque()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCampoCama(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildCampoFecha()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildCampoBloque()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildCampoCama()),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Fila 2: OPERARIO | VARIEDAD | # LÍNEAS
                  if (esMovil) ...[
                    _buildCampoOperario(),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildCampoVariedad()),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildCampoLineas()),
                      ],
                    ),
                  ] else ...[
                    _buildCampoOperario(),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildCampoVariedad()),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: _buildCampoLineas()),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Fila 3: TALLOS X SEMBRAR | PROVEEDOR | CONTENEDOR
                  if (esMovil) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCampoTallos()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCampoContenedor()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCampoProveedor(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildCampoTallos()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildCampoProveedor()),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: _buildCampoContenedor()),
                      ],
                    ),
                  ],

                  // Fórmula informativa de líneas x densidad
                  _buildBannerFormula(),

                  const SizedBox(height: 10),

                  // Fila 4: LOTE (Tabla 187) | OBSERVACIONES
                  if (esMovil) ...[
                    _buildCampoLote(),
                    const SizedBox(height: 10),
                    _buildCampoObservaciones(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildCampoLote()),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: _buildCampoObservaciones()),
                      ],
                    ),
                  ],

                  // Info Lote Tabla 187
                  _buildBannerLoteInfo(),

                  const SizedBox(height: 16),

                  // Botones de Acción
                  _buildBotonesAccion(esMovil),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

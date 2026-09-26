import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

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
  final DbRepository _db = DbRepository();

  // Catálogos
  List<Bloque> _bloques = [];
  List<Cama> _camasDelBloque = [];
  List<Operario> _operarios = [];
  List<Variedad> _variedades = [];
  List<Variedad> _todasLasVariedades = [];
  Map<int, ValidacionCicloResultado> _estadoCicloCamas = {};
  ConfigAgronomica? _configAgronomica;

  // Variables seleccionadas
  String? _fechaSeleccionada;
  Bloque? _bloqueSeleccionado;
  Cama? _camaSeleccionada;
  Operario? _operarioSeleccionado;
  Variedad? _variedadSeleccionada;
  bool _recordarOperario = false;
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
  final TextEditingController _lineasController = TextEditingController(text: '14');
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
    final o = await _db.obtenerOperarios();
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
      _operarios = o;
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Buscar Lote - Tabla 187 (${lotesDisponibles.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF33691E)),
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
                            itemCount: lista.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = lista[i];
                              final isSelected = _loteSeleccionado == item;
                              final detalles = _todosLirios187.where((e) => e.lote == item).toList();
                              final prov = detalles.isNotEmpty ? detalles.first.proveedor : '';
                              final cont = detalles.isNotEmpty ? detalles.first.contenedor : '';
                              final varNom = detalles.isNotEmpty && detalles.first.variedad != null
                                  ? detalles.first.variedad!
                                  : '';

                              return ListTile(
                                tileColor: isSelected
                                    ? const Color(0xFF7CB342).withValues(alpha: 0.15)
                                    : null,
                                title: Text(
                                  'Lote: $item',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF33691E) : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  'Prov: $prov | Cont: $cont${varNom.isNotEmpty ? " | Var: $varNom" : ""}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF7CB342))
                                    : null,
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Catálogo: ${verTodas ? "Todas las Variedades (${_todasLasVariedades.length})" : "Variedades de Lirios (${_variedades.length})"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF33691E)),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(verTodas ? Icons.filter_alt : Icons.all_inclusive, size: 16, color: const Color(0xFF7CB342)),
                        label: Text(
                          verTodas ? 'Filtrar por Lirios' : 'Ver todo el catálogo',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF558B2F)),
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
                  TextField(
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
                  const SizedBox(height: 10),
                  Expanded(
                    child: lista.isEmpty
                        ? const Center(child: Text('No se encontraron variedades'))
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
                                title: Text(
                                  item.nombre,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF33691E) : Colors.black87,
                                  ),
                                ),
                                subtitle: Text('Código: ${item.codigo}${item.colorNombre != null ? ' | Color: ${item.colorNombre}' : ''}${item.familiaNombre != null ? ' | ${item.familiaNombre}' : ''}'),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF7CB342))
                                    : null,
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
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
    }
  }

  void _recalcularTallosPorLineas() {
    final int? l = int.tryParse(_lineasController.text.trim());
    if (l != null && l > 0) {
      final int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 15;
      setState(() {
        _tallosController.text = (l * factor).toString();
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

    if (_operarioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione un operario')),
      );
      return;
    }

    // Validación 1: Verificar restricciones de ciclo agronómico y disponibilidad de cama
    final validacionCiclo = await _db.validarCicloYCamaParaSiembra(
      _camaSeleccionada!.id,
      _fechaSeleccionada ?? '',
    );

    if (!validacionCiclo.esValido) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                validacionCiclo.esCicloActivo ? Icons.block : Icons.timelapse,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Restricción de Ciclo Agronómico',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Cama: ${_camaSeleccionada!.cama} (Bloque ${_bloqueSeleccionado!.codigo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (validacionCiclo.variedadPreviaNombre != null)
                      Text('• Variedad previa: ${validacionCiclo.variedadPreviaNombre}'),
                    Text('• Días transcurridos: ${validacionCiclo.diasTranscurridos} días'),
                    Text('• Ciclo agronómico requerido: ${validacionCiclo.diasRequeridos} días'),
                    if (validacionCiclo.diasFaltantes > 0)
                      Text('• Días faltantes para liberar la cama: ${validacionCiclo.diasFaltantes} días', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido (Corregir Cama)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return; // ESTRICTAMENTE BLOQUEADO POR CICLO
    }

    final int? tallos = int.tryParse(_tallosController.text.trim());
    if (tallos == null || tallos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese una cantidad válida de tallos')),
      );
      return;
    }

    // Validación 2: Verificar límite agronómico estricto fijado por el Administrador
    final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2600;
    if (tallos > limitePermitido) {
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

    final int lineas = int.tryParse(_lineasController.text.trim()) ?? 14;

    setState(() => _guardando = true);

    try {
      final nuevaSiembra = Siembra(
        fecha: _fechaSeleccionada ?? '',
        bloqueCodigo: _bloqueSeleccionado!.codigo,
        camaId: _camaSeleccionada!.id,
        operarioId: _operarioSeleccionado!.id,
        variedadId: _variedadSeleccionada!.id,
        cantidad: tallos,
        estado: 'ACTIVA',
        lineas: lineas,
        cont: _contenedorSeleccionado ?? (_conteoController.text.trim().isNotEmpty ? _conteoController.text.trim() : null),
        proveedor: _proveedorSeleccionado ?? (_proveedorController.text.trim().isNotEmpty ? _proveedorController.text.trim() : null),
        lote: _loteSeleccionado ?? (_loteController.text.trim().isNotEmpty ? _loteController.text.trim() : null),
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
        sincronizado: 0,
      );

      await _db.registrarSiembraOffline(nuevaSiembra);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Siembra de ${widget.subtipo} guardada exitosamente (Offline) ✅',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF558B2F),
        ),
      );

      // Regresar al Dashboard refrescando datos
      Navigator.popUntil(context, (route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_florist, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              'SIEMBRA LIRIOS (${widget.subtipo})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 19,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF33691E),
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                _guardando ? 'GUARDANDO...' : 'GUARDAR',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 26),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                                // Banner Informativo de Parámetros Agronómicos Fijados por el Administrador
                Builder(
                  builder: (context) {
                    final cfg = _configAgronomica;
                    final int limite = _variedadSeleccionada?.limiteEsquejes ?? cfg?.limiteEsquejes ?? 2600;
                    final int dias = _variedadSeleccionada?.diasCiclo ?? cfg?.diasCiclo ?? 90;
                    final fInicio = parsearFechaSiembra(_fechaSeleccionada) ?? DateTime.now();
                    final fEst = fInicio.add(Duration(days: dias));
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
                              'Parámetros Agronómicos (${_variedadSeleccionada?.nombre ?? widget.subtipo}): Máx: $limite plant/cama | Ciclo: $dias d | Cosecha Est.: $fEstStr',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Fecha'),
                          InkWell(
                            onTap: _seleccionarFecha,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fechaSeleccionada ?? 'dd/mm/aaaa',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  const Icon(Icons.calendar_today, color: Color(0xFF7CB342), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Bloque
                    Expanded(
                      flex: 4,
                      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Cama
                    Expanded(
                      flex: 3,
                      child: Column(
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
                                  final bool noDisp = info != null && !info.esValido;
                                  final bool esActiva = info?.esCicloActivo == true;
                                  final String estadoTexto = esActiva
                                      ? '🔴 EN CICLO'
                                      : (noDisp ? '🟠 CICLO (-${info.diasFaltantes}d)' : '🟢 DISPONIBLE');
                                  final Color estadoColor = esActiva
                                      ? Colors.red.shade800
                                      : (noDisp ? Colors.orange.shade800 : Colors.green.shade800);
                                  final Color estadoBg = esActiva
                                      ? Colors.red.shade50
                                      : (noDisp ? Colors.orange.shade50 : Colors.green.shade50);
                                  final Color estadoBorder = esActiva
                                      ? Colors.red.shade200
                                      : (noDisp ? Colors.orange.shade300 : Colors.green.shade200);

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
                          if (_camaSeleccionada != null && _estadoCicloCamas[_camaSeleccionada!.id]?.esValido == false) ...[
                            Builder(
                              builder: (context) {
                                final info = _estadoCicloCamas[_camaSeleccionada!.id]!;
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
                                              esActiva ? '🚫 CAMA EN CICLO ACTIVO' : '⚠️ CICLO INCOMPLETO',
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
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Fila 2: OPERARIO | VARIEDAD | # LÍNEAS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operario
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Operario'),
                              Row(
                                children: [
                                  Text(
                                    'Fijar',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                  ),
                                  Transform.scale(
                                    scale: 0.7,
                                    child: Switch(
                                      value: _recordarOperario,
                                      activeColor: const Color(0xFF7CB342),
                                      onChanged: (val) => setState(() => _recordarOperario = val),
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
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Operario>(
                                isExpanded: true,
                                hint: const Text('Seleccionar operario...'),
                                value: _operarioSeleccionado,
                                items: _operarios.map((o) {
                                  return DropdownMenuItem(
                                    value: o,
                                    child: Text(
                                      o.nombreCompleto,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _operarioSeleccionado = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Variedad
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    // # Líneas
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          _buildLabel('# Líneas'),
                          TextFormField(
                            controller: _lineasController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ej: 100',
                              helperText: 'Dens: ${_variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 15} pl/l',
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
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Fila 3: TALLOS X SEMBRAR | PROVEEDOR (Lista Desplegable Tabla 187) | CONTENEDOR (Lista Desplegable Tabla 187)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tallos
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Tallos x sembrar'),
                          Builder(
                            builder: (context) {
                              final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2600;
                              final int tallosActuales = int.tryParse(_tallosController.text.trim()) ?? 0;
                              final bool excede = tallosActuales > limitePermitido;

                              return TextFormField(
                                controller: _tallosController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Máx: $limitePermitido',
                                  helperText: excede
                                      ? '⚠️ Excede el límite de $limitePermitido plantas'
                                      : 'Máximo: $limitePermitido plantas/cama',
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Proveedor (Lista desplegable Tabla 187)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Proveedor'),
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Contenedor (Lista desplegable Tabla 187)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Contenedor'),
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
                      ),
                    ),
                  ],
                ),

                if (_lineasController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final int? l = int.tryParse(_lineasController.text.trim());
                    final int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 15;
                    final int total = (l ?? 0) * factor;
                    final String varNombre = _variedadSeleccionada?.nombre ?? 'LIRIOS';
                    final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2600;
                    final bool excede = total > limitePermitido;

                    return Container(
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
                              '📐 Fórmula: ${l ?? 0} líneas × $factor pl/línea = $total plantas ($varNombre)${excede ? " ⚠️ (Supera límite de $limitePermitido)" : ""}',
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
                  }),
                ],

                const SizedBox(height: 8),

                // Fila 4: LOTE (Lista Desplegable Tabla 187) | OBSERVACIONES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Lote (Tabla 187)'),
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 6,
                      child: Column(
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
                      ),
                    ),
                  ],
                ),

                if (_loteSeleccionado != null) ...[
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final matches = _todosLirios187.where((e) => e.lote == _loteSeleccionado).toList();
                    final p = matches.isNotEmpty ? matches.first.proveedor : (_proveedorSeleccionado ?? '');
                    final c = matches.isNotEmpty ? matches.first.contenedor : (_contenedorSeleccionado ?? '');
                    final v = matches.isNotEmpty ? matches.first.variedad : null;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Color(0xFF2E7D32), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lote $_loteSeleccionado (Tabla 187) ➔ Proveedor: $p | Contenedor: $c${v != null ? " | Variedad: $v" : ""}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 12),

                // Botones de Acción
                Row(
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
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

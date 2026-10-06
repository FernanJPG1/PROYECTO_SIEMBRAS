import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';
import 'package:app_movil/widgets/crear_variedad_dialog.dart';

class FormSiembraPomponScreen extends StatefulWidget {
  final String cultivo;

  const FormSiembraPomponScreen({
    super.key,
    this.cultivo = 'Pompon',
  });

  @override
  State<FormSiembraPomponScreen> createState() => _FormSiembraPomponScreenState();
}

class _FormSiembraPomponScreenState extends State<FormSiembraPomponScreen> {
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

  // Controladores
  final TextEditingController _lineasController = TextEditingController();
  final TextEditingController _tallosController = TextEditingController();
  final TextEditingController _loteController = TextEditingController();
  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _contController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  // Controladores y estado para división de cama en dos lados
  String _ladoSeleccionado = 'LADO_A'; // 'LADO_A', 'LADO_B', 'AMBOS', 'MIXTO'
  final TextEditingController _lineasLadoAController = TextEditingController();
  final TextEditingController _lineasLadoBController = TextEditingController();

  /// Identifica si el cultivo o área actual corresponde a plantas madre, núcleos o bancos
  bool get _esPlantaMadreOBancoONucleo {
    final c = widget.cultivo.toUpperCase();
    return c.contains('MADRE') || c.contains('BANCO') || c.contains('NÚCLEO') || c.contains('NUCLEO');
  }

  /// Indica si este cultivo tiene división de cama en dos lados (Pompón y Cremón por ahora)
  bool get _tieneDivisionDosLados {
    final c = widget.cultivo.toUpperCase();
    if (c.contains('POMPON') || c.contains('POMPÓN')) return true;
    if (c.contains('CREMON') || c.contains('CREMÓN')) return true;
    final f = (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase();
    if (f.contains('POMPON') || f.contains('POMPÓN')) return true;
    if (f.contains('CREMON') || f.contains('CREMÓN')) return true;
    return false;
  }

  /// Densidad por línea para el Lado A según el cultivo (Pompón: 13, Cremón: 11)
  int get _densidadLadoA {
    final c = widget.cultivo.toUpperCase();
    if (c.contains('POMPON') || c.contains('POMPÓN')) return 13;
    if (c.contains('CREMON') || c.contains('CREMÓN')) return 11;
    final f = (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase();
    if (f.contains('POMPON') || f.contains('POMPÓN')) return 13;
    if (f.contains('CREMON') || f.contains('CREMÓN')) return 11;
    return 13;
  }

  /// Densidad por línea para el Lado B según el cultivo (Pompón: 12, Cremón: 11)
  int get _densidadLadoB {
    final c = widget.cultivo.toUpperCase();
    if (c.contains('POMPON') || c.contains('POMPÓN')) return 12;
    if (c.contains('CREMON') || c.contains('CREMÓN')) return 11;
    final f = (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase();
    if (f.contains('POMPON') || f.contains('POMPÓN')) return 12;
    if (f.contains('CREMON') || f.contains('CREMÓN')) return 11;
    return 12;
  }

  /// Densidad por línea de la cama completa (ambos lados sumados: Pompón 25, Cremón 22)
  int get _densidadCamaCompleta => _densidadLadoA + _densidadLadoB;

  /// Pompon y Cremon requieren obligatoriamente el Clon (ej: 4-25, 3-25).
  /// En los demás cultivos es opcional.
  bool get _requiereClon {
    final c = widget.cultivo.toUpperCase();
    if (c.contains('POMPON') || c.contains('CREMON')) return true;
    final f = (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase();
    if (f.contains('POMPON') || f.contains('CREMON')) return true;
    final n = (_variedadSeleccionada?.nombre ?? '').toUpperCase();
    if (n.contains('POMPON') || n.contains('CREMON')) return true;
    return false;
  }

  @override
  void dispose() {
    _lineasController.dispose();
    _tallosController.dispose();
    _loteController.dispose();
    _proveedorController.dispose();
    _contController.dispose();
    _observacionesController.dispose();
    _lineasLadoAController.dispose();
    _lineasLadoBController.dispose();
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
    List<int> famIds = [];
    final t = widget.cultivo.toLowerCase();
    if (t.contains('cremon')) {
      // Cremon / Fuji / Disbud Cremons
      famIds = [193, 200, 148];
    } else if (t.contains('pompon') || t.contains('crisan')) {
      famIds = [147];
    } else if (t.contains('matsumoto')) {
      famIds = [114, 118, 262];
    } else if (t.contains('gerbera')) {
      famIds = [146, 219];
    } else if (t.contains('girasol') || t.contains('sunflower')) {
      famIds = [213];
    } else if (t.contains('alstroemeria')) {
      famIds = [155, 218];
    }

    final allV = await _db.obtenerVariedades(soloActivas: true);
    final v = famIds.isNotEmpty
        ? await _db.obtenerVariedadesPorFamilia(famIds, soloActivas: true)
        : allV;
    final o = await _db.obtenerOperarios();
    final cfg = await _db.obtenerConfigAgronomica(cultivo: widget.cultivo);

    if (!mounted) return;
    setState(() {
      _bloques = b;
      _variedades = v;
      _todasLasVariedades = allV;
      _operarios = o;
      _configAgronomica = cfg;
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
                      // Barra de filtro con toggle
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Catálogo: ${verTodas ? "Todas (${_todasLasVariedades.length})" : "${widget.cultivo} (${_variedades.length})"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF33691E)),
                          ),
                          TextButton.icon(
                            icon: Icon(verTodas ? Icons.filter_alt : Icons.all_inclusive, size: 16, color: const Color(0xFF7CB342)),
                            label: Text(
                              verTodas ? 'Filtrar por ${widget.cultivo}' : 'Ver todo el catálogo',
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
                            hintText: 'Escribe para buscar variedad...',
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
                              cultivoSugerido: widget.cultivo,
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
                                        cultivoSugerido: widget.cultivo,
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
      final cfgVar = await _db.obtenerConfigAgronomicaParaVariedad(seleccionada, cultivoFallback: widget.cultivo);
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

  void _recalcularTallosPorLineas() {
    if (_tieneDivisionDosLados) {
      if (_ladoSeleccionado == 'MIXTO') {
        final int lA = int.tryParse(_lineasLadoAController.text.trim()) ?? 0;
        final int lB = int.tryParse(_lineasLadoBController.text.trim()) ?? 0;
        final int totalTallos = (lA * _densidadLadoA) + (lB * _densidadLadoB);
        final int totalLineas = (lA > lB) ? lA : lB;
        setState(() {
          _tallosController.text = totalTallos > 0 ? totalTallos.toString() : '';
          _lineasController.text = totalLineas > 0 ? totalLineas.toString() : '';
        });
        return;
      }

      final int? l = int.tryParse(_lineasController.text.trim());
      if (l != null && l > 0) {
        int factor = _densidadCamaCompleta;
        if (_ladoSeleccionado == 'LADO_A') factor = _densidadLadoA;
        if (_ladoSeleccionado == 'LADO_B') factor = _densidadLadoB;

        setState(() {
          _tallosController.text = (l * factor).toString();
        });
      }
      return;
    }

    // Cultivos estándar
    final int? l = int.tryParse(_lineasController.text.trim());
    if (l != null && l > 0) {
      final int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20;
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

    if (!_esPlantaMadreOBancoONucleo && _operarioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione un operario')),
      );
      return;
    }

    final int? tallos = int.tryParse(_tallosController.text.trim());
    if (tallos == null || tallos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese una cantidad válida de tallos')),
      );
      return;
    }

    // Validación 1: Verificar restricciones de capacidad de cama y ciclo (soporta multisembrador y multi-variedad)
    final validacionCiclo = await _db.validarCicloYCamaParaSiembra(
      _camaSeleccionada!.id,
      _fechaSeleccionada ?? '',
      nuevaCantidad: tallos,
      nuevaVariedadId: _variedadSeleccionada!.id,
      nuevoOperarioId: _operarioSeleccionado?.id ?? 0,
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
    final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 4050;
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
                'La cantidad ingresada ($tallos esquejes) supera la restricción máxima de $limitePermitido esquejes por cama configurada para ${_variedadSeleccionada?.nombre ?? widget.cultivo}.\n\n'
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
                    Text('• Cantidad ingresada: $tallos esquejes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('• Restricción máxima permitida: $limitePermitido esquejes', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    Text('• Exceso bloqueado: ${tallos - limitePermitido} esquejes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
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

    // Validación de Clon: Obligatorio para Pompon y Cremon
    if (_requiereClon && _observacionesController.text.trim().isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Clon Obligatorio', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Para el cultivo de ${widget.cultivo}, es OBLIGATORIO ingresar el CLON correspondiente (ej: 4-25, 3-25).\n\nPor favor complete el campo Clon antes de guardar la siembra.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    int totalLineas = int.tryParse(_lineasController.text.trim()) ?? 14;
    String? detalleLado;
    if (_tieneDivisionDosLados) {
      if (_ladoSeleccionado == 'LADO_A') {
        detalleLado = 'LADO A ($_densidadLadoA esq/lín)';
      } else if (_ladoSeleccionado == 'LADO_B') {
        detalleLado = 'LADO B ($_densidadLadoB esq/lín)';
      } else if (_ladoSeleccionado == 'AMBOS') {
        detalleLado = 'CAMA COMPLETA ($_densidadCamaCompleta esq/lín)';
      } else if (_ladoSeleccionado == 'MIXTO') {
        final int lA = int.tryParse(_lineasLadoAController.text.trim()) ?? 0;
        final int lB = int.tryParse(_lineasLadoBController.text.trim()) ?? 0;
        detalleLado = 'MIXTO: Lado A ($lA lín) + Lado B ($lB lín)';
        if (lA > totalLineas || lB > totalLineas) {
          totalLineas = (lA > lB) ? lA : lB;
        }
      }
    }

    String? obsFinal;
    final userObs = _observacionesController.text.trim().toUpperCase();
    if (detalleLado != null && userObs.isNotEmpty) {
      obsFinal = '$userObs | $detalleLado';
    } else if (detalleLado != null) {
      obsFinal = detalleLado;
    } else if (userObs.isNotEmpty) {
      obsFinal = userObs;
    }

    setState(() => _guardando = true);

    try {
      final nuevaSiembra = Siembra(
        fecha: _fechaSeleccionada ?? '',
        bloqueCodigo: _bloqueSeleccionado!.codigo,
        camaId: _camaSeleccionada!.id,
        operarioId: _operarioSeleccionado?.id ?? 0,
        variedadId: _variedadSeleccionada!.id,
        cantidad: tallos,
        estado: 'ACTIVA',
        lineas: totalLineas,
        corte: CalendarioUtil.obtenerEtiquetaCorta(CalendarioUtil.parsearFecha(_fechaSeleccionada) ?? DateTime.now()),
        lote: _loteController.text.trim().isNotEmpty ? _loteController.text.trim() : null,
        proveedor: _proveedorController.text.trim().isNotEmpty ? _proveedorController.text.trim() : null,
        cont: _contController.text.trim().isNotEmpty ? _contController.text.trim() : null,
        observaciones: obsFinal,
        sincronizado: 0,
      );

      await _db.registrarSiembraOffline(nuevaSiembra);

      // Recargar estados de las camas del bloque para reflejar de inmediato la nueva ocupación y cupo
      await _recargarCiclosCamas();

      if (!mounted) return;

      final String nombreVariedad = _variedadSeleccionada?.nombre ?? 'Variedad';
      final String nombreCama = _camaSeleccionada?.cama ?? '';
      final infoCama = _camaSeleccionada != null ? _estadoCicloCamas[_camaSeleccionada!.id] : null;

      // Limpiar datos de la variedad sembrada para permitir registrar la siguiente
      setState(() {
        _variedadSeleccionada = null;
        _tallosController.clear();
        _observacionesController.clear();
        if (!_recordarOperario) {
          _operarioSeleccionado = null;
        }
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const Icon(Icons.calendar_today, color: Color(0xFF7CB342), size: 20),
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
    if (_esPlantaMadreOBancoONucleo) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Operario / Sembrador'),
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
                    activeThumbColor: const Color(0xFF7CB342),
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
                        : 'Toca para buscar variedad...',
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

  Widget _buildSelectorLadoCama() {
    if (!_tieneDivisionDosLados) {
      return const SizedBox.shrink();
    }

    final esPompon = widget.cultivo.toUpperCase().contains('POMPON') ||
        widget.cultivo.toUpperCase().contains('POMPÓN') ||
        (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase().contains('POMPON');
    final nombreCultivo = esPompon ? 'Pompón' : 'Cremón';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFAED581)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.splitscreen_rounded, color: Color(0xFF33691E), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'División de Cama ($nombreCultivo: Total $_densidadCamaCompleta esq/lín)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Seleccione qué lado sembró este sembrador o si terminó su lado y pasó al otro:',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBotonLado(
                id: 'LADO_A',
                titulo: 'Lado A',
                subtitulo: '$_densidadLadoA esq/lín',
                icono: Icons.arrow_back,
              ),
              _buildBotonLado(
                id: 'LADO_B',
                titulo: 'Lado B',
                subtitulo: '$_densidadLadoB esq/lín',
                icono: Icons.arrow_forward,
              ),
              _buildBotonLado(
                id: 'AMBOS',
                titulo: 'Cama Completa',
                subtitulo: '$_densidadCamaCompleta esq/lín',
                icono: Icons.view_column_rounded,
              ),
              _buildBotonLado(
                id: 'MIXTO',
                titulo: 'Pasó al otro lado',
                subtitulo: 'Lado A + Lado B',
                icono: Icons.swap_horiz_rounded,
              ),
            ],
          ),
          if (_ladoSeleccionado == 'MIXTO') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ingrese abajo cuántas líneas sembró en Lado A ($_densidadLadoA esq/l) y cuántas en Lado B ($_densidadLadoB esq/l).',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotonLado({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icono,
  }) {
    final bool seleccionado = _ladoSeleccionado == id;
    return InkWell(
      onTap: () {
        setState(() {
          _ladoSeleccionado = id;
        });
        _recalcularTallosPorLineas();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? const Color(0xFF1B5E20) : Colors.grey.shade400,
            width: seleccionado ? 2 : 1,
          ),
          boxShadow: seleccionado
              ? [BoxShadow(color: Colors.green.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: seleccionado ? Colors.white : const Color(0xFF33691E),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: seleccionado ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: seleccionado ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoLineas() {
    if (_tieneDivisionDosLados && _ladoSeleccionado == 'MIXTO') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Líneas Sembradas por Lado (Mixto)'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lineasLadoAController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Lado A ($_densidadLadoA esq/l)',
                    hintText: 'Ej: 14',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => _recalcularTallosPorLineas(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lineasLadoBController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Lado B ($_densidadLadoB esq/l)',
                    hintText: 'Ej: 14',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => _recalcularTallosPorLineas(),
                ),
              ),
            ],
          ),
        ],
      );
    }

    String ayudaDensidad;
    if (_tieneDivisionDosLados) {
      if (_ladoSeleccionado == 'LADO_A') {
        ayudaDensidad = 'Lado A: $_densidadLadoA esq/línea';
      } else if (_ladoSeleccionado == 'LADO_B') {
        ayudaDensidad = 'Lado B: $_densidadLadoB esq/línea';
      } else {
        ayudaDensidad = 'Cama Completa: $_densidadCamaCompleta esq/línea';
      }
    } else {
      ayudaDensidad = 'Densidad: ${_variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20} esq/l';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('# Líneas'),
        TextFormField(
          controller: _lineasController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ej: 14',
            helperText: ayudaDensidad,
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
        _buildLabel('Tallos x sembrar'),
        Builder(
          builder: (context) {
            final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 4050;
            final int tallosActuales = int.tryParse(_tallosController.text.trim()) ?? 0;
            final bool excede = tallosActuales > limitePermitido;

            return TextFormField(
              controller: _tallosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Máx: $limitePermitido',
                helperText: excede
                    ? '⚠️ Excede límite de $limitePermitido esquejes'
                    : 'Máximo: $limitePermitido esq/cama',
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

  Widget _buildCampoObservaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildLabel(_requiereClon ? 'Clon *' : 'Observaciones'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _requiereClon ? Colors.orange.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _requiereClon ? Colors.orange.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _requiereClon ? 'Obligatorio' : 'Opcional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _requiereClon ? Colors.orange.shade900 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _observacionesController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: _requiereClon ? 'Ej: 4-25, 3-25...' : 'Notas adicionales (ej: 4d Atraso)...',
            helperText: _requiereClon
                ? 'Obligatorio para ${widget.cultivo} (ej: 4-25)'
                : null,
            helperStyle: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _requiereClon ? Colors.orange.shade700 : const Color(0xFF7CB342),
                width: 2,
              ),
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
        _buildLabel('Lote (Opcional)'),
        TextFormField(
          controller: _loteController,
          decoration: InputDecoration(
            hintText: 'Ej: 7310',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoProveedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Proveedor (Opcional)'),
        TextFormField(
          controller: _proveedorController,
          decoration: InputDecoration(
            hintText: 'Ej: Steenvoorden',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoContenedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Contenedor (Opcional)'),
        TextFormField(
          controller: _contController,
          decoration: InputDecoration(
            hintText: 'Ej: 9 BN',
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
    if (_tieneDivisionDosLados && _ladoSeleccionado == 'MIXTO') {
      final int lA = int.tryParse(_lineasLadoAController.text.trim()) ?? 0;
      final int lB = int.tryParse(_lineasLadoBController.text.trim()) ?? 0;
      final int total = (lA * _densidadLadoA) + (lB * _densidadLadoB);
      if (total == 0) return const SizedBox.shrink();
      final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 4050;
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
                '📐 Mixto: ($lA lín × $_densidadLadoA esq/l) + ($lB lín × $_densidadLadoB esq/l) = $total esquejes${excede ? " ⚠️ (Supera límite de $limitePermitido)" : ""}',
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
    }

    if (_lineasController.text.trim().isEmpty) return const SizedBox.shrink();
    return Builder(builder: (context) {
      final int? l = int.tryParse(_lineasController.text.trim());
      int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20;
      String ladoTexto = '';
      if (_tieneDivisionDosLados) {
        if (_ladoSeleccionado == 'LADO_A') {
          factor = _densidadLadoA;
          ladoTexto = ' (Lado A)';
        } else if (_ladoSeleccionado == 'LADO_B') {
          factor = _densidadLadoB;
          ladoTexto = ' (Lado B)';
        } else if (_ladoSeleccionado == 'AMBOS') {
          factor = _densidadCamaCompleta;
          ladoTexto = ' (Cama Completa)';
        }
      }
      final int total = (l ?? 0) * factor;
      final String varNombre = _variedadSeleccionada?.nombre ?? widget.cultivo;
      final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 4050;
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
                '📐 Fórmula$ladoTexto: ${l ?? 0} líneas × $factor esq/línea = $total esquejes ($varNombre)${excede ? " ⚠️ (Supera límite de $limitePermitido)" : ""}',
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
    final tituloForm = esMovil ? widget.cultivo : 'Siembra ${widget.cultivo}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tituloForm.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
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
                      final int limite = _variedadSeleccionada?.limiteEsquejes ?? cfg?.limiteEsquejes ?? 4050;
                      final int dias = _variedadSeleccionada?.diasCiclo ?? cfg?.diasCiclo ?? 98;
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
                                'Parámetros Agronómicos (${_variedadSeleccionada?.nombre ?? widget.cultivo}): Máx: $limite plant/cama | Ciclo: $dias d | Sem. Siembra: Sem $semSiembra | Cosecha Est.: $fEstStr (Sem. $semCosecha)',
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

                  // Fila 2: OPERARIO | VARIEDAD (O solo Variedad si es Madres/Bancos/Núcleos)
                  if (_esPlantaMadreOBancoONucleo) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.forest, color: Color(0xFF2E7D32), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Área Especial: ${widget.cultivo}\nSin asignación de sembrador individual. Las siembras de esta área no se miden en el rendimiento.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCampoVariedad(),
                  ] else ...[
                    if (esMovil) ...[
                      _buildCampoOperario(),
                      const SizedBox(height: 10),
                      _buildCampoVariedad(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildCampoOperario()),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: _buildCampoVariedad()),
                        ],
                      ),
                    ],
                  ],

                  const SizedBox(height: 10),

                  // Distribución de lados de cama para Pompón y Cremón
                  _buildSelectorLadoCama(),

                  const SizedBox(height: 10),

                  // Fila 3: # LÍNEAS | TALLOS X SEMBRAR | OBSERVACIONES / CLON
                  if (esMovil) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCampoLineas()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCampoTallos()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCampoObservaciones(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildCampoLineas()),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: _buildCampoTallos()),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: _buildCampoObservaciones()),
                      ],
                    ),
                  ],

                  // Fórmula informativa
                  _buildBannerFormula(),

                  const SizedBox(height: 10),

                  // Fila 4: LOTE | PROVEEDOR | CONTENEDOR (Opcionales)
                  if (esMovil) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCampoLote()),
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
                        Expanded(flex: 3, child: _buildCampoLote()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildCampoProveedor()),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: _buildCampoContenedor()),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Botones de Acción
                  _buildBotonesAccion(esMovil),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

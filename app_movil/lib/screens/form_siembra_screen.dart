import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

class FormularioSiembraScreen extends StatefulWidget {
  const FormularioSiembraScreen({super.key});

  @override
  State<FormularioSiembraScreen> createState() => _FormularioSiembraScreenState();
}

class _FormularioSiembraScreenState extends State<FormularioSiembraScreen> {
  final _formKey = GlobalKey<FormState>();
  final DbRepository _db = DbRepository();

  // Catálogos cargados
  List<Bloque> _bloques = [];
  List<Cama> _camasDelBloque = [];
  List<Operario> _operarios = [];
  List<Variedad> _variedades = [];
  Map<int, ValidacionCicloResultado> _estadoCicloCamas = {};
  ConfigAgronomica? _configAgronomica;

  // Variables del formulario
  String? _fechaSeleccionada;
  Bloque? _bloqueSeleccionado;
  Cama? _camaSeleccionada;
  Operario? _operarioSeleccionado;
  Variedad? _variedadSeleccionada;
  bool _recordarOperario = false;
  bool _cargandoCamas = false;

  final TextEditingController _tallosController = TextEditingController();
  final TextEditingController _lineasController = TextEditingController(text: '14');
  final TextEditingController _observacionesController = TextEditingController();

  bool get _requiereClon {
    final f = (_variedadSeleccionada?.familiaNombre ?? '').toUpperCase();
    if (f.contains('POMPON') || f.contains('CREMON')) return true;
    final n = (_variedadSeleccionada?.nombre ?? '').toUpperCase();
    if (n.contains('POMPON') || n.contains('CREMON')) return true;
    return false;
  }
  final TextEditingController _loteController = TextEditingController();
  final TextEditingController _proveedorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaSeleccionada = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    final b = await _db.obtenerBloques();
    final v = await _db.obtenerVariedades(soloActivas: true);
    final o = await _db.obtenerOperarios();
    final cfg = await _db.obtenerConfigAgronomica(cultivo: 'GENERAL');

    if (!mounted) return;
    setState(() {
      _bloques = b;
      _variedades = v;
      _operarios = o;
      _configAgronomica = cfg;
    });

    if (_bloqueSeleccionado != null) {
      _onBloqueCambiado(_bloqueSeleccionado);
    }
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
        _fechaSeleccionada = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
      await _recargarCiclosCamas();
    }
  }

  /// Modal con buscador rápido para elegir entre las 560 variedades
  Future<void> _abrirBuscadorVariedades() async {
    final Variedad? seleccionada = await showModalBottomSheet<Variedad>(
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
                ? _variedades
                : _variedades.where((v) =>
                    v.nombre.toLowerCase().contains(query.toLowerCase()) ||
                    v.codigo.toLowerCase().contains(query.toLowerCase())).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Escribe para buscar variedad...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: lista.length,
                      itemBuilder: (context, idx) {
                        final v = lista[idx];
                        return ListTile(
                          title: Text(v.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Código: ${v.codigo} (ID: ${v.id})'),
                          onTap: () => Navigator.pop(ctx, v),
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
      final cfg = await _db.obtenerConfigAgronomicaParaVariedad(seleccionada);
      setState(() {
        _variedadSeleccionada = seleccionada;
        _configAgronomica = cfg;
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
      final int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20;
      setState(() {
        _tallosController.text = (l * factor).toString();
      });
    }
  }

  Future<void> _guardarTodo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bloqueSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un Bloque.')));
      return;
    }
    if (_camaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una Cama.')));
      return;
    }
    if (_operarioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un Operario.')));
      return;
    }
    if (_variedadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una Variedad.')));
      return;
    }

    // 1. VALIDACIÓN DE DENSIDAD DE PLANTAS / ESQUEJES
    final config = await _db.obtenerConfigAgronomicaParaVariedad(_variedadSeleccionada!);
    final limitePermitido = _variedadSeleccionada!.limiteEsquejes ?? config.limiteEsquejes;
    final cantidadIngresada = int.tryParse(_tallosController.text.trim()) ?? 0;
    if (cantidadIngresada > limitePermitido) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 30),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exceso de Plantas',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La cantidad ingresada ($cantidadIngresada esquejes) supera el límite máximo permitido por cama para ${_variedadSeleccionada!.nombre} ($limitePermitido esquejes).',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Cantidad ingresada: $cantidadIngresada esquejes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Text('• Límite permitido: $limitePermitido esquejes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('• Exceso bloqueado: ${cantidadIngresada - limitePermitido} esquejes'),
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
      }
      return; // BLOQUEAR REGISTRO
    }

    // 2. VALIDACIÓN DE CICLO AGRONÓMICO Y DISPONIBILIDAD DE CAMA
    final validacionCiclo = await _db.validarCicloYCamaParaSiembra(
      _camaSeleccionada!.id,
      _fechaSeleccionada!,
    );

    if (!validacionCiclo.esValido) {
      if (mounted) {
        await showDialog(
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
                Text(validacionCiclo.mensaje, style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
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
                      Text('• Duración requerida: ${validacionCiclo.diasRequeridos} días'),
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
      }
      return; // BLOQUEAR REGISTRO
    }

    if (_requiereClon && _observacionesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El campo CLON es obligatorio para variedades de Pompon y Cremon (ej: 4-25).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nuevaSiembra = Siembra(
      fecha: _fechaSeleccionada!,
      bloqueCodigo: _bloqueSeleccionado!.codigo,
      variedadId: _variedadSeleccionada!.id,
      camaId: _camaSeleccionada!.id,
      operarioId: _operarioSeleccionado!.id,
      cantidad: cantidadIngresada,
      lineas: int.tryParse(_lineasController.text) ?? 14,
      observaciones: _observacionesController.text.trim().isNotEmpty
          ? _observacionesController.text.trim().toUpperCase()
          : null,
      lote: _loteController.text.isNotEmpty ? _loteController.text : null,
      proveedor: _proveedorController.text.isNotEmpty ? _proveedorController.text : null,
      sincronizado: 0,
    );

    try {
      await _db.registrarSiembraOffline(nuevaSiembra);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Siembra Guardada Exitosamente en SQLite Local! 💾')),
        );

        if (_recordarOperario) {
          setState(() {
            _bloqueSeleccionado = null;
            _camaSeleccionada = null;
            _variedadSeleccionada = null;
            _camasDelBloque = [];
            _tallosController.clear();
            _observacionesController.clear();
            _loteController.clear();
            _proveedorController.clear();
          });
        } else {
          Navigator.pop(context);
        }
      }
    } on AgronomicValidationException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restricción Agronómica', style: TextStyle(color: Colors.red)),
            content: Text(e.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tallosController.dispose();
    _lineasController.dispose();
    _observacionesController.dispose();
    _loteController.dispose();
    _proveedorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'INGRESAR SIEMBRA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            onPressed: _cargarCatalogos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final cfg = _configAgronomica;
                        final int limite = _variedadSeleccionada?.limiteEsquejes ?? cfg?.limiteEsquejes ?? 2600;
                        final int dias = _variedadSeleccionada?.diasCiclo ?? cfg?.diasCiclo ?? 75;
                        final fInicio = parsearFechaSiembra(_fechaSeleccionada) ?? DateTime.now();
                        final fEst = fInicio.add(Duration(days: dias));
                        final fEstStr = "${fEst.day.toString().padLeft(2, '0')}/${fEst.month.toString().padLeft(2, '0')}/${fEst.year}";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  'Parámetros (${_variedadSeleccionada?.nombre ?? "General"}): Máx: $limite plant/cama | Ciclo: $dias d | Cosecha Est.: $fEstStr',
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

                    // Fila 1: Fecha
                    _buildFieldLabel(
                      'FECHA DE SIEMBRA',
                      InkWell(
                        onTap: _seleccionarFecha,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade700),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fechaSeleccionada!, style: const TextStyle(fontSize: 16)),
                              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fila 2: BLOQUE (29 Bloques oficiales)
                    _buildFieldLabel(
                      'BLOQUE',
                      _buildDropdown<Bloque>(
                        hint: 'Seleccionar bloque...',
                        value: _bloqueSeleccionado,
                        items: _bloques.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text('${b.codigo} - ${b.nombre}'),
                        )).toList(),
                        onChanged: _onBloqueCambiado,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fila 3: CAMA (Filtrada dinámicamente por bloque)
                    _buildFieldLabel(
                      'CAMA (De acuerdo al bloque)',
                      _cargandoCamas
                          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                          : _bloqueSeleccionado == null
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                                  child: const Text('Primero selecciona un bloque arriba', style: TextStyle(color: Colors.grey)),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDropdown<Cama>(
                                      hint: 'Seleccionar cama del bloque (${_camasDelBloque.length} disponibles)...',
                                      value: _camaSeleccionada,
                                      items: _camasDelBloque.map((c) {
                                        final info = _estadoCicloCamas[c.id];
                                        final bool noDisp = info != null && !info.esValido;
                                        final bool esActiva = info?.esCicloActivo == true;
                                        final String estadoTexto = esActiva
                                            ? '🔴 EN CICLO'
                                            : (noDisp ? '🟠 CICLO (-${info.diasFaltantes}d)' : '🟢 DISPONIBLE');
                                        return DropdownMenuItem(
                                          value: c,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Cama ${c.cama}'),
                                              Text(
                                                estadoTexto,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: esActiva
                                                      ? Colors.red.shade800
                                                      : (noDisp ? Colors.orange.shade800 : Colors.green.shade800),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _camaSeleccionada = val),
                                    ),
                                    if (_camaSeleccionada != null && _estadoCicloCamas[_camaSeleccionada!.id]?.esValido == false) ...[
                                      Builder(
                                        builder: (context) {
                                          final info = _estadoCicloCamas[_camaSeleccionada!.id]!;
                                          return Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: info.esCicloActivo ? Colors.red.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: info.esCicloActivo ? Colors.red.shade300 : Colors.orange.shade300),
                                            ),
                                            child: Text(
                                              info.mensaje,
                                              style: TextStyle(fontSize: 11, color: info.esCicloActivo ? Colors.red.shade900 : Colors.orange.shade900),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                    ),
                    const SizedBox(height: 16),

                    // Fila 4: VARIEDAD (Con selector rápido y modal de búsqueda de 560 variedades)
                    _buildFieldLabel(
                      'VARIEDAD',
                      InkWell(
                        onTap: _abrirBuscadorVariedades,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade700),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _variedadSeleccionada != null
                                      ? '${_variedadSeleccionada!.codigo} - ${_variedadSeleccionada!.nombre}'
                                      : 'Toca para buscar variedad (${_variedades.length} disponibles)...',
                                  style: TextStyle(
                                    color: _variedadSeleccionada != null ? Colors.black87 : Colors.grey.shade600,
                                    fontSize: 15,
                                    fontWeight: _variedadSeleccionada != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(Icons.search, color: Colors.green.shade700),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fila 5: OPERARIO + Recordar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildFieldLabel(
                            'OPERARIO (Activo)',
                            _buildDropdown<Operario>(
                              hint: 'Seleccionar empleado...',
                              value: _operarioSeleccionado,
                              items: _operarios.map((o) => DropdownMenuItem(
                                value: o,
                                child: Text('${o.nombreCompleto} (${o.cedula})'),
                              )).toList(),
                              onChanged: (val) => setState(() => _operarioSeleccionado = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            const Text('Fijar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Switch(
                              value: _recordarOperario,
                              onChanged: (val) => setState(() => _recordarOperario = val),
                              activeThumbColor: const Color(0xFF7CB342),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Fila 6: TALLOS X SEMBRAR y LÍNEAS
                    Row(
                      children: [
                        Expanded(
                          child: _buildFieldLabel(
                            'TALLOS X SEMBRAR',
                            Builder(
                              builder: (context) {
                                final int limitePermitido = _variedadSeleccionada?.limiteEsquejes ?? _configAgronomica?.limiteEsquejes ?? 2600;
                                final int cant = int.tryParse(_tallosController.text.trim()) ?? 0;
                                final bool excede = cant > limitePermitido;

                                return TextFormField(
                                  controller: _tallosController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Requerido';
                                    final num = int.tryParse(val.trim());
                                    if (num == null || num <= 0) return 'Mínimo 1';
                                    if (num > limitePermitido) {
                                      return '❌ Máx: $limitePermitido (Ingresó: $num)';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Máx: $limitePermitido',
                                    helperText: excede ? '⚠️ Excede el límite de $limitePermitido esquejes' : 'Máx. permitido: $limitePermitido esquejes',
                                    helperStyle: TextStyle(
                                      color: excede ? Colors.red.shade800 : const Color(0xFF558B2F),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    filled: true,
                                    fillColor: excede ? Colors.red.shade50 : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide(color: excede ? Colors.red : Colors.grey.shade400),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFieldLabel(
                            '# DE LÍNEAS',
                            TextFormField(
                              controller: _lineasController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ej: 130',
                                helperText: 'Dens: ${_variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20} esq/l',
                                helperStyle: const TextStyle(color: Color(0xFF558B2F), fontWeight: FontWeight.bold),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (val) {
                                _recalcularTallosPorLineas();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_lineasController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final int? l = int.tryParse(_lineasController.text.trim());
                        final int factor = _variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20;
                        final int total = (l ?? 0) * factor;
                        final String varNombre = _variedadSeleccionada?.nombre ?? 'GENERAL';
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
                                  '📐 Fórmula: ${l ?? 0} líneas × $factor esq/línea = $total esquejes ($varNombre)${excede ? " ⚠️ (Supera límite de $limitePermitido)" : ""}',
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
                    const SizedBox(height: 16),

                    // Fila 7: Lote y Proveedor
                    Row(
                      children: [
                        Expanded(
                          child: _buildFieldLabel(
                            'LOTE',
                            TextFormField(
                              controller: _loteController,
                              decoration: const InputDecoration(
                                hintText: 'Opcional',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFieldLabel(
                            'PROVEEDOR',
                            TextFormField(
                              controller: _proveedorController,
                              decoration: const InputDecoration(
                                hintText: 'Opcional',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Fila 8: Observaciones / Clon
                    _buildFieldLabel(
                      _requiereClon ? 'CLON (OBLIGATORIO) *' : 'OBSERVACIONES (OPCIONAL)',
                      TextFormField(
                        controller: _observacionesController,
                        maxLines: _requiereClon ? 1 : 2,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: _requiereClon ? 'Ej: 4-25, 3-25...' : 'Detalles adicionales (opcional)...',
                          helperText: _requiereClon ? 'Obligatorio para variedades Pompon y Cremon' : null,
                          helperStyle: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BARRA INFERIOR DE BOTONES
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _guardarTodo,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Guardar Siembra', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7CB342),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade700),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  isExpanded: true,
                  hint: Text(hint, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  value: value,
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF7CB342),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
            ),
            child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

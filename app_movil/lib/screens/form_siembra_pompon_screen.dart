import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

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
  Set<int> _camasOcupadas = {};
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
    final ocupadas = estados.entries.where((e) => !e.value.esValido).map((e) => e.key).toSet();
    if (!mounted) return;
    setState(() {
      _estadoCicloCamas = estados;
      _camasOcupadas = ocupadas;
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
      final ocupadas = estados.entries.where((e) => !e.value.esValido).map((e) => e.key).toSet();
      if (!mounted) return;
      setState(() {
        _camasDelBloque = camas;
        _estadoCicloCamas = estados;
        _camasOcupadas = ocupadas;
        _cargandoCamas = false;
      });
    } else {
      setState(() {
        _camasDelBloque = [];
        _estadoCicloCamas = {};
        _camasOcupadas = {};
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
                  // Barra de filtro con toggle
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Catálogo: ${verTodas ? "Todas las Variedades (${_todasLasVariedades.length})" : "Variedades de ${widget.cultivo} (${_variedades.length})"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF33691E)),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(verTodas ? Icons.filter_alt : Icons.all_inclusive, size: 16, color: const Color(0xFF7CB342)),
                        label: Text(
                          verTodas ? 'Filtrar por ${widget.cultivo}' : 'Ver todo el catálogo',
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
      final cfgVar = await _db.obtenerConfigAgronomicaParaVariedad(seleccionada, cultivoFallback: widget.cultivo);
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
        lote: _loteController.text.trim().isNotEmpty ? _loteController.text.trim() : null,
        proveedor: _proveedorController.text.trim().isNotEmpty ? _proveedorController.text.trim() : null,
        cont: _contController.text.trim().isNotEmpty ? _contController.text.trim() : null,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim().toUpperCase()
            : null,
        sincronizado: 0,
      );

      await _db.registrarSiembraOffline(nuevaSiembra);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Siembra de ${widget.cultivo} guardada localmente (Offline) ✅',
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
    final tituloForm = 'Siembra ${widget.cultivo}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tituloForm.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                                // Banner Informativo de Parámetros Agronómicos Fijados por el Administrador
                Builder(
                  builder: (context) {
                    final cfg = _configAgronomica;
                    final int limite = _variedadSeleccionada?.limiteEsquejes ?? cfg?.limiteEsquejes ?? 2600;
                    final int dias = _variedadSeleccionada?.diasCiclo ?? cfg?.diasCiclo ?? 75;
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
                              'Parámetros Agronómicos (${_variedadSeleccionada?.nombre ?? widget.cultivo}): Máx: $limite plant/cama | Ciclo: $dias d | Cosecha Est.: $fEstStr',
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

                const SizedBox(height: 10),

                // Fila 2: OPERARIO | VARIEDAD
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operario
                    Expanded(
                      flex: 5,
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
                    // Variedad (con modal buscador)
                    Expanded(
                      flex: 5,
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
                          if (_camaSeleccionada != null && _camasOcupadas.contains(_camaSeleccionada!.id))
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.block, color: Colors.red, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Cama con siembra ACTIVA. Finalice el ciclo actual antes de sembrar.',
                                      style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Fila 3: # LÍNEAS | TALLOS X SEMBRAR | OBSERVACIONES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // # Líneas
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('# Líneas'),
                          TextFormField(
                            controller: _lineasController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ej: 130',
                              helperText: 'Densidad: ${_variedadSeleccionada?.densidadLinea ?? _configAgronomica?.densidadLinea ?? 20} esq/l',
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
                    const SizedBox(width: 14),
                    // Tallos x sembrar
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
                                      ? '⚠️ Excede el límite de $limitePermitido esquejes'
                                      : 'Máximo: $limitePermitido esquejes/cama',
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
                    // Observaciones / Clon
                    Expanded(
                      flex: 5,
                      child: Column(
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
                    final String varNombre = _variedadSeleccionada?.nombre ?? widget.cultivo;
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

                const SizedBox(height: 10),

                // Fila 4: LOTE | PROVEEDOR | CONTENEDOR (Opcionales de campo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
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
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

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

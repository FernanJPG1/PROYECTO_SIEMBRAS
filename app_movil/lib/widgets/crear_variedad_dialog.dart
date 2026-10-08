// ============================================================================
// ARCHIVO: crear_variedad_dialog.dart
// ¿QUÉ ES ESTA VENTANA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta ventana es EL SALVADOR O COMODÍN DE CAMPO.
//
// Imagínate este caso de la vida real en la finca:
// Son las 6:30 de la mañana. Llega un camión al bloque con esquejes de una flor nueva
// que no está en la lista de la oficina porque la secretaria no ha llegado todavía.
//
// Si el sistema fuera terco, los 20 sembradores se quedarían sentados en el pasto
// sin trabajar toda la mañana perdiendo tiempo y dinero.
//
// ¿QUÉ HACE ESTA VENTANA?
// 1. Permite que el supervisor escriba el nombre de la flor en la pantalla.
// 2. Elige si es Pompón, Cremón, Girasol o Lirio.
// 3. El sistema le asigna un carné provisional de emergencia (ID temporal negativo).
// 4. Los trabajadores empiezan a sembrar DE INMEDIATO sin frenar la labor.
// 5. Por la tarde, cuando la oficina crea la flor oficial en Access, el sistema
//    fusiona las dos flores automáticamente sin que nadie tenga que reescribir nada.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/utils/responsive.dart';

class CrearVariedadDialog extends StatefulWidget {
  final String? cultivoSugerido;
  final String? nombreInicial;

  const CrearVariedadDialog({
    super.key,
    this.cultivoSugerido,
    this.nombreInicial,
  });

  @override
  State<CrearVariedadDialog> createState() => _CrearVariedadDialogState();
}

class _CrearVariedadDialogState extends State<CrearVariedadDialog> {
  final _formKey = GlobalKey<FormState>();
  final DbRepository _db = DbRepository();

  late TextEditingController _nombreController;
  late TextEditingController _codigoController;
  late TextEditingController _colorController;
  late TextEditingController _limiteEsquejesController;
  late TextEditingController _diasCicloController;
  late TextEditingController _densidadLineaController;

  late String _cultivoSeleccionado;
  bool _guardando = false;

  final Map<String, Map<String, dynamic>> _datosCultivos = {
    'LIRIOS': {
      'familiaId': 199,
      'familiaNombre': 'LILIUM (LIRIOS)',
      'limite': 2430,
      'ciclo': 70,
      'densidad': 16,
    },
    'POMPON': {
      'familiaId': 147,
      'familiaNombre': 'POMPON',
      'limite': 4050,
      'ciclo': 98,
      'densidad': 28,
    },
    'CREMON': {
      'familiaId': 193,
      'familiaNombre': 'CREMON',
      'limite': 3645,
      'ciclo': 70,
      'densidad': 24,
    },
    'GIRASOL': {
      'familiaId': 213,
      'familiaNombre': 'SUNFLOWER (GIRASOL)',
      'limite': 2430,
      'ciclo': 70,
      'densidad': 14,
    },
    'MATSUMOTO': {
      'familiaId': 114,
      'familiaNombre': 'MATSUMOTO',
      'limite': 3402,
      'ciclo': 84,
      'densidad': 22,
    },
    'FUJI': {
      'familiaId': 148,
      'familiaNombre': 'FUJI',
      'limite': 3240,
      'ciclo': 70,
      'densidad': 24,
    },
    'ALSTROEMERIA': {
      'familiaId': 155,
      'familiaNombre': 'ALSTROEMERIA',
      'limite': 120,
      'ciclo': 84,
      'densidad': 8,
    },
    'OTRO': {
      'familiaId': 999,
      'familiaNombre': 'VARIEDAD DE PRUEBA / OTRO',
      'limite': 3000,
      'ciclo': 75,
      'densidad': 20,
    },
  };

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.nombreInicial ?? '');
    _codigoController = TextEditingController();
    _colorController = TextEditingController();

    // Determinar cultivo inicial
    String sugerido = (widget.cultivoSugerido ?? 'LIRIOS').toUpperCase();
    if (sugerido.contains('LIRIO') || sugerido.contains('LA') || sugerido.contains('LO') || sugerido.contains('OT')) {
      _cultivoSeleccionado = 'LIRIOS';
    } else if (sugerido.contains('POMPON')) {
      _cultivoSeleccionado = 'POMPON';
    } else if (sugerido.contains('CREMON')) {
      _cultivoSeleccionado = 'CREMON';
    } else if (sugerido.contains('GIRASOL') || sugerido.contains('SUNFLOWER')) {
      _cultivoSeleccionado = 'GIRASOL';
    } else if (sugerido.contains('MATSUMOTO')) {
      _cultivoSeleccionado = 'MATSUMOTO';
    } else if (_datosCultivos.containsKey(sugerido)) {
      _cultivoSeleccionado = sugerido;
    } else {
      _cultivoSeleccionado = 'OTRO';
    }

    _limiteEsquejesController = TextEditingController();
    _diasCicloController = TextEditingController();
    _densidadLineaController = TextEditingController();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _colorController.dispose();
    _limiteEsquejesController.dispose();
    _diasCicloController.dispose();
    _densidadLineaController.dispose();
    super.dispose();
  }

  void _onCultivoChanged(String? nuevo) {
    if (nuevo == null || !_datosCultivos.containsKey(nuevo)) return;
    setState(() {
      _cultivoSeleccionado = nuevo;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final infoCultivo = _datosCultivos[_cultivoSeleccionado]!;
      final int famId = infoCultivo['familiaId'] as int;
      final String famNombre = infoCultivo['familiaNombre'] as String;

      final int? limite = int.tryParse(_limiteEsquejesController.text.trim()) ?? (infoCultivo['limite'] as int?);
      final int? ciclo = int.tryParse(_diasCicloController.text.trim()) ?? (infoCultivo['ciclo'] as int?);
      final int? densidad = int.tryParse(_densidadLineaController.text.trim()) ?? (infoCultivo['densidad'] as int?);

      final nueva = await _db.crearVariedadTemporal(
        nombre: _nombreController.text.trim().toUpperCase(),
        codigo: _codigoController.text.trim().isNotEmpty ? _codigoController.text.trim().toUpperCase() : null,
        familiaId: famId,
        familiaNombre: famNombre,
        color: _colorController.text.trim().isNotEmpty ? _colorController.text.trim().toUpperCase() : null,
        colorNombre: _colorController.text.trim().isNotEmpty ? _colorController.text.trim().toUpperCase() : null,
        limiteEsquejes: limite,
        diasCiclo: ciclo,
        densidadLinea: densidad,
      );

      if (mounted) {
        Navigator.pop(context, nueva);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la variedad: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.dialogMaxWidth(context).clamp(300.0, 540.0),
          maxHeight: Responsive.dialogMaxHeight(context),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC5E1A5)),
                      ),
                      child: const Icon(Icons.add_business_rounded, color: Color(0xFF2E7D32), size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nueva Variedad / Prueba',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            'Registro local inmediato en SQLite',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                const SizedBox(height: 14),

                // Info banner explicativo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.offline_bolt_rounded, color: Color(0xFFF57F17), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta variedad se guardará en SQLite para registrar sin demora los rendimientos de cortadores y sembradores. '
                          'Cuando sea agregada en Access, el sistema la sincronizará automáticamente.',
                          style: TextStyle(fontSize: 12, color: Colors.brown.shade800, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Nombre de la variedad
                const Text('Nombre de la Variedad *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Ej: PRUEBA ORIENTAL 1, CALLA GOLD, ETC.',
                    prefixIcon: const Icon(Icons.label_important_outline, color: Color(0xFF2E7D32)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Por favor ingresa el nombre de la variedad';
                    }
                    if (v.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Cultivo / Familia y Código
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cultivo / Especie *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _cultivoSeleccionado,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: _datosCultivos.keys.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13.5)));
                            }).toList(),
                            onChanged: _onCultivoChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Código (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codigoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Ej: 00',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Color
                const Text('Color (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _colorController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Ej: BLANCO, AMARILLO, ROSADO, BICOLOR',
                    prefixIcon: const Icon(Icons.palette_outlined, color: Colors.blueGrey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Parámetros agronómicos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parámetros Agronómicos (Predefinidos por cultivo)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Máx. Esquejes', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _limiteEsquejesController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: _datosCultivos[_cultivoSeleccionado]!['limite'].toString(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Días Ciclo', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _diasCicloController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: _datosCultivos[_cultivoSeleccionado]!['ciclo'].toString(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Plantas / Línea', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _densidadLineaController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: _datosCultivos[_cultivoSeleccionado]!['densidad'].toString(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Acciones
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _guardando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _guardando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _guardando ? 'Guardando en SQLite...' : 'Guardar y Usar Variedad',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _guardando ? null : _guardar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

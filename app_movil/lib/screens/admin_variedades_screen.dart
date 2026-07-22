import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/services/sync_service.dart';

class AdminVariedadesScreen extends StatefulWidget {
  const AdminVariedadesScreen({super.key});

  @override
  State<AdminVariedadesScreen> createState() => _AdminVariedadesScreenState();
}

class _AdminVariedadesScreenState extends State<AdminVariedadesScreen> {
  final DbRepository _db = DbRepository();
  final SyncService _syncService = SyncService();

  List<Variedad> _todasVariedades = [];
  List<Variedad> _variedadesFiltradas = [];
  bool _cargando = true;
  String _busqueda = '';
  final String _adminPin = '1234';

  @override
  void initState() {
    super.initState();
    _cargarVariedades();
  }

  Future<void> _cargarVariedades() async {
    setState(() => _cargando = true);
    final list = await _db.obtenerVariedades(soloActivas: false);
    if (!mounted) return;
    setState(() {
      _todasVariedades = list;
      _filtrarVariedades(_busqueda);
      _cargando = false;
    });
  }

  void _filtrarVariedades(String query) {
    _busqueda = query;
    if (query.trim().isEmpty) {
      _variedadesFiltradas = List.from(_todasVariedades);
    } else {
      final q = query.toLowerCase();
      _variedadesFiltradas = _todasVariedades.where((v) {
        return v.nombre.toLowerCase().contains(q) || v.codigo.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _dialogEditarVariedad([Variedad? variedad]) async {
    final esNueva = variedad == null;
    final nombreCtrl = TextEditingController(text: variedad?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: variedad?.codigo ?? '');
    final densidadCtrl = TextEditingController(text: variedad?.densidadLinea?.toString() ?? '20');
    final limiteCtrl = TextEditingController(text: variedad?.limiteEsquejes?.toString() ?? '2600');
    final cicloCtrl = TextEditingController(text: variedad?.diasCiclo?.toString() ?? '75');
    int estadoSeleccionado = variedad?.estado ?? 1;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(esNueva ? Icons.add_circle : Icons.edit, color: const Color(0xFF7CB342), size: 28),
              const SizedBox(width: 8),
              Text(
                esNueva ? 'Nueva Variedad' : 'Editar Variedad',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Variedad *',
                    hintText: 'Ej: WHITE STAR',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código Variedad *',
                    hintText: 'Ej: 01901',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: densidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Densidad (Esquejes / Línea) *',
                    helperText: 'Multiplicador por defecto para esta variedad',
                    hintText: 'Ej: 20',
                    prefixIcon: Icon(Icons.format_list_numbered, color: Color(0xFF7CB342)),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: limiteCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Límite Esquejes / Cama *',
                          hintText: 'Ej: 2600',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cicloCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Días de Ciclo *',
                          hintText: 'Ej: 75',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Activa'),
                      selected: estadoSeleccionado == 1,
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: estadoSeleccionado == 1 ? Colors.green.shade800 : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => estadoSeleccionado = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Inactiva'),
                      selected: estadoSeleccionado == 0,
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: estadoSeleccionado == 0 ? Colors.red.shade800 : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => estadoSeleccionado = 0);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342)),
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final nombre = nombreCtrl.text.trim().toUpperCase();
      final codigo = codigoCtrl.text.trim();
      final nDensidad = int.tryParse(densidadCtrl.text.trim()) ?? 20;
      final nLimite = int.tryParse(limiteCtrl.text.trim()) ?? 2600;
      final nCiclo = int.tryParse(cicloCtrl.text.trim()) ?? 75;

      if (esNueva) {
        final remota = await _syncService.crearVariedadRemota(
          nombre, 
          codigo, 
          _adminPin,
          densidadLinea: nDensidad,
          limiteEsquejes: nLimite,
          diasCiclo: nCiclo,
        );
        if (remota != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Variedad creada exitosamente')),
            );
          }
        } else {
          final nuevoId = DateTime.now().millisecondsSinceEpoch % 100000;
          final local = Variedad(
            id: nuevoId, 
            codigo: codigo, 
            nombre: nombre, 
            estado: estadoSeleccionado,
            densidadLinea: nDensidad,
            limiteEsquejes: nLimite,
            diasCiclo: nCiclo,
          );
          await _db.guardarVariedadLocal(local);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Variedad guardada localmente (pendiente de red)')),
            );
          }
        }
      } else {
        final okRemoto = await _syncService.actualizarVariedadRemota(
          variedad.id,
          nombre,
          codigo,
          estadoSeleccionado,
          _adminPin,
          densidadLinea: nDensidad,
          limiteEsquejes: nLimite,
          diasCiclo: nCiclo,
        );
        final actualizada = Variedad(
          id: variedad.id,
          codigo: codigo,
          nombre: nombre,
          estado: estadoSeleccionado,
          familiaId: variedad.familiaId,
          familiaNombre: variedad.familiaNombre,
          color: variedad.color,
          colorNombre: variedad.colorNombre,
          subvarNombre: variedad.subvarNombre,
          densidadLinea: nDensidad,
          limiteEsquejes: nLimite,
          diasCiclo: nCiclo,
        );
        await _db.guardarVariedadLocal(actualizada);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(okRemoto
                  ? 'Variedad actualizada en la base de datos empresarial'
                  : 'Variedad actualizada localmente'),
            ),
          );
        }
      }

      await _cargarVariedades();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        title: const Text(
          'ADMINISTRAR VARIEDADES',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarVariedades,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7CB342),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Variedad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _dialogEditarVariedad(),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => _filtrarVariedades(val)),
              decoration: InputDecoration(
                hintText: 'Buscar variedad por nombre o código...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7CB342)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Variedades: ${_variedadesFiltradas.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const Text(
                  'Permiso: Administrador',
                  style: TextStyle(color: Color(0xFF7CB342), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
                : _variedadesFiltradas.isEmpty
                    ? const Center(child: Text('No se encontraron variedades'))
                    : ListView.builder(
                        itemCount: _variedadesFiltradas.length,
                        itemBuilder: (context, idx) {
                          final v = _variedadesFiltradas[idx];
                          final esActiva = v.estado == 1;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esActiva ? Colors.green.shade100 : Colors.red.shade100,
                                child: Text(
                                  v.codigo.isNotEmpty ? v.codigo : '#',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: esActiva ? Colors.green.shade800 : Colors.red.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                v.nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: esActiva ? null : TextDecoration.lineThrough,
                                  color: esActiva ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              subtitle: Text(
                                'Código: ${v.codigo} | 📐 ${v.densidadLinea ?? 20} esq/l | 🌿 ${v.limiteEsquejes ?? 2600} max | ${esActiva ? 'ACTIVA' : 'INACTIVA'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: esActiva ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF7CB342)),
                                onPressed: () => _dialogEditarVariedad(v),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

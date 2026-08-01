import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/services/sync_service.dart';

class AdminCicloVariedadScreen extends StatefulWidget {
  const AdminCicloVariedadScreen({super.key});

  @override
  State<AdminCicloVariedadScreen> createState() => _AdminCicloVariedadScreenState();
}

class _AdminCicloVariedadScreenState extends State<AdminCicloVariedadScreen> {
  final DbRepository _db = DbRepository();
  final SyncService _syncService = SyncService();
  final String _adminPin = '1234';

  List<ConfigAgronomica> _configs = [];
  List<Variedad> _todasVariedades = [];
  List<Variedad> _variedadesFiltradas = [];
  bool _cargando = true;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final configs = await _db.obtenerTodasLasConfigsAgronomicas();
    final vars = await _db.obtenerVariedades(soloActivas: false);
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _todasVariedades = vars;
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
        return v.nombre.toLowerCase().contains(q) ||
            v.codigo.toLowerCase().contains(q) ||
            (v.familiaNombre ?? '').toLowerCase().contains(q);
      }).toList();
    }
  }

  /// Edita la duración del ciclo agronómico en días para una variedad específica
  Future<void> _dialogEditarCicloVariedad(Variedad v) async {
    final cicloActual = v.diasCiclo ?? 75;
    final cicloCtrl = TextEditingController(text: cicloActual.toString());

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.timelapse, color: Color(0xFF7CB342), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ciclo: ${v.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código: ${v.codigo} ${v.familiaNombre != null ? ' | ${v.familiaNombre}' : ''}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text(
                'Define el tiempo estimado en días que toma el ciclo de siembra para esta variedad:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: cicloCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Días de Duración del Ciclo *',
                  hintText: 'Ej: 75',
                  helperText: 'Si la cama tiene una siembra activa que no ha cumplido estos días, no dejará sembrar.',
                  prefixIcon: Icon(Icons.timer, color: Color(0xFF7CB342)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342)),
            onPressed: () {
              if (cicloCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar Ciclo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (guardado == true && mounted) {
      final nuevoCiclo = int.tryParse(cicloCtrl.text.trim()) ?? cicloActual;
      // 1. Guardar en SQLite local
      await _db.actualizarCicloVariedad(v.id, nuevoCiclo);
      // 2. Intentar sincronizar con backend Access
      _syncService.actualizarVariedadRemota(
        v.id,
        v.nombre,
        v.codigo,
        v.estado,
        _adminPin,
        diasCiclo: nuevoCiclo,
      );

      await _cargarDatos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Ciclo actualizado para ${v.nombre}: $nuevoCiclo días'),
            backgroundColor: const Color(0xFF7CB342),
          ),
        );
      }
    }
  }

  /// Edita la duración del ciclo agronómico para un grupo de cultivo general
  Future<void> _dialogEditarCicloCultivo(ConfigAgronomica cfg) async {
    final cicloCtrl = TextEditingController(text: cfg.diasCiclo.toString());

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.timelapse, color: Color(0xFF7CB342), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ciclo Base: ${cfg.cultivo}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Define la duración mínima en días del ciclo para este grupo de cultivo:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: cicloCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Días de Ciclo Agronómico *',
                  hintText: 'Ej: 75',
                  helperText: 'Aplica a todas las variedades de este cultivo que no tengan duración individual.',
                  prefixIcon: Icon(Icons.timer, color: Color(0xFF7CB342)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342)),
            onPressed: () {
              if (cicloCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar Ciclo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (guardado == true && mounted) {
      final nuevoCiclo = int.tryParse(cicloCtrl.text.trim()) ?? cfg.diasCiclo;
      final nuevaConfig = ConfigAgronomica(
        cultivo: cfg.cultivo,
        limiteEsquejes: cfg.limiteEsquejes,
        diasCiclo: nuevoCiclo,
        fechaActualizacion: DateTime.now().toString(),
      );
      await _db.guardarConfigAgronomica(nuevaConfig);
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Ciclo actualizado para ${cfg.cultivo}: $nuevoCiclo días'),
            backgroundColor: const Color(0xFF7CB342),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F8E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF7CB342),
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'DÍAS DE CICLO POR VARIEDAD',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.local_florist, size: 20), text: 'Por Variedad'),
              Tab(icon: Icon(Icons.category, size: 20), text: 'Por Cultivo General'),
            ],
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
            : TabBarView(
                children: [
                  // --- PESTAÑA 1: POR VARIEDAD (762 Variedades) ---
                  Column(
                    children: [
                      // Buscador
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: Colors.white,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar variedad por nombre o código...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                            suffixIcon: _busqueda.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _busqueda = '';
                                        _filtrarVariedades('');
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF7CB342), width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => _filtrarVariedades(val));
                          },
                        ),
                      ),
                      // Barra informativa
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFFE8F5E9),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF33691E), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mostrando ${_variedadesFiltradas.length} variedades. Pulsa "Editar" para cambiar los días de ciclo.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF33691E), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista de variedades
                      Expanded(
                        child: _variedadesFiltradas.isEmpty
                            ? const Center(child: Text('No se encontraron variedades'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: _variedadesFiltradas.length,
                                itemBuilder: (ctx, idx) {
                                  final v = _variedadesFiltradas[idx];
                                  final dias = v.diasCiclo ?? 75;
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF7CB342).withValues(alpha: 0.15),
                                        child: const Icon(Icons.timelapse, color: Color(0xFF33691E)),
                                      ),
                                      title: Text(
                                        v.nombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238)),
                                      ),
                                      subtitle: Text(
                                        'Código: ${v.codigo} ${v.familiaNombre != null ? '• ${v.familiaNombre}' : ''}\n'
                                        'Ciclo actual: $dias días de desarrollo',
                                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                      ),
                                      trailing: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7CB342),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                        label: const Text('Editar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                        onPressed: () => _dialogEditarCicloVariedad(v),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // --- PESTAÑA 2: POR CULTIVO GENERAL ---
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _configs.length,
                    itemBuilder: (ctx, idx) {
                      final cfg = _configs[idx];
                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7CB342).withValues(alpha: 0.15),
                            child: const Icon(Icons.category, color: Color(0xFF33691E)),
                          ),
                          title: Text(
                            cfg.cultivo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF33691E)),
                          ),
                          subtitle: Text(
                            'Duración Requerida Base: ${cfg.diasCiclo} días',
                            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7CB342),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                            label: const Text('Editar', style: TextStyle(color: Colors.white, fontSize: 13)),
                            onPressed: () => _dialogEditarCicloCultivo(cfg),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

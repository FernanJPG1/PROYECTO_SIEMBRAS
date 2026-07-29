import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

class AdminConfigAgronomicaScreen extends StatefulWidget {
  const AdminConfigAgronomicaScreen({super.key});

  @override
  State<AdminConfigAgronomicaScreen> createState() => _AdminConfigAgronomicaScreenState();
}

class _AdminConfigAgronomicaScreenState extends State<AdminConfigAgronomicaScreen> {
  final DbRepository _db = DbRepository();
  List<ConfigAgronomica> _configs = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarConfigs();
  }

  Future<void> _cargarConfigs() async {
    setState(() => _cargando = true);
    final list = await _db.obtenerTodasLasConfigsAgronomicas();
    if (!mounted) return;
    setState(() {
      _configs = list;
      _cargando = false;
    });
  }

  Future<void> _dialogEditarConfig(ConfigAgronomica cfg) async {
    final limiteCtrl = TextEditingController(text: cfg.limiteEsquejes.toString());
    final cicloCtrl = TextEditingController(text: cfg.diasCiclo.toString());
    final densidadCtrl = TextEditingController(text: cfg.densidadLinea.toString());

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFF7CB342), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Configurar ${cfg.cultivo}',
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
                'Parámetros independientes fijados por el Administrador:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: densidadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Densidad Base (Esquejes / Línea) *',
                  helperText: 'Multiplicador por defecto: # Líneas × Densidad',
                  prefixIcon: Icon(Icons.format_list_numbered, color: Color(0xFF7CB342)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limiteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Límite Máximo Esquejes / Cama *',
                  helperText: 'Límite que el operario no podrá superar en siembra',
                  prefixIcon: Icon(Icons.forest, color: Color(0xFF7CB342)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cicloCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días de Duración del Ciclo *',
                  helperText: 'Tiempo estimado de desarrollo de la planta',
                  prefixIcon: Icon(Icons.timelapse, color: Color(0xFF7CB342)),
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
              if (limiteCtrl.text.trim().isEmpty || cicloCtrl.text.trim().isEmpty || densidadCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar Parámetros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (guardado == true) {
      final nuevoLimite = int.tryParse(limiteCtrl.text.trim()) ?? cfg.limiteEsquejes;
      final nuevoCiclo = int.tryParse(cicloCtrl.text.trim()) ?? cfg.diasCiclo;
      final nuevaDensidad = int.tryParse(densidadCtrl.text.trim()) ?? cfg.densidadLinea;

      final now = DateTime.now();
      final fechaAct = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

      final actualizada = ConfigAgronomica(
        cultivo: cfg.cultivo,
        limiteEsquejes: nuevoLimite,
        diasCiclo: nuevoCiclo,
        densidadLinea: nuevaDensidad,
        fechaActualizacion: fechaAct,
      );

      await _db.guardarConfigAgronomica(actualizada);
      await _cargarConfigs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Parámetros de ${cfg.cultivo} actualizados correctamente.'),
            backgroundColor: const Color(0xFF33691E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        title: const Text(
          'CONFIGURACIÓN DE CICLOS Y LÍMITES',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: const Row(
                    children: [
                      Icon(Icons.shield, color: Color(0xFF7CB342), size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Parámetros agronómicos configurados por el Administrador. '
                          'Aplican a todos los formularios de siembra independientemente de las variedades.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final cfg = _configs[index];
                      final esGeneral = cfg.cultivo == 'GENERAL';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: esGeneral ? const Color(0xFF7CB342) : Colors.green.shade100,
                                child: Icon(
                                  esGeneral ? Icons.star : Icons.grass,
                                  color: esGeneral ? Colors.white : const Color(0xFF33691E),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      esGeneral ? 'CONFIGURACIÓN GENERAL (DEFAULT)' : cfg.cultivo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: esGeneral ? const Color(0xFF2E7D32) : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: Colors.amber.shade300),
                                          ),
                                          child: Text(
                                            '📐 Densidad: ${cfg.densidadLinea} esq/l',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F8E9),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: const Color(0xFFC5E1A5)),
                                          ),
                                          child: Text(
                                            '🌿 Límite: ${cfg.limiteEsquejes} esq/cama',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF33691E),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            '⏱️ Ciclo: ${cfg.diasCiclo} días',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF7CB342), size: 24),
                                tooltip: 'Editar Parámetros',
                                onPressed: () => _dialogEditarConfig(cfg),
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
    );
  }
}

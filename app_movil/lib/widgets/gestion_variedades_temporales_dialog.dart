// ============================================================================
// ARCHIVO: gestion_variedades_temporales_dialog.dart
// ¿QUÉ ES ESTA VENTANA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta ventana es EL LIBRO DE LEGALIZACIÓN DE FLORES PROVISIONALES.
//
// Cuando en el campo se inventó una flor de emergencia para que la gente no parara
// de trabajar, queda anotada aquí como "Variedad Temporal".
//
// ¿QUÉ HACE ESTA VENTANA?
// 1. REVISIÓN: Muestra la lista de flores provisionales y cuántas siembras se hicieron con ellas.
// 2. RECONCILIACIÓN AUTOMÁTICA: Si en la oficina ya crearon la flor en Access,
//    al tocar un botón el sistema las une y las oficializa al instante.
// 3. VINCULACIÓN MANUAL: Si en el campo le pusieron "Anastasia Amarilla" pero en la oficina
//    la bautizaron como "Anastasia Gold", el supervisor las enlaza con un toque
//    y el sistema actualiza todas las siembras para que los reportes salgan perfectos.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/services/sync_service.dart';
import 'package:app_movil/utils/responsive.dart';
import 'package:app_movil/widgets/crear_variedad_dialog.dart';

class GestionVariedadesTemporalesDialog extends StatefulWidget {
  const GestionVariedadesTemporalesDialog({super.key});

  @override
  State<GestionVariedadesTemporalesDialog> createState() => _GestionVariedadesTemporalesDialogState();
}

class _GestionVariedadesTemporalesDialogState extends State<GestionVariedadesTemporalesDialog> {
  final DbRepository _db = DbRepository();
  final SyncService _sync = SyncService();

  List<Map<String, dynamic>> _temporales = [];
  List<Variedad> _variedadesOficiales = [];
  bool _cargando = true;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final temps = await _db.obtenerVariedadesTemporalesConConteo();
    final all = await _db.obtenerVariedades(soloActivas: false);
    final oficiales = all.where((v) => !v.esTemporal && v.id > 0).toList();

    if (mounted) {
      setState(() {
        _temporales = temps;
        _variedadesOficiales = oficiales;
        _cargando = false;
      });
    }
  }

  Future<void> _ejecutarReconciliacionAutomatica() async {
    setState(() => _procesando = true);
    try {
      final reconciliadas = await _db.reconciliarVariedadesTemporales();
      await _cargarDatos();
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: reconciliadas > 0 ? const Color(0xFF2E7D32) : Colors.blueGrey,
            content: Text(
              reconciliadas > 0
                  ? '¡Éxito! Se sincronizaron $reconciliadas variedades temporales con Access.'
                  : 'No se encontraron nuevas coincidencias por nombre exacto en el catálogo descargado.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reconciliar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _vincularManualmente(Variedad temp) async {
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
                ? _variedadesOficiales
                : _variedadesOficiales.where((v) =>
                    v.nombre.toLowerCase().contains(query.toLowerCase()) ||
                    v.codigo.toLowerCase().contains(query.toLowerCase())).toList();

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.dialogMaxWidth(context)),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                  const SizedBox(height: 12),
                  Text(
                    'Seleccionar Variedad Oficial de Access para vincular con "${temp.nombre}"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar en catálogo oficial...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final v = lista[i];
                        return ListTile(
                          title: Text(v.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID Access: ${v.id} | Código: ${v.codigo} | ${v.familiaNombre ?? ""}'),
                          trailing: const Icon(Icons.link, color: Color(0xFF2E7D32)),
                          onTap: () => Navigator.pop(ctx, v),
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
      setState(() => _procesando = true);
      try {
        final totalMigradas = await _db.vincularVariedadTemporalManual(
          tempVariedadId: temp.id,
          realVariedadId: seleccionada.id,
        );
        await _cargarDatos();
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2E7D32),
              content: Text(
                '¡Vinculación Exitosa! Se migraron $totalMigradas siembras a "${seleccionada.nombre}" (ID: ${seleccionada.id}).',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al vincular: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _crearEnAccessRemoto(Variedad temp) async {
    final pinController = TextEditingController(text: 'admin');
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cloud_upload_rounded, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Crear Variedad en Access')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se enviará "${temp.nombre}" al servidor para darla de alta inmediatamente en Access (t11_mcolorsseries).'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN de Administrador',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Crear en Access'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _procesando = true);
      try {
        final nuevaRemota = await _sync.crearVariedadRemota(
          temp.nombre,
          temp.codigo,
          pinController.text.trim(),
          limiteEsquejes: temp.limiteEsquejes,
          diasCiclo: temp.diasCiclo,
          densidadLinea: temp.densidadLinea,
          familiaId: temp.familiaId,
        );

        if (nuevaRemota != null) {
          // Reconciliar de inmediato
          await _db.vincularVariedadTemporalManual(
            tempVariedadId: temp.id,
            realVariedadId: nuevaRemota.id,
          );
          await _cargarDatos();
          if (mounted) {
            setState(() => _procesando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF2E7D32),
                content: Text('¡Variedad creada en Access (ID: ${nuevaRemota.id}) y siembras sincronizadas!'),
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() => _procesando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo crear en Access. Verifique la conexión con el servidor.'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmarEliminarVariedad(Variedad v, int totalSiembras) async {
    bool eliminarSiembras = false;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Eliminar Variedad Temporal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar la variedad "${v.nombre}" (Código: ${v.codigo}) de SQLite?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (totalSiembras > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atención: Tiene $totalSiembras siembra(s) registrada(s)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: eliminarSiembras,
                        activeColor: Colors.red.shade700,
                        title: const Text(
                          'Eliminar también las siembras asociadas a esta variedad en este dispositivo.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: (val) {
                          setDialogState(() => eliminarSiembras = val ?? false);
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Esta variedad no tiene ninguna siembra registrada. Se eliminará inmediatamente de forma segura.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Eliminar'),
              onPressed: () {
                if (totalSiembras > 0 && !eliminarSiembras) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes marcar la casilla para confirmar la eliminación de las siembras asociadas.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(dCtx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirmar == true) {
      setState(() => _procesando = true);
      try {
        await _db.eliminarVariedadTemporal(v.id, eliminarSiembrasAsociadas: eliminarSiembras);
        await _cargarDatos();
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2E7D32),
              content: Text('Variedad "${v.nombre}" eliminada exitosamente.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.dialogMaxWidth(context).clamp(320.0, 720.0),
          maxHeight: Responsive.dialogMaxHeight(context).clamp(340.0, 700.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: Color(0xFFE65100), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variedades Temporales y Pruebas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        Text(
                          'Sincronización y reconciliación de registros con Access',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
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

              // Botones de acción general
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reconciliar Automáticamente con Access'),
                    onPressed: _procesando ? null : _ejecutarReconciliacionAutomatica,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF81C784)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Crear Nueva Variedad'),
                    onPressed: _procesando
                        ? null
                        : () async {
                            final nueva = await showDialog<Variedad>(
                              context: context,
                              builder: (ctx) => const CrearVariedadDialog(),
                            );
                            if (nueva != null) {
                              _cargarDatos();
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Estado de carga o contenido
              Expanded(
                child: _cargando || _procesando
                    ? const Center(child: CircularProgressIndicator())
                    : _temporales.isEmpty
                        ? _buildEstadoVacio()
                        : _buildListaTemporales(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, size: 64, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Todo está Sincronizado!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No hay variedades temporales pendientes. Todas las siembras y rendimientos registrados están asociados a las variedades comerciales oficiales de Access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaTemporales() {
    return ListView.builder(
      itemCount: _temporales.length,
      itemBuilder: (context, i) {
        final item = _temporales[i];
        final Variedad v = item['variedad'] as Variedad;
        final int totalSiembras = item['total_siembras'] as int;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.shade300),
          ),
          color: const Color(0xFFFFFDF5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.science_rounded, color: Colors.amber.shade900, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                v.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Text(
                                  'PRUEBA / TEMPORAL',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cultivo: ${v.familiaNombre ?? "General"} | Código: ${v.codigo} | ID Local: ${v.id}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Text(
                        '$totalSiembras siembra(s)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                      onPressed: () => _confirmarEliminarVariedad(v, totalSiembras),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF90CAF9)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Vincular a Variedad de Access', style: TextStyle(fontSize: 12)),
                      onPressed: () => _vincularManualmente(v),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Crear en Access Ahora', style: TextStyle(fontSize: 12)),
                      onPressed: () => _crearEnAccessRemoto(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

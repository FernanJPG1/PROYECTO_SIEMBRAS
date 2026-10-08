// ============================================================================
// ARCHIVO: historial_screen.dart
// ¿QUÉ ES ESTA PANTALLA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta pantalla es EL BUZÓN DE CARTAS O LA BANDEJA DE SALIDA.
//
// Aquí se muestran las siembras que se anotaron en los bloques pero que todavía
// NO han viajado al computador de la oficina porque el celular no ha entrado al Wi-Fi.
//
// 1. EL RELOJITO DE ESPERA:
//    Cada siembra aquí tiene un relojito indicando que está segura y guardada en el celular,
//    pero esperando al mensajero para viajar a la oficina.
//
// 2. REVISIÓN Y CORRECCIÓN:
//    El supervisor puede mirar la lista antes de ir a la oficina. Si ve que alguien
//    anotó una cama equivocada, puede corregirla o borrarla a tiempo.
//
// 3. BUZÓN LIMPIO:
//    Cuando presionas 'Sincronizar' en la oficina, este buzón queda completamente vacío
//    con un aviso verde que dice: '¡Todo al día! No hay cartas pendientes'.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/sync_service.dart' as app_sync;
import 'package:app_movil/utils/responsive.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final dbRepo = DbRepository();
  List<Siembra> pendientes = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    final datos = await dbRepo.obtenerSiembrasPendientesSync();
    setState(() {
      pendientes = datos;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bandeja de Salida', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: cargando 
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContentContainer(
              maxWidth: 800,
              child: pendientes.isEmpty
                ? _buildEmptyState()
                : _buildListaPendientes(),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Todo está sincronizado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay siembras locales pendientes de subir.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildListaPendientes() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tienes ${pendientes.length} registro(s) sin subir a Access.',
                  style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pendientes.length,
            itemBuilder: (ctx, i) {
              final s = pendientes[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.eco, color: Color(0xFF10B981)),
                  ),
                  title: Text('Cama ID: ${s.camaId} | Variedad ID: ${s.variedadId}'),
                  subtitle: Text('Cantidad: ${s.cantidad} esquejes'),
                  trailing: const Icon(Icons.cloud_upload, color: Colors.grey),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.sync),
              label: const Text('SINCRONIZAR CON EL SERVIDOR', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                setState(() => cargando = true);
                
                final syncSvc = app_sync.SyncService();
                final exito = await syncSvc.sincronizarPendientes();
                if (!mounted) return;
                
                if (exito) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronización Exitosa ✅'), backgroundColor: Color(0xFF10B981)),
                  );
                  _cargarPendientes(); // Recargar la lista (debería quedar vacía)
                } else {
                  setState(() => cargando = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al conectar con el servidor ❌'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ),
        )
      ],
    );
  }
}

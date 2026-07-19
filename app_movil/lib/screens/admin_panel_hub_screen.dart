import 'package:flutter/material.dart';
import 'package:app_movil/screens/admin_variedades_screen.dart';
import 'package:app_movil/screens/admin_densidad_plantas_screen.dart';
import 'package:app_movil/screens/admin_ciclo_variedad_screen.dart';
import 'package:app_movil/services/sync_service.dart' as app_sync;

class AdminPanelHubScreen extends StatelessWidget {
  const AdminPanelHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PANEL DE ADMINISTRACIÓN',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Color(0xFF7CB342), size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestión Agronómica y Parámetros',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selecciona el módulo administrativo que deseas configurar. Cada opción administra sus reglas de forma independiente.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- VISTA 1: REGISTRAR NUEVA VARIEDAD ---
            _buildAdminOptionCard(
              context: context,
              icon: Icons.grass,
              color: const Color(0xFF558B2F),
              title: '1. Registrar / Gestionar Variedades',
              subtitle: 'Crear nuevas variedades, códigos, familias y colores. Activar o desactivar variedades para siembra.',
              badgeText: 'Catálogo de Variedades',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminVariedadesScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // --- VISTA 2: DENSIDAD DE PLANTAS X CAMA ---
            _buildAdminOptionCard(
              context: context,
              icon: Icons.numbers,
              color: const Color(0xFF689F38),
              title: '2. Densidad de Plantas por Cama',
              subtitle: 'Definir el número máximo de esquejes/plantas permitidos por cama según la variedad o grupo de cultivo.',
              badgeText: 'Límites y Reglas de Densidad',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDensidadPlantasScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // --- VISTA 3: DÍAS DE CICLO POR VARIEDAD ---
            _buildAdminOptionCard(
              context: context,
              icon: Icons.timelapse,
              color: const Color(0xFF33691E),
              title: '3. Días de Ciclo por Variedad',
              subtitle: 'Configurar el tiempo mínimo de desarrollo agronómico en días requeridos antes de permitir una resiembra.',
              badgeText: 'Duración del Ciclo Agronómico',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminCicloVariedadScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // --- VISTA 4: CONFIGURACIÓN DE SERVIDOR LOCAL / RED ---
            _buildAdminOptionCard(
              context: context,
              icon: Icons.dns,
              color: const Color(0xFF00796B),
              title: '4. Conexión y Servidor Local / Red',
              subtitle: 'Configurar IP o URL del servidor backend para sincronizar por Wi-Fi o red local sin cables.',
              badgeText: 'Servidor y Red',
              onTap: () {
                _mostrarConfiguracionServidor(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarConfiguracionServidor(BuildContext context) async {
    final syncSvc = app_sync.SyncService();
    final currentUrl = await syncSvc.getBaseUrl();
    final urlController = TextEditingController(text: currentUrl);
    String estadoConexion = '';
    bool probando = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.dns, color: Color(0xFF00796B), size: 28),
              SizedBox(width: 8),
              Text('Servidor y Conexión de Red', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configura la dirección del backend para que la tablet se sincronice a través de la red local o Wi-Fi:',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                const Text('URL del Servidor Backend:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.X:8000/api',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.network_check, color: Color(0xFF00796B)),
                      tooltip: 'Probar Conexión',
                      onPressed: probando ? null : () async {
                        setDialogState(() {
                          probando = true;
                          estadoConexion = 'Probando conexión...';
                        });
                        final res = await syncSvc.probarConexion(urlController.text.trim());
                        setDialogState(() {
                          probando = false;
                          if (res['exito'] == true) {
                            estadoConexion = '✓ ${res['mensaje']}';
                          } else {
                            estadoConexion = '✗ ${res['mensaje']}';
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (estadoConexion.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    estadoConexion,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: estadoConexion.startsWith('✓') ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valores comunes recomendados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => urlController.text = 'http://10.0.2.2:8000/api',
                        child: const Text('• Emulador Android: http://10.0.2.2:8000/api', style: TextStyle(fontSize: 11, color: Colors.blue)),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => urlController.text = 'http://192.168.1.39:8000/api',
                        child: const Text('• Tablet por Wi-Fi: http://192.168.1.39:8000/api', style: TextStyle(fontSize: 11, color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
              onPressed: () async {
                await syncSvc.setBaseUrl(urlController.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Dirección del servidor guardada correctamente.'),
                      backgroundColor: Color(0xFF00796B),
                    ),
                  );
                }
              },
              child: const Text('Guardar Configuración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

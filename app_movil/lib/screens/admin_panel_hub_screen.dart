// ============================================================================
// ARCHIVO: admin_panel_hub_screen.dart
// ¿QUÉ ES ESTA PANTALLA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta pantalla es EL ESCRITORIO DEL JEFE O SUPERVISOR GENERAL.
//
// Desde aquí se manejan las herramientas avanzadas de la finca:
// 1. 🖨️ Centro de Impresión de Planillas PDF (listas para WhatsApp).
// 2. 🏆 Liquidación de Rendimientos de los Sembradores para nómina.
// 3. 🏷️ Gestión de Flores Temporales: Para revisar qué flores de emergencia se crearon
//       en campo y cruzarlas con la lista oficial de la oficina.
// 4. ⚙️ Ajustes de conexión con la oficina (probar si la red Wi-Fi responde).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/screens/reporte_dialog.dart';
import 'package:app_movil/screens/rendimiento_dialog.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/widgets/gestion_variedades_temporales_dialog.dart';
import 'package:app_movil/widgets/gestion_sembradores_dialog.dart';
import 'package:app_movil/utils/responsive.dart';

class AdminPanelHubScreen extends StatefulWidget {
  final List<Siembra> siembras;
  final List<Siembra>? siembrasFiltradas;
  final List<Variedad> variedades;
  final List<Cama> camas;
  final List<Operario> operarios;
  final String cultivoFiltro;
  final DateTime? fechaFiltro;

  const AdminPanelHubScreen({
    super.key,
    this.siembras = const [],
    this.siembrasFiltradas,
    this.variedades = const [],
    this.camas = const [],
    this.operarios = const [],
    this.cultivoFiltro = 'TODOS',
    this.fechaFiltro,
  });

  @override
  State<AdminPanelHubScreen> createState() => _AdminPanelHubScreenState();
}

class _AdminPanelHubScreenState extends State<AdminPanelHubScreen> {
  late List<Siembra> _siembras;
  late List<Siembra> _siembrasFiltradas;
  late List<Variedad> _variedades;
  late List<Cama> _camas;
  late List<Operario> _operarios;
  int _totalTemporales = 0;
  int _totalSembradoresActivos = 0;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _siembras = List.from(widget.siembras);
    _siembrasFiltradas = widget.siembrasFiltradas != null
        ? List.from(widget.siembrasFiltradas!)
        : List.from(widget.siembras);
    _variedades = List.from(widget.variedades);
    _camas = List.from(widget.camas);
    _operarios = List.from(widget.operarios);

    if (_siembras.isEmpty || _variedades.isEmpty || _operarios.isEmpty) {
      _recargarDatos();
    }
  }

  Future<void> _recargarDatos() async {
    setState(() => _cargando = true);
    final db = DbRepository();
    final siembrasDb = await db.obtenerHistorialSiembras();
    final variedadesDb = await db.obtenerVariedades();
    final camasDb = await db.obtenerCamas();
    final operariosDb = await db.obtenerOperarios();
    final tempsDb = await db.obtenerVariedadesTemporales();
    final sembradoresDb = await db.obtenerIdsSembradoresActivos();

    if (mounted) {
      setState(() {
        _siembras = siembrasDb;
        _siembrasFiltradas = siembrasDb;
        _variedades = variedadesDb;
        _camas = camasDb;
        _operarios = operariosDb;
        _totalTemporales = tempsDb.length;
        _totalSembradoresActivos = sembradoresDb.length;
        _cargando = false;
      });
    }
  }

  void _abrirGestionTemporales() async {
    await showDialog(
      context: context,
      builder: (context) => const GestionVariedadesTemporalesDialog(),
    );
    _recargarDatos();
  }

  void _abrirGestionSembradores() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => const GestionSembradoresDialog(),
    );
    if (res == true) {
      _recargarDatos();
    }
  }

  void _abrirRendimiento() {
    final sem = CalendarioUtil.obtenerEtiquetaSemana(widget.fechaFiltro ?? DateTime.now(), incluirAnio: true);
    showDialog(
      context: context,
      builder: (context) => RendimientoDialog(
        siembras: _siembrasFiltradas.isNotEmpty ? _siembrasFiltradas : _siembras,
        operarios: _operarios,
        variedades: _variedades,
        camas: _camas,
        cultivo: widget.cultivoFiltro != 'TODOS' ? widget.cultivoFiltro : 'TODOS',
        semana: sem,
        rangoFechas: widget.fechaFiltro != null
            ? '${widget.fechaFiltro!.day.toString().padLeft(2, '0')}/${widget.fechaFiltro!.month.toString().padLeft(2, '0')}/${widget.fechaFiltro!.year}'
            : null,
      ),
    );
  }

  void _abrirReportes() {
    showDialog(
      context: context,
      builder: (context) => ReporteDialog(
        siembras: _siembras,
        variedades: _variedades,
        camas: _camas,
        operarios: _operarios,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTallos = _siembras.fold<int>(0, (sum, s) => sum + s.cantidad);
    final esMovil = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'PANEL DE ADMINISTRACIÓN',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7CB342)),
            )
          : ResponsiveContentContainer(
              maxWidth: 850,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(esMovil ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Banner Encabezado
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC5E1A5)),
                          ),
                          child: const Icon(Icons.shield, color: Color(0xFF33691E), size: 34),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo de Supervisión y Control',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Acceso administrativo reservado. Desde este panel se supervisa el rendimiento operativo y se emiten los reportes oficiales.',
                                style: TextStyle(fontSize: 12.5, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Resumen rápido de datos en el sistema
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: esMovil
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildKpiItem('Siembras', '${_siembras.length}', Icons.grass, const Color(0xFF558B2F)),
                                    const SizedBox(height: 8),
                                    _buildKpiItem('Operarios', '${_operarios.length}', Icons.people, const Color(0xFFF57F17)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 60, color: Colors.grey.shade200),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildKpiItem('Tallos / Esq.', '$totalTallos', Icons.eco, const Color(0xFF2E7D32)),
                                    const SizedBox(height: 8),
                                    if (_totalTemporales > 0)
                                      _buildKpiItem('Pruebas', '$_totalTemporales', Icons.science_rounded, const Color(0xFFD84315))
                                    else
                                      _buildKpiItem('Camas', '${_camas.length}', Icons.view_week, const Color(0xFF00796B)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildKpiItem('Siembras', '${_siembras.length}', Icons.grass, const Color(0xFF558B2F)),
                              _buildDivider(),
                              _buildKpiItem('Tallos / Esquejes', '$totalTallos', Icons.eco, const Color(0xFF2E7D32)),
                              _buildDivider(),
                              _buildKpiItem('Operarios', '${_operarios.length}', Icons.people, const Color(0xFFF57F17)),
                              if (_totalTemporales > 0) ...[
                                _buildDivider(),
                                _buildKpiItem('Pruebas', '$_totalTemporales', Icons.science_rounded, const Color(0xFFD84315)),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  // OPCIÓN 1: RENDIMIENTO DEL CORTADOR Y SEMBRADOR
                  _buildAdminCard(
                    icon: Icons.leaderboard,
                    iconBgColor: const Color(0xFFFFF3E0),
                    iconColor: const Color(0xFFE65100),
                    badgeText: 'PRODUCTIVIDAD Y CONTROL',
                    badgeColor: const Color(0xFFE65100),
                    title: 'Rendimiento del Cortador y Sembrador',
                    subtitle:
                        'Métricas detalladas de productividad individual, recuento de tallos y esquejes procesados, velocidad por cama y ranking de desempeño del personal.',
                    actionLabel: 'Ver Rendimiento y Productividad',
                    onTap: _abrirRendimiento,
                  ),

                  const SizedBox(height: 16),

                  // OPCIÓN 2: EXPORTAR REPORTES EN PDF
                  _buildAdminCard(
                    icon: Icons.picture_as_pdf,
                    iconBgColor: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF2E7D32),
                    badgeText: 'INFORMES Y DOCUMENTACIÓN OFICIAL',
                    badgeColor: const Color(0xFF2E7D32),
                    title: 'Exportar Reportes en PDF',
                    subtitle:
                        'Generación de documentos consolidados de siembra, filtrado por fechas o variedades y exportación digital en formato PDF de alta calidad.',
                    actionLabel: 'Generar Reporte PDF',
                    onTap: _abrirReportes,
                  ),

                  const SizedBox(height: 16),

                  // OPCIÓN 3: GESTIÓN Y VINCULACIÓN DE VARIEDADES TEMPORALES
                  _buildAdminCard(
                    icon: Icons.science_rounded,
                    iconBgColor: const Color(0xFFEDE7F6),
                    iconColor: const Color(0xFF512DA8),
                    badgeText: _totalTemporales > 0 ? '$_totalTemporales PENDIENTE(S) DE ACCESS' : 'SINCRONIZACIÓN AL DÍA',
                    badgeColor: _totalTemporales > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                    title: 'Variedades de Prueba y Temporales',
                    subtitle:
                        'Control de variedades creadas en campo para registrar rendimientos de corte y siembra antes de su registro oficial en Access, con vinculación y auto-reconciliación.',
                    actionLabel: 'Gestionar y Sincronizar Variedades',
                    onTap: _abrirGestionTemporales,
                  ),

                  const SizedBox(height: 16),

                  // OPCIÓN 4: GESTIÓN DE PERSONAL DE SIEMBRA (SEMBRADORES)
                  _buildAdminCard(
                    icon: Icons.badge_outlined,
                    iconBgColor: const Color(0xFFE1F5FE),
                    iconColor: const Color(0xFF0288D1),
                    badgeText: _totalSembradoresActivos > 0 ? '$_totalSembradoresActivos EN SIEMBRA' : 'SIN CONFIGURAR',
                    badgeColor: const Color(0xFF0288D1),
                    title: 'Personal de Siembra (Sembradores)',
                    subtitle:
                        'Filtra y selecciona de los ${_operarios.length} empleados de la empresa únicamente a los autorizados para registrar siembras y canastas de lirios en campo.',
                    actionLabel: 'Gestionar Sembradores',
                    onTap: _abrirGestionSembradores,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildKpiItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      elevation: 0,
                    ),
                    icon: Icon(icon, size: 18, color: Colors.white),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    onPressed: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

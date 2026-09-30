import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/screens/reporte_dialog.dart';
import 'package:app_movil/screens/rendimiento_dialog.dart';
import 'package:app_movil/utils/calendario_util.dart';

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

    if (mounted) {
      setState(() {
        _siembras = siembrasDb;
        _siembrasFiltradas = siembrasDb;
        _variedades = variedadesDb;
        _camas = camasDb;
        _operarios = operariosDb;
        _cargando = false;
      });
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildKpiItem('Siembras', '${_siembras.length}', Icons.grass, const Color(0xFF558B2F)),
                        _buildDivider(),
                        _buildKpiItem('Tallos / Esquejes', '$totalTallos', Icons.eco, const Color(0xFF2E7D32)),
                        _buildDivider(),
                        _buildKpiItem('Operarios', '${_operarios.length}', Icons.people, const Color(0xFFF57F17)),
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
                ],
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

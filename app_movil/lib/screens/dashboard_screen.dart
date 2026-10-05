import 'package:flutter/material.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/screens/menu_cultivos_screen.dart';
import 'package:app_movil/screens/admin_panel_hub_screen.dart';
import 'package:app_movil/services/network_service.dart';
import 'package:app_movil/services/sync_service.dart' as app_sync;
import 'package:app_movil/services/persistent_backup_service.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DbRepository _db = DbRepository();
  bool? _forzarModoTarjetas;
  List<Siembra> _siembras = [];
  List<Variedad> _variedades = [];
  List<Cama> _camas = [];
  List<Operario> _operarios = [];
  bool _cargando = true;

  // Filtro interactivo por fecha, semana de EE. UU. y variedad madre
  DateTime? _fechaFiltro;
  int? _semanaFiltro; // Semana US (1 a 53)
  int _anioFiltro = DateTime.now().year;
  String _cultivoFiltro = 'TODOS'; // 'TODOS', 'POMPÓN', 'CREMÓN', 'MATSUMOTO', 'LIRIOS', 'GIRASOL'

  static const List<Map<String, dynamic>> _cultivosConfig = [
    {
      'nombre': 'TODOS',
      'label': 'TODAS',
      'icono': Icons.grid_view_rounded,
      'color': Color(0xFF558B2F),
    },
    {
      'nombre': 'POMPÓN',
      'label': 'POMPÓN',
      'icono': Icons.local_florist,
      'color': Color(0xFFD81B60),
    },
    {
      'nombre': 'CREMÓN',
      'label': 'CREMÓN',
      'icono': Icons.filter_vintage,
      'color': Color(0xFF8E24AA),
    },
    {
      'nombre': 'MATSUMOTO',
      'label': 'MATSUMOTO',
      'icono': Icons.yard,
      'color': Color(0xFF00897B),
    },
    {
      'nombre': 'LIRIOS',
      'label': 'LIRIOS',
      'icono': Icons.spa,
      'color': Color(0xFF283593),
    },
    {
      'nombre': 'GIRASOL',
      'label': 'GIRASOL',
      'icono': Icons.wb_sunny,
      'color': Color(0xFFF57F17),
    },
  ];

  late NetworkService _networkService;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _networkService = NetworkService(
      onNetworkRestored: () {
        // Modo manual: No auto-sincronizar automáticamente en segundo plano.
        // La sincronización se realiza únicamente cuando el usuario presiona el botón.
      },
    );
  }

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos({bool mostrarNotificacionRespaldo = false}) async {
    setState(() => _cargando = true);
    
    // Auto-recuperación y verificación desde almacenamiento persistente independiente de caché
    final resultado = await _db.restaurarDesdeRespaldoPersistente();

    final historial = await _db.obtenerHistorialSiembras();
    final v = await _db.obtenerVariedades(soloActivas: true);
    final c = await _db.obtenerCamas();
    final o = await _db.obtenerOperarios();
    if (!mounted) return;
    setState(() {
      _siembras = historial;
      _variedades = v;
      _camas = c;
      _operarios = o;
      _cargando = false;
    });

    if (resultado.huboRecuperacion && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.security, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🛡️ Se recuperaron ${resultado.recuperadas} siembras guardadas de forma permanente antes de que la tablet se apagara o reiniciara.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF33691E),
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (mostrarNotificacionRespaldo && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Respaldo verificado: Todas las siembras (${resultado.pendientesSync} pendientes) están 100% protegidas contra apagado o reinicio.',
          ),
          backgroundColor: const Color(0xFF558B2F),
        ),
      );
    }
  }

  String _normalizarCultivo(String c) {
    final s = c.trim().toUpperCase()
        .replaceAll('Ó', 'O')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Á', 'A')
        .replaceAll('Ú', 'U');
    if (s.contains('POMP')) return 'POMPÓN';
    if (s.contains('CREM')) return 'CREMÓN';
    if (s.contains('MATSUMOTO') || s.contains('ASTER')) return 'MATSUMOTO';
    if (s.contains('LIRIO') || s.contains('LILIUM')) return 'LIRIOS';
    if (s.contains('GIRASOL') || s.contains('SUNFLOWER')) return 'GIRASOL';
    return c;
  }

  String _obtenerCultivoDeSiembra(Siembra s) {
    final va = _variedades.firstWhere(
      (v) => v.id == s.variedadId,
      orElse: () => Variedad(id: s.variedadId, codigo: '', nombre: ''),
    );
    return _obtenerCultivoDeVariedad(va, s.observaciones);
  }

  String _obtenerCultivoDeVariedad(Variedad va, [String? observaciones]) {
    final fam = (va.familiaNombre ?? '').toUpperCase();
    final nom = va.nombre.toUpperCase();
    final obs = (observaciones ?? '').toUpperCase();
    final famId = va.familiaId ?? 0;

    // 1. LIRIOS: Lilium, Lirio, IDs 199, 204, 309, 255
    if (fam.contains('LILIUM') ||
        fam.contains('LIRIO') ||
        obs.contains('LIRIO') ||
        nom.contains('LIRIO') ||
        fam.contains('LONGIFLORUM') ||
        fam.contains('ASIATICO') ||
        fam.contains('ORIENTAL') ||
        [199, 204, 309, 255].contains(famId)) {
      return 'LIRIOS';
    }

    // 2. GIRASOL: Sunflower, Girasol, ID 213
    if (fam.contains('SUNFLOWER') ||
        fam.contains('GIRASOL') ||
        obs.contains('GIRASOL') ||
        nom.contains('GIRASOL') ||
        famId == 213) {
      return 'GIRASOL';
    }

    // 3. MATSUMOTO: Matsumoto, Aster, IDs 114, 118, 262
    if (fam.contains('MATSUMOTO') ||
        obs.contains('MATSUMOTO') ||
        nom.contains('MATSUMOTO') ||
        fam.contains('ASTER') ||
        [114, 118, 262].contains(famId)) {
      return 'MATSUMOTO';
    }

    // 4. CREMON: Cremon, Fuji, Disbud, IDs 193, 200, 148
    if (fam.contains('CREMON') ||
        fam.contains('FUJI') ||
        fam.contains('DISBUD') ||
        obs.contains('CREMON') ||
        nom.contains('CREMON') ||
        [193, 200, 148].contains(famId)) {
      return 'CREMÓN';
    }

    // 5. POMPON: Pompon, Crisantemo, ID 147
    if ((fam.contains('POMPON') ||
            fam.contains('CRISANTEMO') ||
            obs.contains('POMPON') ||
            nom.contains('POMPON') ||
            famId == 147) &&
        !fam.contains('CREMON') &&
        !obs.contains('CREMON') &&
        !nom.contains('CREMON')) {
      return 'POMPÓN';
    }

    if (fam.contains('POMP') || nom.contains('POMP')) return 'POMPÓN';
    if (fam.contains('CREM') || nom.contains('CREM')) return 'CREMÓN';

    return 'OTRO';
  }

  Map<String, int> _calcularConteoCultivos() {
    final Map<String, int> counts = {
      'TODOS': 0,
      'POMPÓN': 0,
      'CREMÓN': 0,
      'MATSUMOTO': 0,
      'LIRIOS': 0,
      'GIRASOL': 0,
    };

    for (var s in _siembras) {
      if (_fechaFiltro != null) {
        final dStr = _fechaFiltro!.day.toString().padLeft(2, '0');
        final mStr = _fechaFiltro!.month.toString().padLeft(2, '0');
        final yStr = _fechaFiltro!.year.toString();
        final match1 = "$dStr/$mStr/$yStr";
        final match2 = "$yStr-$mStr-$dStr";
        if (!s.fecha.contains(match1) && !s.fecha.contains(match2)) {
          continue;
        }
      } else if (_semanaFiltro != null) {
        final f = CalendarioUtil.parsearFecha(s.fecha);
        if (f == null || f.year != _anioFiltro || CalendarioUtil.obtenerSemanaUS(f) != _semanaFiltro) {
          continue;
        }
      }

      counts['TODOS'] = (counts['TODOS'] ?? 0) + 1;
      final c = _obtenerCultivoDeSiembra(s);
      final cNorm = _normalizarCultivo(c);
      if (counts.containsKey(cNorm)) {
        counts[cNorm] = (counts[cNorm] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Siembra> get _siembrasFiltradas {
    return _siembras.where((s) {
      if (_fechaFiltro != null) {
        final dStr = _fechaFiltro!.day.toString().padLeft(2, '0');
        final mStr = _fechaFiltro!.month.toString().padLeft(2, '0');
        final yStr = _fechaFiltro!.year.toString();
        final match1 = "$dStr/$mStr/$yStr";
        final match2 = "$yStr-$mStr-$dStr";
        if (!s.fecha.contains(match1) && !s.fecha.contains(match2)) {
          return false;
        }
      } else if (_semanaFiltro != null) {
        final f = CalendarioUtil.parsearFecha(s.fecha);
        if (f == null || f.year != _anioFiltro || CalendarioUtil.obtenerSemanaUS(f) != _semanaFiltro) {
          return false;
        }
      }
      if (_cultivoFiltro != 'TODOS') {
        final cult = _obtenerCultivoDeSiembra(s);
        if (_normalizarCultivo(cult) != _normalizarCultivo(_cultivoFiltro)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _abrirAdminVariedades() async {
    final pinController = TextEditingController(text: '1234');
    final auth = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF7CB342), size: 28),
            SizedBox(width: 8),
            Text(
              'Acceso Administrador',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el PIN de Administrador para acceder a reportes, exportación PDF y rendimiento del personal:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN de Administrador',
                hintText: '1234',
                prefixIcon: const Icon(Icons.key, color: Color(0xFF7CB342)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7CB342), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7CB342),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (pinController.text.trim() == '1234' || pinController.text.trim() == 'admin1234') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN incorrecto. (PIN por defecto: 1234)')),
                );
              }
            },
            child: const Text('Ingresar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (auth == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPanelHubScreen(
            siembras: _siembras,
            siembrasFiltradas: _siembrasFiltradas,
            variedades: _variedades,
            camas: _camas,
            operarios: _operarios,
            cultivoFiltro: _cultivoFiltro,
            fechaFiltro: _fechaFiltro,
          ),
        ),
      );
      _cargarDatos();
    }
  }

  Future<void> _confirmarYEliminarSiembra(Siembra s) async {
    if (s.idLocal == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Eliminar Siembra',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Está seguro de que desea eliminar este registro de siembra de la base de datos?',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Fecha: ${s.fecha}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('• Cantidad: ${s.cantidad} esquejes'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar Registro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _db.eliminarSiembra(s.idLocal!);
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Registro de siembra eliminado correctamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoSincronizar() async {
    if (_sincronizando) return;

    final syncSvc = app_sync.SyncService();
    setState(() => _sincronizando = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Sincronizando con Servidor Empresarial...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF558B2F),
        ),
      );
    }

    bool catalogosExito = await syncSvc.descargarCatalogos();
    final pendientes = await _db.obtenerSiembrasPendientesSync();
    bool subidaExito = true;
    if (pendientes.isNotEmpty) {
      subidaExito = await syncSvc.sincronizarPendientes();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (catalogosExito && subidaExito) {
        final urlUsada = syncSvc.ultimaUrlProbada ?? 'Servidor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sincronización Completa (${_variedades.length} Variedades, ${_camas.length} Camas) ✓\nConectado a: $urlUsada',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF558B2F),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final String url = syncSvc.ultimaUrlProbada ?? 'http://192.168.1.39:8000/api';
        final String detalleError = syncSvc.ultimoError != null ? '\nDetalle: ${syncSvc.ultimoError}' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'No se pudo conectar al Servidor Backend',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'URL: $url\n'
                  '• En la PC, ejecuta "iniciar_backend.bat".\n'
                  '• Verifica que la tablet y la PC estén en la misma red Wi-Fi.$detalleError',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'CONFIGURAR IP',
              textColor: Colors.amber.shade200,
              onPressed: _mostrarSincronizacionDialog,
            ),
          ),
        );
      }
    }
    setState(() => _sincronizando = false);
    _cargarDatos();
  }

  Future<void> _seleccionarFechaFiltro() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Text('Filtrar Siembras por Fecha / Semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF33691E))),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.today, color: Color(0xFF558B2F))),
              title: const Text('Semana Actual (Calendario EE. UU.)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Semana ${CalendarioUtil.obtenerSemanaUS(DateTime.now())} (${DateTime.now().year})'),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF558B2F)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _semanaFiltro = CalendarioUtil.obtenerSemanaUS(DateTime.now());
                  _anioFiltro = DateTime.now().year;
                  _fechaFiltro = null;
                });
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.calendar_month, color: Color(0xFF558B2F))),
              title: const Text('Seleccionar por Semana (EE. UU.)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Elegir una semana específica del calendario agronómico'),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF558B2F)),
              onTap: () {
                Navigator.pop(ctx);
                _abrirSelectorSemanaFiltro();
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.calendar_today, color: Color(0xFF558B2F))),
              title: const Text('Seleccionar Día Específico', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Elegir una fecha puntual en el calendario'),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF558B2F)),
              onTap: () async {
                Navigator.pop(ctx);
                final DateTime? seleccionada = await showDatePicker(
                  context: context,
                  initialDate: _fechaFiltro ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: Color(0xFF7CB342), onPrimary: Colors.white, onSurface: Color(0xFF263238)),
                    ),
                    child: child!,
                  ),
                );
                if (seleccionada != null) {
                  setState(() {
                    _fechaFiltro = seleccionada;
                    _semanaFiltro = null;
                  });
                }
              },
            ),
            if (_fechaFiltro != null || _semanaFiltro != null) ...[
              const Divider(),
              TextButton.icon(
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text('Quitar Filtro de Fecha / Semana', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _fechaFiltro = null;
                    _semanaFiltro = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _abrirSelectorSemanaFiltro() {
    final semanas = CalendarioUtil.obtenerListaSemanasDelAnio(_anioFiltro);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text(
              'Seleccionar Semana (Calendario EE. UU.)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF33691E)),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: semanas.length,
                itemBuilder: (c, idx) {
                  final item = semanas[idx];
                  final semNum = item['semana'] as int;
                  final now = DateTime.now();
                  final esActual = (now.year == _anioFiltro && CalendarioUtil.obtenerSemanaUS(now) == semNum);
                  final isSelected = (_semanaFiltro == semNum);

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isSelected
                          ? const Color(0xFF33691E)
                          : esActual
                              ? const Color(0xFF7CB342)
                              : const Color(0xFFF1F8E9),
                      child: Text(
                        '$semNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (isSelected || esActual) ? Colors.white : const Color(0xFF33691E),
                        ),
                      ),
                    ),
                    title: Text(
                      item['etiquetaCompleta'] as String,
                      style: TextStyle(
                        fontWeight: (isSelected || esActual) ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF33691E) : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF33691E), size: 20)
                        : esActual
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFDCEDC8), borderRadius: BorderRadius.circular(6)),
                                child: const Text('ACTUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF33691E))),
                              )
                            : null,
                    onTap: () {
                      setState(() {
                        _semanaFiltro = semNum;
                        _fechaFiltro = null;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMetricasDialog() {
    int totalTallos = 0;
    int activas = 0;
    int finalizadas = 0;
    for (var s in _siembrasFiltradas) {
      totalTallos += s.cantidad;
      if (s.estado == 'ACTIVA') {
        activas++;
      } else {
        finalizadas++;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Color(0xFF7CB342), size: 28),
            SizedBox(width: 8),
            Text('Resumen de Siembra', style: TextStyle(color: Color(0xFF33691E), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Registros:', '${_siembrasFiltradas.length} siembras'),
            const Divider(),
            _buildStatRow('Siembras Activas:', '$activas camas', color: Colors.green.shade700),
            const Divider(),
            _buildStatRow('Ciclos Finalizados:', '$finalizadas camas', color: Colors.grey.shade700),
            const Divider(),
            _buildStatRow('Tallos/Esquejes Totales:', '$totalTallos unidades', color: const Color(0xFF33691E)),
            const Divider(),
            _buildStatRow('Variedades en Catálogo:', '${_variedades.length} activas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF7CB342), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarSincronizacionDialog() async {
    final pendientesList = await _db.obtenerSiembrasPendientesSync();
    final pendientes = pendientesList.length;
    final total = _siembras.length;
    final sincronizadas = total - pendientes;
    final syncSvc = app_sync.SyncService();
    final currentUrl = await syncSvc.getBaseUrl();
    final urlController = TextEditingController(text: currentUrl);
    String estadoConexion = '';
    bool probando = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.sync_alt, color: Color(0xFF7CB342), size: 28),
              SizedBox(width: 8),
              Text('Sincronización y Servidor', style: TextStyle(color: Color(0xFF33691E), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Sincronizadas con Servidor:', '$sincronizadas', color: Colors.green.shade700),
                const Divider(),
                _buildStatRow('Pendientes por subir:', '$pendientes', color: pendientes > 0 ? Colors.orange.shade800 : Colors.grey),
                const Divider(),
                _buildStatRow('Resguardo Antiapagado:', 'Activo y Seguro ✓', color: const Color(0xFF2E7D32)),
                const SizedBox(height: 16),
                const Text('Dirección IP / URL del Servidor Backend:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E))),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.X:8000/api',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.network_check, color: Color(0xFF7CB342)),
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
                  const SizedBox(height: 6),
                  Text(
                    estadoConexion,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: estadoConexion.startsWith('✓') ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text('Atajos rápidos para Tablets / Emulador:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.wifi, size: 14, color: Color(0xFF33691E)),
                      label: const Text('Wi-Fi PC (192.168.1.39)', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () {
                        setDialogState(() {
                          urlController.text = 'http://192.168.1.39:8000/api';
                          estadoConexion = '';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.developer_mode, size: 14, color: Colors.grey),
                      label: const Text('Emulador (10.0.2.2)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          urlController.text = 'http://10.0.2.2:8000/api';
                          estadoConexion = '';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342)),
              icon: const Icon(Icons.sync, color: Colors.white, size: 18),
              label: const Text('Guardar y Sincronizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await syncSvc.setBaseUrl(urlController.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _autoSincronizar();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoRespaldoPersistente() async {
    final diag = await PersistentBackupService.instance.obtenerDiagnosticoRespaldo();
    final pendientes = _siembras.where((s) => s.sincronizado == 0).length;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF558B2F), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Almacenamiento Permanente',
                style: TextStyle(color: Color(0xFF33691E), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Protección Activa contra Apagado y Reinicio de Tablet',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow('Total Registros en Tablet:', '${_siembras.length}'),
              const Divider(),
              _buildStatRow('Pendientes de Sincronizar:', '$pendientes', color: pendientes > 0 ? Colors.orange.shade900 : Colors.green),
              const Divider(),
              _buildStatRow('Copia Espejo de Emergencia:', diag['activo'] == true ? 'Actualizada y Activa ✓' : 'En proceso...', color: const Color(0xFF33691E)),
              const SizedBox(height: 12),
              const Text(
                '¿Cómo funciona esta protección?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E)),
              ),
              const SizedBox(height: 5),
              const Text(
                'Cada siembra se escribe directamente con sincronización física obligatoria (fsync) en la memoria interna permanente y en archivos espejo fuera de la memoria caché. Si la tablet se apaga, se reinicia o se descarga al 0%, los registros pendientes NO se pierden y se recuperan automáticamente.',
                style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF558B2F)),
            icon: const Icon(Icons.verified, color: Colors.white, size: 18),
            label: const Text('Verificar Respaldo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _cargarDatos(mostrarNotificacionRespaldo: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarFinalizarCiclo(Siembra s, Cama ca, Variedad va) async {
    final now = DateTime.now();
    final fechaHoy = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final fechaFinController = TextEditingController(text: fechaHoy);

    final cfg = await _db.obtenerConfigAgronomicaParaVariedad(va);
    final int diasRequeridos = va.diasCiclo ?? cfg.diasCiclo;
    final fInicio = parsearFechaSiembra(s.fecha) ?? DateTime.now();
    final int diasTranscurridos = now.difference(fInicio).inDays >= 0 ? now.difference(fInicio).inDays : 0;
    final bool cicloIncompleto = diasTranscurridos < diasRequeridos;

    if (!mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_available, color: Color(0xFF7CB342), size: 28),
            SizedBox(width: 8),
            Text('Finalizar Ciclo de Siembra', style: TextStyle(color: Color(0xFF33691E), fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Desea cerrar el ciclo de cultivo para esta cama?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC5E1A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Cama: ${ca.cama} (Bloque ${s.bloqueCodigo ?? ca.bloque})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('• Variedad: ${va.nombre}'),
                    Text('• Fecha Inicio: ${s.fecha}'),
                    Text('• Cantidad: ${s.cantidad} esquejes'),
                    Text('• Ciclo Variedad: $diasRequeridos días (Lleva: $diasTranscurridos días)'),
                  ],
                ),
              ),
              if (cicloIncompleto)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '¡Ciclo Agronómico Incompleto!',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Requiere: $diasRequeridos días | Transcurridos: $diasTranscurridos días (Faltan ${diasRequeridos - diasTranscurridos} días)',
                        style: TextStyle(fontSize: 12, color: Colors.brown.shade900, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cerrar anticipadamente indica cosecha adelantada, descarte o daño del cultivo.',
                        style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: fechaFinController,
                decoration: const InputDecoration(
                  labelText: 'Fecha de Finalización (DD/MM/AAAA)',
                  prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF7CB342)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF558B2F), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cicloIncompleto
                          ? 'Nota: Aunque se registre la finalización, la cama requiere $diasRequeridos días de ciclo agronómico (faltan ${diasRequeridos - diasTranscurridos} días para nueva siembra).'
                          : 'Al finalizar este ciclo, la Cama ${ca.cama} quedará DISPONIBLE para una nueva siembra.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cicloIncompleto ? Colors.brown.shade800 : Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar Ciclo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && s.idLocal != null) {
      final fFin = fechaFinController.text.trim().isNotEmpty ? fechaFinController.text.trim() : fechaHoy;
      await _db.finalizarCicloSiembra(s.idLocal!, fFin);
      _autoSincronizar();
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Ciclo finalizado. Cama ${ca.cama} ahora está DISPONIBLE para sembrar.'),
            backgroundColor: const Color(0xFF33691E),
          ),
        );
      }
    }
  }

  void _mostrarDetalleSiembra(Siembra s, Operario op, Variedad va, Cama ca, int diasCiclo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.grass, color: Color(0xFF7CB342), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detalle de Siembra: ${va.nombre}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: s.estado == 'ACTIVA' ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.estado,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: s.estado == 'ACTIVA' ? Colors.green.shade900 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow('Fecha de Siembra:', s.fecha),
            _buildStatRow('Empleado / Operario:', op.nombreCompleto),
            _buildStatRow('Variedad:', '${va.nombre} (${va.codigo})'),
            _buildStatRow('Bloque:', s.bloqueCodigo ?? ca.bloque),
            _buildStatRow('Cama:', ca.cama),
            _buildStatRow('Cantidad Esquejes (Esq):', '${s.cantidad} unidades'),
            _buildStatRow('Líneas (Line):', s.lineas != null ? '${s.lineas}' : '-'),
            _buildStatRow('Lote:', (_obtenerCultivoDeSiembra(s) == 'LIRIOS' && s.lote != null && s.lote!.isNotEmpty) ? s.lote! : '-'),
            _buildStatRow('Proveedor (Provee):', (_obtenerCultivoDeSiembra(s) == 'LIRIOS' && s.proveedor != null && s.proveedor!.isNotEmpty) ? s.proveedor! : '-'),
            _buildStatRow('Contenedor / Conteo (Cont):', (_obtenerCultivoDeSiembra(s) == 'LIRIOS' && s.cont != null && s.cont!.isNotEmpty) ? s.cont! : '-'),
            () {
              final nomVaUpper = va.nombre.toUpperCase();
              final codVaUpper = va.codigo.toUpperCase();
              final bool esClonVa = nomVaUpper.contains('POMPON') ||
                  nomVaUpper.contains('POMPÓN') ||
                  nomVaUpper.contains('CREMON') ||
                  nomVaUpper.contains('CREMÓN') ||
                  codVaUpper.startsWith('POM') ||
                  codVaUpper.startsWith('CRM') ||
                  codVaUpper.startsWith('CRE');
              return _buildStatRow(esClonVa ? 'Clon:' : 'Observaciones:', (s.observaciones != null && s.observaciones!.isNotEmpty) ? s.observaciones! : '-');
            }(),
            _buildStatRow('Días de Ciclo:', '$diasCiclo días ${s.estado == 'ACTIVA' ? '(en curso)' : '(finalizado)'}'),
            if (s.fechaFin != null && s.fechaFin!.isNotEmpty)
              _buildStatRow('Fecha Fin:', s.fechaFin!),
            FutureBuilder<List<Siembra>>(
              future: _db.obtenerSiembrasActivasPorCama(s.camaId),
              builder: (ctx, snapshot) {
                if (snapshot.hasData && (snapshot.data?.length ?? 0) > 1) {
                  final activas = snapshot.data!;
                  final int totalCama = activas.fold(0, (sum, item) => sum + item.cantidad);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB300)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.group_work, color: Color(0xFFE65100), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Cama Compartida (${activas.length} registros activos)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFE65100)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total sembrado en esta cama: $totalCama esquejes/plantas',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7CB342),
                      side: const BorderSide(color: Color(0xFF7CB342)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _dialogEditarSiembra(s);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmarYEliminarSiembra(s);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7CB342),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialogEditarSiembra(Siembra s) async {
    final fechaCtrl = TextEditingController(text: s.fecha);
    final cantidadCtrl = TextEditingController(text: s.cantidad.toString());
    final lineasCtrl = TextEditingController(text: s.lineas != null ? s.lineas.toString() : '');
    final loteCtrl = TextEditingController(text: s.lote ?? '');
    final proveedorCtrl = TextEditingController(text: s.proveedor ?? '');
    final contCtrl = TextEditingController(text: s.cont ?? '');
    final obsCtrl = TextEditingController(text: s.observaciones ?? '');

    int selOperarioId = s.operarioId;
    int selVariedadId = s.variedadId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final varActual = _variedades.firstWhere(
            (v) => v.id == selVariedadId,
            orElse: () => Variedad(id: selVariedadId, codigo: '', nombre: 'Variedad #$selVariedadId'),
          );

          final nomUpper = varActual.nombre.toUpperCase();
          final codUpper = varActual.codigo.toUpperCase();
          final bool esClonReq = nomUpper.contains('POMPON') ||
              nomUpper.contains('POMPÓN') ||
              nomUpper.contains('CREMON') ||
              nomUpper.contains('CREMÓN') ||
              codUpper.startsWith('POM') ||
              codUpper.startsWith('CRM') ||
              codUpper.startsWith('CRE');
          final bool esLirioReq = _obtenerCultivoDeVariedad(varActual) == 'LIRIOS';

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFF7CB342), size: 28),
                const SizedBox(width: 8),
                Text(
                  'Editar Registro #${s.idLocal ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E), fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fechaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Fecha (DD/MM/AAAA)',
                            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF7CB342)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.date_range, color: Color(0xFF7CB342)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            final fStr = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                            setDialogState(() => fechaCtrl.text = fStr);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: _variedades.any((v) => v.id == selVariedadId) ? selVariedadId : null,
                    decoration: InputDecoration(
                      labelText: 'Variedad',
                      prefixIcon: const Icon(Icons.local_florist, color: Color(0xFF7CB342)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _variedades.map((v) {
                      return DropdownMenuItem<int>(
                        value: v.id,
                        child: Text('${v.nombre} (${v.codigo})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selVariedadId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: _operarios.any((o) => o.id == selOperarioId) ? selOperarioId : null,
                    decoration: InputDecoration(
                      labelText: 'Empleado / Operario',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF7CB342)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _operarios.map((o) {
                      return DropdownMenuItem<int>(
                        value: o.id,
                        child: Text(o.nombreCompleto),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selOperarioId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cantidad (Esquejes / Tallos)',
                      helperText: 'Variedad: ${varActual.nombre}',
                      prefixIcon: const Icon(Icons.numbers, color: Color(0xFF7CB342)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (esLirioReq) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lineasCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Líneas',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: loteCtrl,
                            decoration: InputDecoration(
                              labelText: 'Lote * (Obligatorio)',
                              labelStyle: const TextStyle(color: Color(0xFF283593), fontWeight: FontWeight.bold),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: proveedorCtrl,
                            decoration: InputDecoration(
                              labelText: 'Proveedor * (Obligatorio)',
                              labelStyle: const TextStyle(color: Color(0xFF283593), fontWeight: FontWeight.bold),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: contCtrl,
                            decoration: InputDecoration(
                              labelText: 'Contenedor * (Obligatorio)',
                              labelStyle: const TextStyle(color: Color(0xFF283593), fontWeight: FontWeight.bold),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: lineasCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Líneas',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  TextField(
                    controller: obsCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: esClonReq ? 'Clon * (Obligatorio)' : 'Observaciones (Opcional)',
                      labelStyle: TextStyle(
                        color: esClonReq ? Colors.deepOrange.shade800 : null,
                        fontWeight: esClonReq ? FontWeight.bold : FontWeight.normal,
                      ),
                      hintText: esClonReq ? 'Ej: 4-25, 3-25...' : 'Notas adicionales...',
                      prefixIcon: Icon(
                        esClonReq ? Icons.tag : Icons.comment,
                        color: esClonReq ? Colors.deepOrange : const Color(0xFF7CB342),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: esClonReq
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                            )
                          : null,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7CB342),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final cant = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
                  if (cant <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa una cantidad válida mayor a 0')),
                    );
                    return;
                  }

                  // Validación 1: Conflicto de ciclo agronómico y capacidad de cama
                  final fNuevaStr = fechaCtrl.text.trim().isNotEmpty ? fechaCtrl.text.trim() : s.fecha;
                  final valCiclo = await _db.validarCicloYCamaParaSiembra(
                    s.camaId,
                    fNuevaStr,
                    nuevaCantidad: cant,
                    nuevaVariedadId: s.variedadId,
                    nuevoOperarioId: s.operarioId,
                    excluirSiembraId: s.idLocal,
                  );
                  if (!mounted) return;
                  if (!valCiclo.esValido) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('❌ ${valCiclo.mensaje}'),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Validación 2: Límite agronómico estricto
                  final cfgVar = await _db.obtenerConfigAgronomicaParaVariedad(varActual);
                  if (!mounted) return;
                  final int limitePermitido = varActual.limiteEsquejes ?? cfgVar.limiteEsquejes;
                  if (cant > limitePermitido) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('❌ Límite excedido: Máximo permitido para ${varActual.nombre} es $limitePermitido esquejes (Ingresó: $cant).'),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Validación 3: Clon obligatorio para Pompon y Cremon
                  if (esClonReq && obsCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('❌ El Clon es OBLIGATORIO para variedades de Pompon o Cremon (Ej: 4-25, 3-25).'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Validación 4: Trazabilidad obligatoria para Lirios
                  if (esLirioReq) {
                    if (loteCtrl.text.trim().isEmpty ||
                        proveedorCtrl.text.trim().isEmpty ||
                        contCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('❌ Para Lirios, Lote, Contenedor y Proveedor son estrictamente OBLIGATORIOS.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                  }

                  final nuevaSiembra = s.copyWith(
                    fecha: fNuevaStr,
                    cantidad: cant,
                    variedadId: selVariedadId,
                    operarioId: selOperarioId,
                    lineas: int.tryParse(lineasCtrl.text.trim()),
                    lote: esLirioReq && loteCtrl.text.trim().isNotEmpty ? loteCtrl.text.trim() : null,
                    proveedor: esLirioReq && proveedorCtrl.text.trim().isNotEmpty ? proveedorCtrl.text.trim() : null,
                    cont: esLirioReq && contCtrl.text.trim().isNotEmpty ? contCtrl.text.trim() : null,
                    observaciones: obsCtrl.text.trim().isNotEmpty ? obsCtrl.text.trim().toUpperCase() : null,
                    sincronizado: 0,
                  );

                  try {
                    await _db.actualizarSiembra(nuevaSiembra);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _cargarDatos();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Registro de siembra actualizado correctamente.'),
                        backgroundColor: Color(0xFF7CB342),
                      ),
                    );
                  } on AgronomicValidationException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.red, content: Text('❌ $e')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.red, content: Text('Error al actualizar: $e')),
                    );
                  }
                },
                child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrirModalEditarRegistro() async {
    final lista = _siembrasFiltradas;
    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros de siembra para editar.')),
      );
      return;
    }

    if (lista.length == 1) {
      await _dialogEditarSiembra(lista.first);
      return;
    }

    String busqueda = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtrados = lista.where((s) {
              if (busqueda.isEmpty) return true;
              final q = busqueda.toLowerCase();
              final va = _variedades.firstWhere((v) => v.id == s.variedadId, orElse: () => Variedad(id: 0, codigo: '', nombre: ''));
              final op = _operarios.firstWhere((o) => o.id == s.operarioId, orElse: () => Operario(id: 0, cedula: '', nombreCompleto: ''));
              return va.nombre.toLowerCase().contains(q) ||
                  op.nombreCompleto.toLowerCase().contains(q) ||
                  s.fecha.contains(q) ||
                  (s.bloqueCodigo ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const Text(
                    'Seleccionar Registro para Editar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por variedad, operario o fecha...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) => setModalState(() => busqueda = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('No se encontraron registros'))
                        : ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final s = filtrados[i];
                              final va = _variedades.firstWhere(
                                (v) => v.id == s.variedadId,
                                orElse: () => Variedad(id: 0, codigo: '', nombre: 'Variedad #${s.variedadId}'),
                              );
                              final op = _operarios.firstWhere(
                                (o) => o.id == s.operarioId,
                                orElse: () => Operario(id: 0, cedula: '', nombreCompleto: 'Operario #${s.operarioId}'),
                              );
                              final ca = _camas.firstWhere(
                                (c) => c.id == s.camaId,
                                orElse: () => Cama(id: 0, cama: s.camaId.toString(), bloque: s.bloqueCodigo ?? '', nave: ''),
                              );

                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE8F5E9),
                                  child: Icon(Icons.edit_note, color: Color(0xFF7CB342)),
                                ),
                                title: Text(
                                  '${va.nombre} - ${s.fecha}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                                ),
                                subtitle: Text('Operario: ${op.nombreCompleto} | Cama: ${ca.cama} | Cantidad: ${s.cantidad} esq'),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF7CB342)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _dialogEditarSiembra(s);
                                },
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
  }



  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? const Color(0xFF33691E)),
          ),
        ],
      ),
    );
  }

  Widget _buildChipCultivo(Map<String, dynamic> cfg, Map<String, int> conteoCultivos) {
    final nombre = cfg['nombre'] as String;
    final label = cfg['label'] as String;
    final icono = cfg['icono'] as IconData;
    final color = cfg['color'] as Color;
    final isSelected = _cultivoFiltro == nombre;
    final count = conteoCultivos[nombre] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _cultivoFiltro = nombre;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.35),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 15,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.28)
                      : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiembraCardMobile(
    Siembra s,
    Operario op,
    Variedad va,
    Cama ca,
    int diasCiclo,
    bool isSynced,
    bool esActiva,
  ) {
    final cultivo = _obtenerCultivoDeSiembra(s);
    final fSiembra = CalendarioUtil.parsearFecha(s.fecha);
    final semStr = fSiembra != null ? 'Sem. ${CalendarioUtil.obtenerSemanaUS(fSiembra)}' : '';
    final esLirioItem = cultivo == 'LIRIOS';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esActiva ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mostrarDetalleSiembra(s, op, va, ca, diasCiclo),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Variedad + Estado badge + Sync
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          va.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF558B2F).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cultivo,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF33691E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                op.nombreCompleto,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: esActiva ? Colors.green.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: esActiva ? Colors.green.shade300 : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      esActiva ? '🟢 ACTIVA' : '⚪ FINALIZADA',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: esActiva ? Colors.green.shade800 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isSynced ? Icons.check_circle : Icons.cloud_upload_outlined,
                    size: 18,
                    color: isSynced ? const Color(0xFF7CB342) : Colors.amber.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Fila de datos en píldoras (Bloque/Cama, Cantidad/Esquejes, Fecha/Semana, Ciclo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBF7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPildoraInfo('UBICACIÓN', '${s.bloqueCodigo ?? ca.bloque} - C${ca.cama}'),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    _buildPildoraInfo('CANTIDAD', '${s.cantidad} esq'),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    _buildPildoraInfo('FECHA', '${s.fecha} ${semStr.isNotEmpty ? "($semStr)" : ""}'),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    _buildPildoraInfo('CICLO', '$diasCiclo d'),
                  ],
                ),
              ),

              // Datos adicionales (líneas, lote, proveedor si lirios, o notas)
              if ((esLirioItem && (s.lote != null || s.proveedor != null)) || (s.observaciones != null && s.observaciones!.isNotEmpty)) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (s.lineas != null) ...[
                      Text('Lín: ${s.lineas}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                    ],
                    if (esLirioItem && s.lote != null && s.lote!.isNotEmpty) ...[
                      Text('Lote: ${s.lote}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      const SizedBox(width: 8),
                    ],
                    if (s.observaciones != null && s.observaciones!.isNotEmpty)
                      Expanded(
                        child: Text(
                          'Obs: ${s.observaciones}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              // Acciones en tarjeta
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (esActiva)
                    InkWell(
                      onTap: () => _confirmarFinalizarCiclo(s, ca, va),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7CB342),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Finalizar Ciclo', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20, color: Color(0xFF558B2F)),
                    tooltip: 'Ver detalle',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onPressed: () => _mostrarDetalleSiembra(s, op, va, ca, diasCiclo),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: 'Eliminar',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onPressed: () => _confirmarYEliminarSiembra(s),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPildoraInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.2),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  int _calcularDiasCiclo(Siembra s) {
    try {
      DateTime fInicio = DateTime.now();
      if (s.fecha.contains('/')) {
        final p = s.fecha.split('/');
        fInicio = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      } else {
        final pIso = DateTime.tryParse(s.fecha);
        if (pIso != null) fInicio = pIso;
      }
      DateTime fFin = DateTime.now();
      if (s.estado == 'FINALIZADA' && s.fechaFin != null && s.fechaFin!.isNotEmpty) {
        if (s.fechaFin!.contains('/')) {
          final p = s.fechaFin!.split('/');
          fFin = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        } else {
          final pIsoFin = DateTime.tryParse(s.fechaFin!);
          if (pIsoFin != null) fFin = pIsoFin;
        }
      }
      final diff = fFin.difference(fInicio).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildSelectorFecha({double? width}) {
    final bool tieneFiltro = _fechaFiltro != null || _semanaFiltro != null;
    String labelFiltro = "Fecha / Sem.";
    if (_semanaFiltro != null) {
      labelFiltro = "Semana #$_semanaFiltro";
    } else if (_fechaFiltro != null) {
      final sem = CalendarioUtil.obtenerSemanaUS(_fechaFiltro!);
      labelFiltro = "${_fechaFiltro!.day.toString().padLeft(2, '0')}/${_fechaFiltro!.month.toString().padLeft(2, '0')} (S$sem)";
    }

    final child = InkWell(
      onTap: _seleccionarFechaFiltro,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tieneFiltro ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tieneFiltro ? const Color(0xFF558B2F) : Colors.grey.shade400,
            width: tieneFiltro ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelFiltro,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: tieneFiltro ? FontWeight.bold : FontWeight.w500,
                  color: tieneFiltro ? const Color(0xFF33691E) : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tieneFiltro)
              GestureDetector(
                onTap: () => setState(() {
                  _fechaFiltro = null;
                  _semanaFiltro = null;
                }),
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              )
            else
              const Icon(Icons.arrow_drop_down, color: Color(0xFF558B2F), size: 18),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final listaMostrar = _siembrasFiltradas;
    final conteoCultivos = _calcularConteoCultivos();
    final pendientesSync = _siembras.where((s) => s.sincronizado == 0).length;
    final esMovil = Responsive.isMobile(context);
    final esModoTarjetas = _forzarModoTarjetas ?? esMovil;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Siembra',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: esMovil
            ? [
                // Mobile Sync Button (compact icon button with badge)
                IconButton(
                  tooltip: _sincronizando
                      ? 'Sincronizando...'
                      : (pendientesSync > 0 ? '$pendientesSync pendientes por sincronizar' : 'Sincronizar'),
                  onPressed: _sincronizando ? null : _autoSincronizar,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _sincronizando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, color: Colors.white, size: 24),
                      if (!_sincronizando && pendientesSync > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF9100),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$pendientesSync',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(esModoTarjetas ? Icons.table_chart : Icons.view_agenda, color: Colors.white, size: 22),
                  tooltip: esModoTarjetas ? 'Ver como Tabla' : 'Ver como Tarjetas',
                  onPressed: () {
                    setState(() {
                      _forzarModoTarjetas = !esModoTarjetas;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Más opciones',
                  onSelected: (value) {
                    switch (value) {
                      case 'sync_config':
                        _mostrarSincronizacionDialog();
                        break;
                      case 'seguridad':
                        _mostrarDialogoRespaldoPersistente();
                        break;
                      case 'admin':
                        _abrirAdminVariedades();
                        break;
                      case 'refrescar':
                        _cargarDatos(mostrarNotificacionRespaldo: false);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'sync_config',
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: Color(0xFF558B2F), size: 20),
                          SizedBox(width: 10),
                          Text('Configurar IP / Servidor'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'seguridad',
                      child: Row(
                        children: [
                          Icon(Icons.security, color: Color(0xFF558B2F), size: 20),
                          SizedBox(width: 10),
                          Text('Respaldo Permanente'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'admin',
                      child: Row(
                        children: [
                          Icon(Icons.shield, color: Color(0xFF558B2F), size: 20),
                          SizedBox(width: 10),
                          Text('Panel de Administrador'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refrescar',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Color(0xFF558B2F), size: 20),
                          SizedBox(width: 10),
                          Text('Refrescar Datos'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  icon: Icon(esModoTarjetas ? Icons.table_chart : Icons.view_agenda, color: Colors.white, size: 22),
                  tooltip: esModoTarjetas ? 'Ver como Tabla' : 'Ver como Tarjetas',
                  onPressed: () {
                    setState(() {
                      _forzarModoTarjetas = !esModoTarjetas;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _sincronizando ? null : _autoSincronizar,
                      onLongPress: _mostrarSincronizacionDialog,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _sincronizando
                                ? [const Color(0xFF1976D2), const Color(0xFF0D47A1)]
                                : (pendientesSync > 0
                                    ? [const Color(0xFFFF9100), const Color(0xFFE65100)]
                                    : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: (_sincronizando
                                      ? Colors.blue.shade900
                                      : (pendientesSync > 0 ? Colors.orange.shade900 : Colors.green.shade900))
                                  .withValues(alpha: 0.5),
                              blurRadius: 7,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sincronizando)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                              )
                            else
                              const Icon(Icons.sync, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              _sincronizando
                                  ? 'SINCRONIZANDO...'
                                  : (pendientesSync > 0 ? 'SINCRONIZAR ($pendientesSync)' : 'SINCRONIZAR'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white, size: 22),
                  tooltip: 'Configurar IP y Servidor Backend',
                  onPressed: _mostrarSincronizacionDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.security, color: Colors.white, size: 26),
                  tooltip: 'Almacenamiento Permanente Seguro (Antiapagado)',
                  onPressed: _mostrarDialogoRespaldoPersistente,
                ),
                IconButton(
                  icon: const Icon(Icons.shield, color: Colors.white, size: 26),
                  tooltip: 'Panel de Administrador',
                  onPressed: _abrirAdminVariedades,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
                  tooltip: 'Refrescar Datos',
                  onPressed: () => _cargarDatos(mostrarNotificacionRespaldo: false),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: Column(
        children: [
          // --- BARRA DE FILTROS SEGÚN EL DISPOSITIVO ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: esMovil
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.filter_alt, color: Color(0xFF558B2F), size: 22),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildSelectorFecha(),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF7CB342), width: 1.5),
                              color: Colors.white,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.bar_chart, color: Color(0xFF558B2F), size: 20),
                              tooltip: 'Métricas de Siembra',
                              onPressed: _mostrarMetricasDialog,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF7CB342), width: 1.5),
                              color: Colors.white,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit_note, color: Color(0xFF558B2F), size: 21),
                              tooltip: 'Editar Registros',
                              onPressed: _abrirModalEditarRegistro,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _cultivosConfig.map((cfg) => _buildChipCultivo(cfg, conteoCultivos)).toList(),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.filter_alt, color: Color(0xFF558B2F), size: 24),
                      const SizedBox(width: 8),
                      _buildSelectorFecha(width: 145),
                      const SizedBox(width: 8),
                      Container(width: 1.2, height: 26, color: Colors.grey.shade300),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _cultivosConfig.map((cfg) => _buildChipCultivo(cfg, conteoCultivos)).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF7CB342), width: 1.8),
                          color: Colors.white,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.bar_chart, color: Color(0xFF558B2F), size: 20),
                          tooltip: 'Métricas de Siembra',
                          onPressed: _mostrarMetricasDialog,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _mostrarSincronizacionDialog,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: pendientesSync > 0 ? Colors.orange.shade50 : const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: pendientesSync > 0 ? Colors.orange.shade800 : const Color(0xFF7CB342),
                              width: 1.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pendientesSync > 0 ? Icons.sync_problem : Icons.sync,
                                color: pendientesSync > 0 ? Colors.orange.shade800 : const Color(0xFF33691E),
                                size: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                pendientesSync > 0 ? '$pendientesSync pend.' : 'Sync OK',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: pendientesSync > 0 ? Colors.orange.shade900 : const Color(0xFF33691E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF7CB342), width: 1.8),
                          color: Colors.white,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit_note, color: Color(0xFF558B2F), size: 21),
                          tooltip: 'Editar Registros de Siembra',
                          onPressed: _abrirModalEditarRegistro,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF7CB342), width: 1.8),
                          color: Colors.white,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.security, color: Color(0xFF558B2F), size: 19),
                          tooltip: 'Almacenamiento Permanente Seguro (Antiapagado)',
                          onPressed: _mostrarDialogoRespaldoPersistente,
                        ),
                      ),
                    ],
                  ),
          ),

          // Indicador de filtro activo
          if (_cultivoFiltro != 'TODOS' || _fechaFiltro != null || _semanaFiltro != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFDCEDC8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Color(0xFF33691E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${[
                        if (_cultivoFiltro != 'TODOS') 'Variedad Madre: $_cultivoFiltro',
                        if (_semanaFiltro != null) 'Semana EE. UU.: #$_semanaFiltro ($_anioFiltro)',
                        if (_fechaFiltro != null) 'Fecha: ${_fechaFiltro!.day.toString().padLeft(2, "0")}/${_fechaFiltro!.month.toString().padLeft(2, "0")}/${_fechaFiltro!.year} (Sem. ${CalendarioUtil.obtenerSemanaUS(_fechaFiltro!)})',
                      ].join('  •  ')} (${listaMostrar.length} ${listaMostrar.length == 1 ? "cama" : "camas"})',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _cultivoFiltro = 'TODOS';
                        _fechaFiltro = null;
                        _semanaFiltro = null;
                      });
                    },
                    child: const Text(
                      'Mostrar todas',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),

          // --- VISTA DE SIEMBRAS: TARJETAS (MÓVIL) O TABLA (TABLET / ESCRITORIO) ---
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
                : listaMostrar.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _fechaFiltro != null || _cultivoFiltro != 'TODOS'
                                  ? 'No hay registros con los filtros seleccionados'
                                  : 'No hay siembras registradas aún',
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            if (_fechaFiltro != null || _cultivoFiltro != 'TODOS') ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.filter_alt_off, color: Color(0xFF7CB342)),
                                label: const Text('Limpiar Filtros', style: TextStyle(color: Color(0xFF7CB342))),
                                onPressed: () {
                                  setState(() {
                                    _fechaFiltro = null;
                                    _cultivoFiltro = 'TODOS';
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      )
                    : esModoTarjetas
                        ? ResponsiveContentContainer(
                            maxWidth: 850,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              itemCount: listaMostrar.length,
                              itemBuilder: (context, index) {
                                final s = listaMostrar[index];
                                final op = _operarios.firstWhere(
                                  (o) => o.id == s.operarioId,
                                  orElse: () => Operario(id: 0, cedula: '', nombreCompleto: s.operarioId.toString()),
                                );
                                final va = _variedades.firstWhere(
                                  (v) => v.id == s.variedadId,
                                  orElse: () => Variedad(id: 0, codigo: '', nombre: s.variedadId.toString()),
                                );
                                final ca = _camas.firstWhere(
                                  (c) => c.id == s.camaId,
                                  orElse: () => Cama(id: 0, cama: s.camaId.toString(), bloque: s.bloqueCodigo ?? '', nave: ''),
                                );
                                final isSynced = s.sincronizado == 1;
                                final diasCiclo = _calcularDiasCiclo(s);
                                final esActiva = s.estado == 'ACTIVA';
                                return _buildSiembraCardMobile(s, op, va, ca, diasCiclo, isSynced, esActiva);
                              },
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // Ancho base garantizado para todas las columnas detalladas
                              const double tableMinWidth = 1620.0;
                              final tableWidth = constraints.maxWidth < tableMinWidth ? tableMinWidth : constraints.maxWidth;

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: tableWidth,
                                  child: Column(
                                    children: [
                                      // Encabezados de Tabla exactos del boceto
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        color: const Color(0xFFE8F5E9),
                                        child: const Row(
                                          children: [
                                            _HeaderCol('FECHA', width: 105),
                                            Expanded(flex: 3, child: _HeaderCol('EMPLEADO', width: 0)),
                                            Expanded(flex: 3, child: _HeaderCol('VARIEDAD', width: 0)),
                                            _HeaderCol('BLOQUE', width: 80),
                                            _HeaderCol('CAMA', width: 75),
                                            _HeaderCol('ESQ', width: 90),
                                            _HeaderCol('LINE', width: 70),
                                            _HeaderCol('LOTE', width: 100),
                                            _HeaderCol('PROVEE', width: 100),
                                            _HeaderCol('CONT', width: 90),
                                            Expanded(flex: 3, child: _HeaderCol('CLON / OBS', width: 0)),
                                            _HeaderCol('ESTADO', width: 115),
                                            _HeaderCol('CICLO', width: 90),
                                            _HeaderCol('ACCIÓN', width: 105),
                                            _HeaderCol('SYNC', width: 60),
                                            _HeaderCol('DEL', width: 45),
                                          ],
                                        ),
                                      ),

                                      // Lista de Filas en Tabla
                                      Expanded(
                                        child: ListView.separated(
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: listaMostrar.length,
                                          separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
                                          itemBuilder: (context, index) {
                                        final s = listaMostrar[index];
                                        final op = _operarios.firstWhere(
                                          (o) => o.id == s.operarioId,
                                          orElse: () => Operario(id: 0, cedula: '', nombreCompleto: s.operarioId.toString()),
                                        );
                                        final va = _variedades.firstWhere(
                                          (v) => v.id == s.variedadId,
                                          orElse: () => Variedad(id: 0, codigo: '', nombre: s.variedadId.toString()),
                                        );
                                        final ca = _camas.firstWhere(
                                          (c) => c.id == s.camaId,
                                          orElse: () => Cama(id: 0, cama: s.camaId.toString(), bloque: s.bloqueCodigo ?? '', nave: ''),
                                        );

                                        final isSynced = s.sincronizado == 1;

                                        // Cálculo de días de ciclo
                                        int diasCiclo = 0;
                                        try {
                                          DateTime fInicio = DateTime.now();
                                          if (s.fecha.contains('/')) {
                                            final p = s.fecha.split('/');
                                            fInicio = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                                          } else {
                                            final pIso = DateTime.tryParse(s.fecha);
                                            if (pIso != null) fInicio = pIso;
                                          }
                                          DateTime fFin = DateTime.now();
                                          if (s.estado == 'FINALIZADA' && s.fechaFin != null && s.fechaFin!.isNotEmpty) {
                                            if (s.fechaFin!.contains('/')) {
                                              final p = s.fechaFin!.split('/');
                                              fFin = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                                            } else {
                                              final pIsoFin = DateTime.tryParse(s.fechaFin!);
                                              if (pIsoFin != null) fFin = pIsoFin;
                                            }
                                          }
                                          diasCiclo = fFin.difference(fInicio).inDays;
                                          if (diasCiclo < 0) diasCiclo = 0;
                                        } catch (_) {}

                                        final esActiva = s.estado == 'ACTIVA';

                                        // Campos detallados solicitados en el boceto
                                        final bool esLirioItem = _obtenerCultivoDeSiembra(s) == 'LIRIOS';
                                        final lineasStr = s.lineas != null ? s.lineas.toString() : '-';
                                        final loteStr = (esLirioItem && s.lote != null && s.lote!.isNotEmpty)
                                            ? s.lote!
                                            : '-';
                                        final proveeStr = (esLirioItem && s.proveedor != null && s.proveedor!.isNotEmpty)
                                            ? s.proveedor!
                                            : '-';
                                        final contStr = (esLirioItem && s.cont != null && s.cont!.isNotEmpty)
                                            ? s.cont!
                                            : '-';
                                        final obsesStr = (s.observaciones != null && s.observaciones!.isNotEmpty)
                                            ? s.observaciones!
                                            : '-';

                                        return InkWell(
                                          onTap: () => _mostrarDetalleSiembra(s, op, va, ca, diasCiclo),
                                          child: Container(
                                            color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFCF8),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            child: Row(
                                              children: [
                                                // 1. FECHA CON SEMANA US
                                                () {
                                                  final fSiembra = CalendarioUtil.parsearFecha(s.fecha);
                                                  final semStr = fSiembra != null ? 'Sem. ${CalendarioUtil.obtenerSemanaUS(fSiembra)}' : '';
                                                  return SizedBox(
                                                    width: 105,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(s.fecha, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                        if (semStr.isNotEmpty)
                                                          Text(semStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF558B2F), fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  );
                                                }(),
                                                // 2. EMPLEADO
                                                Expanded(flex: 3, child: _DataCol(op.nombreCompleto, width: 0)),
                                                // 3. VARIEDAD
                                                Expanded(flex: 3, child: _DataCol(va.nombre, width: 0, textColor: const Color(0xFF2E7D32), isBold: true)),
                                                // 4. BLOQUE
                                                _DataCol(s.bloqueCodigo ?? ca.bloque, width: 80),
                                                // 5. CAMA
                                                _DataCol(ca.cama, width: 75),
                                                // 6. ESQ (Esquejes / Tallos)
                                                _DataCol(s.cantidad.toString(), width: 90, isBold: true),
                                                // 7. LINE (Líneas)
                                                _DataCol(lineasStr, width: 70),
                                                // 8. LOTE
                                                _DataCol(loteStr, width: 100),
                                                // 9. PROVEE (Proveedor)
                                                _DataCol(proveeStr, width: 100),
                                                // 10. CONT (Contenedor / Conteo)
                                                _DataCol(contStr, width: 90),
                                                // 11. OBSES (Observaciones)
                                                Expanded(flex: 3, child: _DataCol(obsesStr, width: 0)),
                                                // 12. ESTADO
                                                SizedBox(
                                                  width: 115,
                                                  child: Center(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: esActiva ? Colors.green.shade50 : Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: esActiva ? Colors.green.shade300 : Colors.grey.shade400),
                                                      ),
                                                      child: Text(
                                                        esActiva ? '🟢 ACTIVA' : '⚪ FINALIZADA',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: esActiva ? Colors.green.shade800 : Colors.grey.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // 13. CICLO
                                                SizedBox(
                                                  width: 90,
                                                  child: Center(
                                                    child: Text(
                                                      '$diasCiclo d',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: esActiva ? const Color(0xFF33691E) : Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // 14. ACCIÓN (FINALIZAR CICLO)
                                                SizedBox(
                                                  width: 105,
                                                  child: Center(
                                                    child: esActiva
                                                        ? InkWell(
                                                            onTap: () => _confirmarFinalizarCiclo(s, ca, va),
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF7CB342),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.check, size: 13, color: Colors.white),
                                                                  SizedBox(width: 2),
                                                                  Text('Finalizar', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                        : Text(
                                                            'Cerrado',
                                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                                                          ),
                                                  ),
                                                ),
                                                // 15. SYNC
                                                SizedBox(
                                                  width: 60,
                                                  child: Center(
                                                    child: Icon(
                                                      isSynced ? Icons.check_circle : Icons.cloud_upload_outlined,
                                                      size: 19,
                                                      color: isSynced ? const Color(0xFF7CB342) : Colors.amber.shade800,
                                                    ),
                                                  ),
                                                ),
                                                // 16. ELIMINAR
                                                SizedBox(
                                                  width: 45,
                                                  child: Center(
                                                    child: IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                      tooltip: 'Eliminar Siembra',
                                                      onPressed: () => _confirmarYEliminarSiembra(s),
                                                    ),
                                                  ),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Botón flotante (+) en la esquina inferior derecha
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Colors.white, width: 2.5),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MenuCultivosScreen()),
          );
          _cargarDatos();
        },
        child: const Icon(Icons.add, color: Colors.white, size: 34),
      ),
    );
  }
}

class _HeaderCol extends StatelessWidget {
  final String title;
  final double width;

  const _HeaderCol(this.title, {required this.width});

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      title,
      style: const TextStyle(
        color: Color(0xFF33691E),
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );

    if (width > 0) {
      return SizedBox(
        width: width,
        child: textWidget,
      );
    }
    return textWidget;
  }
}

class _DataCol extends StatelessWidget {
  final String text;
  final double width;
  final bool isBold;
  final Color? textColor;

  const _DataCol(this.text, {required this.width, this.isBold = false, this.textColor});

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: TextStyle(
        color: textColor ?? const Color(0xFF263238),
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );

    if (width > 0) {
      return SizedBox(
        width: width,
        child: textWidget,
      );
    }
    return textWidget;
  }
}

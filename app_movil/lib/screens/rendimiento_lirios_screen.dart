// ============================================================================
// ARCHIVO: rendimiento_lirios_screen.dart
// ¿QUÉ ES ESTA PANTALLA EXPLICADA DE FORMA SENCILLA?
// Imagínate que esta pantalla es LA ALCANCÍA O CUADERNO DE PAGO POR TAREA EN LIRIOS.
//
// En el cultivo de Lirios, los sembradores trabajan en cuadrillas y reciben canastas
// plásticas llenas de bulbos contados (ejemplo: 143 bulbos para Lirio LA, o 63 bulbos para Lirio LO/OT).
//
// ¿QUÉ HACE ESTA PANTALLA?
// 1. EL MARCADOR DE CANASTAS:
//    El supervisor se para al lado de los surcos. Cada vez que Pedro termina una canasta,
//    toca el botón (+1) y de inmediato el sistema le anota esa canasta a Pedro con la hora exacta.
//
// 2. EL PODIO Y LAS MEDALLAS (Oro, Plata y Bronce):
//    Muestra en vivo quién es el sembrador más rápido del día, para motivar al equipo
//    y reconocer su esfuerzo.
//
// 3. LA LIQUIDACIÓN EXACTA:
//    Multiplica las canastas por la cantidad de bulbos y entrega el número total de plantas
//    que sembró cada persona para pasar la cuenta de cobro a la oficina sin errores.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:app_movil/utils/responsive.dart';

class RendimientoLiriosScreen extends StatefulWidget {
  final String subgrupoInicial; // 'LA', 'LO', 'OT', o 'Lirio LA'

  const RendimientoLiriosScreen({
    super.key,
    this.subgrupoInicial = 'LA',
  });

  @override
  State<RendimientoLiriosScreen> createState() => _RendimientoLiriosScreenState();
}

class _RendimientoLiriosScreenState extends State<RendimientoLiriosScreen>
    with SingleTickerProviderStateMixin {
  final DbRepository _db = DbRepository();
  final NumberFormat _fmt = NumberFormat('#,###', 'es_CO');
  final Uuid _uuidGenerator = const Uuid();

  late TabController _tabController;
  late DateTime _fechaSeleccionada;
  String _filtroTexto = '';
  bool _cargando = true;

  List<Operario> _todosLosOperarios = [];
  List<CanastaLirio> _canastasDelDia = [];

  // Subgrupos disponibles
  final List<String> _codigosSubgrupos = ['LA', 'LO', 'OT'];
  final Map<String, String> _nombresSubgrupos = {
    'LA': 'Lirio LA',
    'LO': 'Lirio LO',
    'OT': 'Lirio OT',
  };

  // Densidades oficiales por parrilla y canasta
  final Map<String, int> _densidadesParrilla = {
    'LA': 143,
    'LO': 63,
    'OT': 63,
  };

  final Map<String, List<int>> _canastasOpciones = {
    'LA': [400, 425, 450],
    'LO': [200, 225, 250],
    'OT': [200, 225, 250],
  };

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = DateTime.now();

    // Deducir índice de subgrupo inicial
    int idxInicial = 0;
    final subUpper = widget.subgrupoInicial.toUpperCase();
    if (subUpper.contains('LO')) {
      idxInicial = 1;
    } else if (subUpper.contains('OT')) {
      idxInicial = 2;
    } else {
      idxInicial = 0; // LA
    }

    _tabController = TabController(
      length: _codigosSubgrupos.length,
      vsync: this,
      initialIndex: idxInicial,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _fechaStr {
    return "${_fechaSeleccionada.day.toString().padLeft(2, '0')}/${_fechaSeleccionada.month.toString().padLeft(2, '0')}/${_fechaSeleccionada.year}";
  }

  String get _subgrupoActual => _codigosSubgrupos[_tabController.index];

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final ops = await _db.obtenerOperarios();
    final canastas = await _db.obtenerCanastasLirios(fecha: _fechaStr);

    if (!mounted) return;
    setState(() {
      _todosLosOperarios = ops;
      _canastasDelDia = canastas;
      _cargando = false;
    });
  }

  Future<void> _cambiarFecha(DateTime nuevaFecha) async {
    setState(() => _fechaSeleccionada = nuevaFecha);
    await _cargarDatos();
  }

  Future<void> _seleccionarFechaDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF33691E),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await _cambiarFecha(picked);
    }
  }

  Future<void> _entregarCanasta(Operario op, int cantidadBulbos, {String? obs}) async {
    final hora = DateFormat('hh:mm a').format(DateTime.now());
    final nueva = CanastaLirio(
      uuid: _uuidGenerator.v4(),
      fecha: _fechaStr,
      subgrupo: _subgrupoActual,
      operarioId: op.id,
      operarioNombre: op.nombreCompleto,
      cantidadBulbos: cantidadBulbos,
      hora: hora,
      sincronizado: 0,
      observaciones: obs,
    );

    await _db.registrarCanastaLirios(nueva);
    await _cargarDatos();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '✓ Canasta de $cantidadBulbos bulbos entregada a ${op.nombreCompleto} ($hora)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarCanasta(CanastaLirio canasta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Eliminar Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '¿Desea eliminar la entrega de ${canasta.cantidadBulbos} bulbos de las ${canasta.hora} para ${canasta.operarioNombre}?',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && canasta.id != null) {
      await _db.eliminarCanastaLirios(canasta.id!);
      await _cargarDatos();
    }
  }

  void _abrirModalEntregaCanasta(Operario op) {
    final sub = _subgrupoActual;
    final opciones = _canastasOpciones[sub] ?? [400, 425, 450];
    final densParrilla = _densidadesParrilla[sub] ?? 143;
    final TextEditingController customController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CB342).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.all_inbox, color: Color(0xFF2E7D32), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entregar Canasta a Sembrador',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          Text(
                            op.nombreCompleto,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33691E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LIRIO $sub',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF33691E), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cada que el operario finalice una canasta, solicite otra. Densidad de parrilla: $densParrilla bulbos.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF33691E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SELECCIONE LA CANTIDAD DE BULBOS:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF558B2F),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Botones táctiles grandes para cada cantidad oficial
                Row(
                  children: opciones.map((cant) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7CB342),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _entregarCanasta(op, cant);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_basket_rounded, size: 24, color: Colors.white),
                              const SizedBox(height: 6),
                              Text(
                                '$cant',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'bulbos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Opción para cantidad personalizada si una canasta vino diferente
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Otra cantidad de canasta...',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ej: 380 bulbos',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF33691E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final c = int.tryParse(customController.text.trim());
                            if (c != null && c > 0) {
                              Navigator.pop(ctx);
                              _entregarCanasta(op, c);
                            }
                          },
                          child: const Text('Registrar'),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final esMovil = Responsive.isMobile(context);
    final sub = _subgrupoActual;
    final canastasGrupo = _canastasDelDia.where((c) => c.subgrupo == sub).toList();

    // Mapeo de canastas por operario
    final Map<int, List<CanastaLirio>> canastasPorOp = {};
    for (var c in canastasGrupo) {
      canastasPorOp.putIfAbsent(c.operarioId, () => []).add(c);
    }

    // Filtrar operarios
    List<Operario> operariosFiltrados = _todosLosOperarios;
    if (_filtroTexto.trim().isNotEmpty) {
      final q = _filtroTexto.toLowerCase();
      operariosFiltrados = operariosFiltrados.where((o) {
        return o.nombreCompleto.toLowerCase().contains(q) || o.cedula.contains(q);
      }).toList();
    }

    // Ordenar: primero los que tienen entregas hoy (mayor a menor bulbos), luego por nombre
    operariosFiltrados.sort((a, b) {
      final bulbosA = (canastasPorOp[a.id] ?? []).fold<int>(0, (s, c) => s + c.cantidadBulbos);
      final bulbosB = (canastasPorOp[b.id] ?? []).fold<int>(0, (s, c) => s + c.cantidadBulbos);
      if (bulbosA != bulbosB) {
        return bulbosB.compareTo(bulbosA);
      }
      return a.nombreCompleto.compareTo(b.nombreCompleto);
    });

    final totalCanastas = canastasGrupo.length;
    final totalBulbos = canastasGrupo.fold<int>(0, (s, c) => s + c.cantidadBulbos);
    final totalOpsActivos = canastasPorOp.keys.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'RENDIMIENTOS LIRIOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.5,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 24),
              tooltip: 'Volver al Inicio',
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'LA (143 b/p)', icon: Icon(Icons.spa, size: 18)),
            Tab(text: 'LO (63 b/p)', icon: Icon(Icons.local_florist, size: 18)),
            Tab(text: 'OT (63 b/p)', icon: Icon(Icons.filter_vintage, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
            : ResponsiveContentContainer(
                maxWidth: 960,
                padding: EdgeInsets.symmetric(
                  horizontal: esMovil ? 12 : 20,
                  vertical: 8,
                ),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    // Selector de Fecha
                    _buildSelectorFecha(esMovil),
                    const SizedBox(height: 10),

                    // Tarjeta de KPIs del Subgrupo
                    _buildKpiCard(
                      subgrupo: sub,
                      totalCanastas: totalCanastas,
                      totalBulbos: totalBulbos,
                      totalOpsActivos: totalOpsActivos,
                      esMovil: esMovil,
                    ),
                    const SizedBox(height: 10),

                    // Barra de búsqueda de operarios
                    _buildBarraBusqueda(),
                    const SizedBox(height: 12),

                    // Encabezado de la lista
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EMPLEADOS (${operariosFiltrados.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF33691E),
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_filtroTexto.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => setState(() => _filtroTexto = ''),
                            child: const Text('Limpiar filtro', style: TextStyle(fontSize: 11, color: Color(0xFF558B2F))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lista de Operarios
                    if (operariosFiltrados.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            _filtroTexto.isNotEmpty
                                ? 'No se encontraron operarios para "$_filtroTexto"'
                                : 'No hay operarios registrados en la base de datos',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ...operariosFiltrados.asMap().entries.map((entry) {
                        final i = entry.key;
                        final op = entry.value;
                        final canastasOp = canastasPorOp[op.id] ?? [];
                        final int totalBulbosOp = canastasOp.fold<int>(0, (s, c) => s + c.cantidadBulbos);
                        final int totalCanastasOp = canastasOp.length;
                        final bool tieneEntregas = totalCanastasOp > 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildOperarioCard(
                            op: op,
                            canastas: canastasOp,
                            totalCanastas: totalCanastasOp,
                            totalBulbos: totalBulbosOp,
                            tieneEntregas: tieneEntregas,
                            posicion: i + 1,
                            esMovil: esMovil,
                          ),
                        );
                      }),

                    // Espaciado final para asegurar scroll completo
                    const SizedBox(height: 70),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSelectorFecha(bool esMovil) {
    final sem = CalendarioUtil.obtenerEtiquetaCorta(_fechaSeleccionada);
    final esHoy = _fechaStr == DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF33691E)),
            tooltip: 'Día anterior',
            onPressed: () => _cambiarFecha(_fechaSeleccionada.subtract(const Duration(days: 1))),
          ),
          Flexible(
            child: InkWell(
              onTap: _seleccionarFechaDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF7CB342), size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$_fechaStr ($sem)${esHoy ? " • HOY" : ""}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: esMovil ? 13 : 15,
                          color: const Color(0xFF1B5E20),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              if (!esHoy)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: const Color(0xFF33691E),
                  ),
                  onPressed: () => _cambiarFecha(DateTime.now()),
                  child: const Text('Ir a Hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF33691E)),
                tooltip: 'Día siguiente',
                onPressed: () => _cambiarFecha(_fechaSeleccionada.add(const Duration(days: 1))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String subgrupo,
    required int totalCanastas,
    required int totalBulbos,
    required int totalOpsActivos,
    required bool esMovil,
  }) {
    final dens = _densidadesParrilla[subgrupo] ?? 143;
    final opciones = (_canastasOpciones[subgrupo] ?? []).join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF33691E), Color(0xFF558B2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESUMEN ${_nombresSubgrupos[subgrupo]!.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Densidad: $dens b/parrilla',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📦 Canastas estándar para este grupo: $opciones bulbos',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            children: [
              Expanded(
                child: _buildKpiItem(
                  icon: Icons.all_inbox,
                  label: 'Canastas',
                  valor: '$totalCanastas',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _buildKpiItem(
                  icon: Icons.spa,
                  label: 'Bulbos',
                  valor: _fmt.format(totalBulbos),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _buildKpiItem(
                  icon: Icons.people,
                  label: 'Sembradores',
                  valor: '$totalOpsActivos',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem({required IconData icon, required String label, required String valor}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBarraBusqueda() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar empleado por nombre o cédula...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7CB342)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7CB342), width: 2),
        ),
      ),
      onChanged: (val) => setState(() => _filtroTexto = val),
    );
  }

  Widget _buildOperarioCard({
    required Operario op,
    required List<CanastaLirio> canastas,
    required int totalCanastas,
    required int totalBulbos,
    required bool tieneEntregas,
    required int posicion,
    required bool esMovil,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tieneEntregas ? const Color(0xFF81C784) : Colors.grey.shade300,
          width: tieneEntregas ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge de ranking si tiene entregas
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tieneEntregas
                      ? (posicion == 1
                          ? const Color(0xFFFFF9C4)
                          : (posicion == 2
                              ? const Color(0xFFECEFF1)
                              : (posicion == 3 ? const Color(0xFFEFEBE9) : const Color(0xFFE8F5E9))))
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tieneEntregas
                        ? (posicion == 1
                            ? const Color(0xFFFBC02D)
                            : (posicion == 2
                                ? Colors.blueGrey
                                : (posicion == 3 ? Colors.brown : const Color(0xFF66BB6A))))
                        : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  tieneEntregas
                      ? (posicion == 1 ? '🥇' : (posicion == 2 ? '🥈' : (posicion == 3 ? '🥉' : '#$posicion')))
                      : '#$posicion',
                  style: TextStyle(
                    fontSize: (posicion <= 3 && tieneEntregas) ? 14 : 11,
                    fontWeight: FontWeight.bold,
                    color: tieneEntregas ? const Color(0xFF2E7D32) : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.nombreCompleto,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF263238),
                      ),
                    ),
                    Text(
                      'Cédula: ${op.cedula.isNotEmpty ? op.cedula : "S/C"}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Botón rápido para entregar canasta
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7CB342),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: esMovil ? 10 : 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text(
                  '+ Canasta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _abrirModalEntregaCanasta(op),
              ),
            ],
          ),

          // Resumen de entregas hoy
          if (tieneEntregas) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.all_inbox, size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        'Total: $totalCanastas canastas',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                  Text(
                    '${_fmt.format(totalBulbos)} bulbos sembrados',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1B5E20)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Chips de cada canasta entregada
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: canastas.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final c = entry.value;
                return Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.green.shade300),
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xFF7CB342),
                    radius: 9,
                    child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  label: Text(
                    '${c.cantidadBulbos} b (${c.hora})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.red),
                  onDeleted: () => _confirmarEliminarCanasta(c),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Sin canastas entregadas hoy para este grupo.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

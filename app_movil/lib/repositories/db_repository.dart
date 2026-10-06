import 'package:app_movil/database/local_db.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/services/persistent_backup_service.dart';
import 'package:app_movil/utils/calendario_util.dart';
import 'package:sqflite/sqflite.dart';

/// Excepción lanzada cuando una operación viola las restricciones agronómicas de densidad o ciclos
class AgronomicValidationException implements Exception {
  final String message;
  AgronomicValidationException(this.message);

  @override
  String toString() => message;
}

/// Resultado de la validación estricta de ciclos agronómicos y disponibilidad de cama
class ValidacionCicloResultado {
  final bool esValido;
  final bool esCicloActivo; // La cama ya tiene una siembra ACTIVA
  final bool esCicloIncompleto; // La cama tuvo una siembra que no ha cumplido los días mínimos requeridos
  final bool esCamaLlena; // La cama alcanzó el 100% de su capacidad agronómica
  final bool esCamaCompartida; // La cama tiene siembras activas pero aún tiene cupo disponible
  final String mensaje;
  final Siembra? siembraPrevia;
  final List<Siembra> siembrasActivas;
  final String? variedadPreviaNombre;
  final List<String> variedadesPresentes;
  final List<String> operariosPresentes;
  final int cantidadOcupada;
  final int limiteMaximo;
  final int cupoDisponible;
  final int diasTranscurridos;
  final int diasRequeridos;
  final int diasFaltantes;
  final DateTime? fechaMinimaPermitida;

  ValidacionCicloResultado({
    required this.esValido,
    this.esCicloActivo = false,
    this.esCicloIncompleto = false,
    this.esCamaLlena = false,
    this.esCamaCompartida = false,
    required this.mensaje,
    this.siembraPrevia,
    this.siembrasActivas = const [],
    this.variedadPreviaNombre,
    this.variedadesPresentes = const [],
    this.operariosPresentes = const [],
    this.cantidadOcupada = 0,
    this.limiteMaximo = 3600,
    this.cupoDisponible = 3600,
    this.diasTranscurridos = 0,
    this.diasRequeridos = 0,
    this.diasFaltantes = 0,
    this.fechaMinimaPermitida,
  });
}

/// Helper para convertir fechas DD/MM/AAAA o ISO a DateTime de forma segura
DateTime? parsearFechaSiembra(String? fStr) {
  if (fStr == null || fStr.trim().isEmpty) return null;
  final clean = fStr.trim();
  if (clean.contains('/')) {
    final parts = clean.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }
  }
  return DateTime.tryParse(clean);
}

class DbRepository {
  // === MÉTODOS PARA CATÁLOGOS (Sync hacia la app) ===

  Future<void> reemplazarBloques(List<Bloque> bloques) async {
    final db = await LocalDatabase.instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final batch = db.batch();
      for (var b in bloques) {
        batch.insert('tb_bloques', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> reemplazarVariedades(List<Variedad> variedades) async {
    final db = await LocalDatabase.instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final batch = db.batch();
      for (var v in variedades) {
        final map = v.toMap();
        map['es_temporal'] = 0; // Las variedades del backend Access son oficiales
        batch.insert('tb_variedades', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
    // Sincronizar y reconciliar automáticamente variedades temporales con las oficiales recién insertadas
    await reconciliarVariedadesTemporales();
  }

  Future<void> reemplazarCamas(List<Cama> camas) async {
    final db = await LocalDatabase.instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final batch = db.batch();
      for (var c in camas) {
        batch.insert('tb_camas', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> reemplazarOperarios(List<Operario> operarios) async {
    final db = await LocalDatabase.instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final batch = db.batch();
      for (var o in operarios) {
        batch.insert('tb_operarios', o.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // === CONFIGURACIÓN AGRONÓMICA INDEPENDIENTE (ADMINISTRADOR) ===

  /// Obtiene los límites y días de ciclo configurados por el Administrador
  Future<ConfigAgronomica> obtenerConfigAgronomica({String? cultivo}) async {
    final db = await LocalDatabase.instance.database;
    String cName = (cultivo ?? 'GENERAL').trim().toUpperCase();

    // Normalización de sinónimos agronómicos de cultivo
    if (cName.contains(' LA') || cName == 'LA' || cName.contains('ASIAT')) {
      cName = 'LA';
    } else if (cName.contains(' LO') || cName == 'LO' || cName.contains('ORIENT')) {
      cName = 'LO';
    } else if (cName.contains(' OT') || cName == 'OT') {
      cName = 'OT';
    } else if (cName.contains('LIRIO')) {
      cName = 'LIRIOS';
    } else if (cName.contains('CRISAN') || cName.contains('POMP')) {
      cName = 'POMPON';
    } else if (cName.contains('CREM') || cName.contains('FUJI') || cName.contains('DISBUD')) {
      cName = 'CREMON';
    } else if (cName.contains('GIRAS') || cName.contains('SUNF')) {
      cName = 'GIRASOL';
    } else if (cName.contains('MATSU') || cName.contains('ASTER')) {
      cName = 'MATSUMOTO';
    } else if (cName.contains('GERB')) {
      cName = 'GERBERA';
    } else if (cName.contains('ALSTRO')) {
      cName = 'ALSTROEMERIA';
    }

    // 1. Intentar buscar por el nombre específico normalizado
    var result = await db.query(
      'tb_config_agronomica',
      where: 'cultivo = ?',
      whereArgs: [cName],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return ConfigAgronomica.fromMap(result.first);
    }

    // 2. Si no existe específico, buscar por coincidencia parcial
    final all = await db.query('tb_config_agronomica');
    for (var r in all) {
      final key = r['cultivo'].toString().toUpperCase();
      if (cName.contains(key) || key.contains(cName)) {
        return ConfigAgronomica.fromMap(r);
      }
    }

    // 3. Fallback a GENERAL
    final general = await db.query(
      'tb_config_agronomica',
      where: "cultivo = 'GENERAL'",
      limit: 1,
    );
    if (general.isNotEmpty) {
      return ConfigAgronomica.fromMap(general.first);
    }

    return ConfigAgronomica(cultivo: 'GENERAL', limiteEsquejes: 3600, diasCiclo: 75, densidadLinea: 20);
  }

  /// Obtiene los parámetros agronómicos precisos para una variedad específica.
  /// Prioriza los valores individuales de la variedad (si están definidos y > 0)
  /// y de lo contrario utiliza los valores de la configuración agronómica del cultivo.
  Future<ConfigAgronomica> obtenerConfigAgronomicaParaVariedad(
    Variedad? variedad, {
    String? cultivoFallback,
  }) async {
    String? cultivoDeducido = cultivoFallback;
    if (variedad != null) {
      final fam = (variedad.familiaNombre ?? '').toUpperCase();
      final nom = variedad.nombre.toUpperCase();

      if (fam.contains('LIRIO') || nom.contains('LIRIO') || fam.contains('LONGIFLORUM') || fam.contains('ASIATICO') || fam.contains('ORIENTAL') || nom.contains('LA') || nom.contains('LO') || nom.contains('OT')) {
        if (fam.contains('ORIENTAL') || nom.contains('ORIENTAL') || fam.contains(' LO') || nom.contains(' LO')) {
          cultivoDeducido = 'LO';
        } else if (fam.contains(' OT') || nom.contains(' OT')) {
          cultivoDeducido = 'OT';
        } else if (fam.contains('LA') || nom.contains('LA') || fam.contains('ASIAT')) {
          cultivoDeducido = 'LA';
        } else {
          cultivoDeducido = 'LIRIOS';
        }
      } else if (fam.contains('CREMON') || nom.contains('CREMON') || fam.contains('FUJI') || fam.contains('DISBUD')) {
        cultivoDeducido = 'CREMON';
      } else if (fam.contains('POMPON') || nom.contains('POMPON') || fam.contains('CRISANTEMO')) {
        cultivoDeducido = 'POMPON';
      } else if (fam.contains('GIRASOL') || nom.contains('GIRASOL') || fam.contains('SUNFLOWER')) {
        cultivoDeducido = 'GIRASOL';
      } else if (fam.contains('MATSUMOTO') || nom.contains('MATSUMOTO') || fam.contains('ASTER')) {
        cultivoDeducido = 'MATSUMOTO';
      } else if (fam.contains('GERBERA') || nom.contains('GERBERA')) {
        cultivoDeducido = 'GERBERA';
      } else if (fam.contains('ALSTROEMERIA') || nom.contains('ALSTROEMERIA')) {
        cultivoDeducido = 'ALSTROEMERIA';
      } else if (fam.contains('BANCO') || nom.contains('BANCO')) {
        cultivoDeducido = 'BANCOS';
      } else if (fam.contains('NUCLEO') || nom.contains('NUCLEO')) {
        cultivoDeducido = 'NUCLEOS';
      }
    }

    final baseConfig = await obtenerConfigAgronomica(cultivo: cultivoDeducido);

    final int limiteFinal = (variedad != null && variedad.limiteEsquejes != null && variedad.limiteEsquejes! > 0)
        ? variedad.limiteEsquejes!
        : baseConfig.limiteEsquejes;

    final int diasFinal = (variedad != null && variedad.diasCiclo != null && variedad.diasCiclo! > 0)
        ? variedad.diasCiclo!
        : baseConfig.diasCiclo;

    final int densidadFinal = (variedad != null && variedad.densidadLinea != null && variedad.densidadLinea! > 0)
        ? variedad.densidadLinea!
        : baseConfig.densidadLinea;

    return ConfigAgronomica(
      cultivo: variedad?.nombre ?? baseConfig.cultivo,
      limiteEsquejes: limiteFinal,
      diasCiclo: diasFinal,
      densidadLinea: densidadFinal,
    );
  }

  Future<List<ConfigAgronomica>> obtenerTodasLasConfigsAgronomicas() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_config_agronomica', orderBy: 'cultivo ASC');
    return result.map((m) => ConfigAgronomica.fromMap(m)).toList();
  }

  Future<void> guardarConfigAgronomica(ConfigAgronomica config) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'tb_config_agronomica',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // === LECTURA LOCAL (Para pintar el UI) ===

  Future<List<Bloque>> obtenerBloques() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_bloques', orderBy: 'codigo ASC');
    return result.map((json) => Bloque.fromMap(json)).toList();
  }

  Future<List<Variedad>> obtenerVariedades({bool soloActivas = true}) async {
    final db = await LocalDatabase.instance.database;
    final result = soloActivas
        ? await db.query('tb_variedades', where: 'estado = ?', whereArgs: [1], orderBy: 'nombre ASC')
        : await db.query('tb_variedades', orderBy: 'nombre ASC');
    return result.map((json) => Variedad.fromMap(json)).toList();
  }

  Future<List<Variedad>> obtenerVariedadesPorFamilia(List<int> familiaIds, {bool soloActivas = true, bool incluirTemporales = true}) async {
    final db = await LocalDatabase.instance.database;
    if (familiaIds.isEmpty) {
      return obtenerVariedades(soloActivas: soloActivas);
    }
    final placeholders = List.filled(familiaIds.length, '?').join(',');
    final whereArgs = [...familiaIds];
    String whereClause = '(familia_id IN ($placeholders)';
    if (incluirTemporales) {
      whereClause += ' OR es_temporal = 1 OR id < 0)';
    } else {
      whereClause += ')';
    }
    if (soloActivas) {
      whereClause += ' AND estado = 1';
    }
    final result = await db.query(
      'tb_variedades',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
    );
    if (result.isEmpty) {
      return obtenerVariedades(soloActivas: soloActivas);
    }
    return result.map((json) => Variedad.fromMap(json)).toList();
  }

  Future<Variedad?> obtenerVariedadPorId(int id) async {
    final db = await LocalDatabase.instance.database;
    final res = await db.query('tb_variedades', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return Variedad.fromMap(res.first);
  }

  /// Registra una nueva variedad temporal en SQLite para permitir la captura inmediata de siembras
  /// y rendimientos de cortadores/sembradores mientras se oficializa en la base de datos empresarial.
  Future<Variedad> crearVariedadTemporal({
    required String nombre,
    String? codigo,
    required int familiaId,
    String? familiaNombre,
    String? color,
    String? colorNombre,
    int? limiteEsquejes,
    int? diasCiclo,
    int? densidadLinea,
  }) async {
    final db = await LocalDatabase.instance.database;

    // Generar un ID negativo único para evitar cualquier colisión con IDs de Access
    final minRes = await db.rawQuery('SELECT MIN(id) as min_id FROM tb_variedades WHERE id < 0');
    int nextTempId = -1;
    if (minRes.isNotEmpty && minRes.first['min_id'] != null) {
      final currentMin = minRes.first['min_id'] as int;
      nextTempId = currentMin - 1;
    }

    final String finalCod = (codigo != null && codigo.trim().isNotEmpty)
        ? codigo.trim().toUpperCase()
        : 'TEMP-${DateTime.now().millisecondsSinceEpoch % 10000}';

    final nueva = Variedad(
      id: nextTempId,
      codigo: finalCod,
      nombre: nombre.trim().toUpperCase(),
      estado: 1,
      familiaId: familiaId,
      familiaNombre: familiaNombre ?? 'GENERAL',
      color: color,
      colorNombre: colorNombre,
      subvarNombre: 'VARIEDAD TEMPORAL / PRUEBA',
      limiteEsquejes: limiteEsquejes,
      diasCiclo: diasCiclo,
      densidadLinea: densidadLinea,
      esTemporal: true,
    );

    await db.insert(
      'tb_variedades',
      nueva.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return nueva;
  }

  /// Obtiene la lista de variedades temporales creadas en SQLite
  Future<List<Variedad>> obtenerVariedadesTemporales() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query(
      'tb_variedades',
      where: 'es_temporal = 1 OR id < 0',
      orderBy: 'nombre ASC',
    );
    return result.map((json) => Variedad.fromMap(json)).toList();
  }

  /// Obtiene la lista de variedades temporales junto con el número de siembras asociadas
  Future<List<Map<String, dynamic>>> obtenerVariedadesTemporalesConConteo() async {
    final db = await LocalDatabase.instance.database;
    final temps = await db.query(
      'tb_variedades',
      where: 'es_temporal = 1 OR id < 0',
      orderBy: 'nombre ASC',
    );

    final List<Map<String, dynamic>> resultado = [];
    for (var t in temps) {
      final id = t['id'] as int;
      final cRes = await db.rawQuery('SELECT COUNT(*) as total FROM tb_siembras WHERE variedad_id = ?', [id]);
      final count = Sqflite.firstIntValue(cRes) ?? 0;
      resultado.add({
        'variedad': Variedad.fromMap(t),
        'total_siembras': count,
      });
    }
    return resultado;
  }

  /// Cuenta el número de siembras asociadas a una variedad
  Future<int> contarSiembrasPorVariedad(int variedadId) async {
    final db = await LocalDatabase.instance.database;
    final cRes = await db.rawQuery('SELECT COUNT(*) as total FROM tb_siembras WHERE variedad_id = ?', [variedadId]);
    return Sqflite.firstIntValue(cRes) ?? 0;
  }

  /// Elimina una variedad temporal creada en SQLite.
  /// Si tiene siembras asociadas y [eliminarSiembrasAsociadas] es true,
  /// también elimina esas siembras locales.
  /// Si [eliminarSiembrasAsociadas] es false y tiene siembras, arroja una excepción.
  Future<int> eliminarVariedadTemporal(int variedadId, {bool eliminarSiembrasAsociadas = false}) async {
    final db = await LocalDatabase.instance.database;

    final check = await db.query(
      'tb_variedades',
      where: 'id = ? AND (es_temporal = 1 OR id < 0)',
      whereArgs: [variedadId],
    );
    if (check.isEmpty) {
      throw Exception('Solo se pueden eliminar variedades temporales o de prueba creadas localmente.');
    }

    final totalSiembras = await contarSiembrasPorVariedad(variedadId);

    if (totalSiembras > 0 && !eliminarSiembrasAsociadas) {
      throw Exception('La variedad tiene $totalSiembras siembra(s) asociada(s).');
    }

    return await db.transaction((txn) async {
      if (totalSiembras > 0 && eliminarSiembrasAsociadas) {
        await txn.delete(
          'tb_siembras',
          where: 'variedad_id = ?',
          whereArgs: [variedadId],
        );
      }
      return await txn.delete(
        'tb_variedades',
        where: 'id = ?',
        whereArgs: [variedadId],
      );
    });
  }

  /// Sincroniza y reconcilia automáticamente las variedades temporales creadas en la app
  /// con las variedades reales recién descargadas de la base de datos empresarial (Access).
  /// Si encuentra una variedad en Access con el mismo nombre (o código), actualiza
  /// todas las siembras en SQLite que tenían el ID temporal para usar el ID real de Access.
  Future<int> reconciliarVariedadesTemporales() async {
    final db = await LocalDatabase.instance.database;
    final temps = await db.query(
      'tb_variedades',
      where: 'es_temporal = 1 OR id < 0',
    );
    if (temps.isEmpty) return 0;

    int totalReconciliadas = 0;

    for (var tMap in temps) {
      final tempId = tMap['id'] as int;
      final tempNombre = (tMap['nombre'] as String? ?? '').trim().toUpperCase();
      final tempCodigo = (tMap['codigo'] as String? ?? '').trim().toUpperCase();

      if (tempNombre.isEmpty) continue;

      // Buscar si ya existe una variedad oficial de Access (id > 0 y es_temporal = 0)
      List<Map<String, dynamic>> matches = [];
      if (tempCodigo.isNotEmpty && tempCodigo != '00' && !tempCodigo.startsWith('TEMP')) {
        matches = await db.query(
          'tb_variedades',
          where: '(id > 0 AND (es_temporal IS NULL OR es_temporal = 0)) AND (UPPER(TRIM(nombre)) = ? OR UPPER(TRIM(codigo)) = ?)',
          whereArgs: [tempNombre, tempCodigo],
          limit: 1,
        );
      } else {
        matches = await db.query(
          'tb_variedades',
          where: '(id > 0 AND (es_temporal IS NULL OR es_temporal = 0)) AND UPPER(TRIM(nombre)) = ?',
          whereArgs: [tempNombre],
          limit: 1,
        );
      }

      if (matches.isNotEmpty) {
        final realId = matches.first['id'] as int;

        // Migrar todas las siembras asociadas al ID temporal
        await db.update(
          'tb_siembras',
          {'variedad_id': realId},
          where: 'variedad_id = ?',
          whereArgs: [tempId],
        );

        // Actualizar camas que apunten a este ID
        await db.update(
          'tb_camas',
          {'referencia_actual_id': realId},
          where: 'referencia_actual_id = ?',
          whereArgs: [tempId],
        );

        // Eliminar la variedad temporal de SQLite porque ya existe la oficial de Access
        await db.delete(
          'tb_variedades',
          where: 'id = ?',
          whereArgs: [tempId],
        );

        totalReconciliadas++;
      }
    }

    return totalReconciliadas;
  }

  /// Vincula manualmente una variedad temporal con una variedad real de Access seleccionada por el usuario
  Future<int> vincularVariedadTemporalManual({
    required int tempVariedadId,
    required int realVariedadId,
  }) async {
    final db = await LocalDatabase.instance.database;
    final count = await db.update(
      'tb_siembras',
      {'variedad_id': realVariedadId},
      where: 'variedad_id = ?',
      whereArgs: [tempVariedadId],
    );

    await db.update(
      'tb_camas',
      {'referencia_actual_id': realVariedadId},
      where: 'referencia_actual_id = ?',
      whereArgs: [tempVariedadId],
    );

    await db.delete(
      'tb_variedades',
      where: 'id = ?',
      whereArgs: [tempVariedadId],
    );

    return count;
  }

  Future<void> guardarVariedadLocal(Variedad variedad) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'tb_variedades',
      variedad.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Actualiza la densidad de plantas (límite y factor por línea) para una variedad específica
  Future<void> actualizarDensidadVariedad(int variedadId, int nuevoLimite, {int? nuevaDensidadLinea}) async {
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> data = {'limite_esquejes': nuevoLimite};
    if (nuevaDensidadLinea != null && nuevaDensidadLinea > 0) {
      data['densidad_linea'] = nuevaDensidadLinea;
    }
    await db.update(
      'tb_variedades',
      data,
      where: 'id = ?',
      whereArgs: [variedadId],
    );
  }

  /// Actualiza específicamente el factor de densidad por línea para una variedad
  Future<void> actualizarDensidadLineaVariedad(int variedadId, int nuevaDensidadLinea) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'tb_variedades',
      {'densidad_linea': nuevaDensidadLinea},
      where: 'id = ?',
      whereArgs: [variedadId],
    );
  }

  /// Actualiza la duración del ciclo agronómico en días para una variedad específica
  Future<void> actualizarCicloVariedad(int variedadId, int nuevosDias) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'tb_variedades',
      {'dias_ciclo': nuevosDias},
      where: 'id = ?',
      whereArgs: [variedadId],
    );
  }

  Future<List<Cama>> obtenerCamas() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_camas', orderBy: 'bloque ASC, cama ASC');
    return result.map((json) => Cama.fromMap(json)).toList();
  }

  Future<List<Cama>> obtenerCamasPorBloque(String bloqueCodigo) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query(
      'tb_camas',
      where: 'bloque = ?',
      whereArgs: [bloqueCodigo],
      orderBy: 'cama ASC',
    );
    return result.map((json) => Cama.fromMap(json)).toList();
  }

  /// Retorna los IDs de las camas que tienen su capacidad 100% llena en el ciclo activo
  Future<Set<int>> obtenerIdsCamasOcupadas({String? bloqueCodigo}) async {
    final db = await LocalDatabase.instance.database;
    String whereClause = "estado = 'ACTIVA'";
    List<dynamic> whereArgs = [];
    if (bloqueCodigo != null && bloqueCodigo.isNotEmpty) {
      whereClause += ' AND bloque_codigo = ?';
      whereArgs.add(bloqueCodigo);
    }
    final siembras = await db.query(
      'tb_siembras',
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (siembras.isEmpty) return {};

    // Agrupar siembras por cama_id y acumular cantidades
    final Map<int, int> cantidadPorCama = {};
    final Map<int, List<int>> variedadesPorCama = {};
    for (final s in siembras) {
      final camaId = s['cama_id'] as int;
      final cant = s['cantidad'] as int? ?? 0;
      final varId = s['variedad_id'] as int;
      cantidadPorCama[camaId] = (cantidadPorCama[camaId] ?? 0) + cant;
      variedadesPorCama.putIfAbsent(camaId, () => []).add(varId);
    }

    final Set<int> camasLlenas = {};
    for (final entry in cantidadPorCama.entries) {
      final camaId = entry.key;
      final totalCant = entry.value;
      final varIds = variedadesPorCama[camaId] ?? [];

      int limite = 3600;
      for (final vid in varIds) {
        final vRows = await db.query('tb_variedades', where: 'id = ?', whereArgs: [vid], limit: 1);
        if (vRows.isNotEmpty) {
          final v = Variedad.fromMap(vRows.first);
          final cfg = await obtenerConfigAgronomicaParaVariedad(v);
          final limVar = v.limiteEsquejes ?? cfg.limiteEsquejes;
          if (limVar < limite) limite = limVar;
        }
      }

      if (totalCant >= limite) {
        camasLlenas.add(camaId);
      }
    }

    return camasLlenas;
  }

  /// Retorna TODAS las siembras activas en una cama (soporta multisembradores y multi-variedad)
  Future<List<Siembra>> obtenerSiembrasActivasPorCama(int camaId, {int? excluirSiembraId}) async {
    final db = await LocalDatabase.instance.database;
    String whereClause = "cama_id = ? AND estado = 'ACTIVA'";
    List<dynamic> whereArgs = [camaId];
    if (excluirSiembraId != null) {
      whereClause += ' AND id_local != ?';
      whereArgs.add(excluirSiembraId);
    }
    final result = await db.query(
      'tb_siembras',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id_local ASC',
    );
    return result.map((row) => Siembra.fromMap(row)).toList();
  }

  /// Retorna la primera siembra activa para una cama específica si existe (retrocompatibilidad)
  Future<Siembra?> obtenerSiembraActivaPorCama(int camaId, {int? excluirSiembraId}) async {
    final activas = await obtenerSiembrasActivasPorCama(camaId, excluirSiembraId: excluirSiembraId);
    if (activas.isNotEmpty) {
      return activas.first;
    }
    return null;
  }

  /// Retorna la última siembra registrada en una cama (activa o finalizada)
  Future<Siembra?> obtenerUltimaSiembraPorCama(int camaId, {int? excluirSiembraId}) async {
    final db = await LocalDatabase.instance.database;
    String whereClause = 'cama_id = ?';
    List<dynamic> whereArgs = [camaId];
    if (excluirSiembraId != null) {
      whereClause += ' AND id_local != ?';
      whereArgs.add(excluirSiembraId);
    }
    final result = await db.query(
      'tb_siembras',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id_local DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Siembra.fromMap(result.first);
    }
    return null;
  }

  /// Valida de forma estricta las restricciones agronómicas de capacidad y ciclo de cama,
  /// permitiendo explícitamente multisembradores y multi-variedad en la misma cama hasta agotar el cupo agronómico.
  Future<ValidacionCicloResultado> validarCicloYCamaParaSiembra(
    int camaId,
    String fechaNuevaStr, {
    int? nuevaCantidad,
    int? nuevaVariedadId,
    int? nuevoOperarioId,
    int? excluirSiembraId,
  }) async {
    final db = await LocalDatabase.instance.database;
    final fechaNueva = parsearFechaSiembra(fechaNuevaStr) ?? DateTime.now();

    // 1. Consultar configuración de la nueva variedad (si fue especificada)
    Variedad? nuevaVariedad;
    ConfigAgronomica? cfgNuevaVariedad;
    if (nuevaVariedadId != null) {
      final vRows = await db.query('tb_variedades', where: 'id = ?', whereArgs: [nuevaVariedadId], limit: 1);
      if (vRows.isNotEmpty) {
        nuevaVariedad = Variedad.fromMap(vRows.first);
        cfgNuevaVariedad = await obtenerConfigAgronomicaParaVariedad(nuevaVariedad);
      }
    }

    // 2. Obtener TODAS las siembras ACTIVAS en la cama (soporte multisembradores y multi-variedad)
    final siembrasActivas = await obtenerSiembrasActivasPorCama(camaId, excluirSiembraId: excluirSiembraId);

    if (siembrasActivas.isNotEmpty) {
      // Calcular cantidad acumulada sembrada actualmente en la cama
      final int totalPlantado = siembrasActivas.fold(0, (sum, s) => sum + s.cantidad);

      // Recopilar información de variedades y sembradores presentes
      final Set<String> nombresVariedades = {};
      final Set<String> nombresOperarios = {};
      int limiteCama = nuevaVariedad?.limiteEsquejes ?? cfgNuevaVariedad?.limiteEsquejes ?? 3600;
      int maxDiasCicloReq = nuevaVariedad?.diasCiclo ?? cfgNuevaVariedad?.diasCiclo ?? 75;

      for (final s in siembrasActivas) {
        final vRows = await db.query('tb_variedades', where: 'id = ?', whereArgs: [s.variedadId], limit: 1);
        if (vRows.isNotEmpty) {
          final v = Variedad.fromMap(vRows.first);
          nombresVariedades.add(v.nombre);
          final cfg = await obtenerConfigAgronomicaParaVariedad(v);
          final int limV = v.limiteEsquejes ?? cfg.limiteEsquejes;
          if (limV < limiteCama) limiteCama = limV;
          final int dCiclo = v.diasCiclo ?? cfg.diasCiclo;
          if (dCiclo > maxDiasCicloReq) maxDiasCicloReq = dCiclo;
        } else {
          nombresVariedades.add('Variedad #${s.variedadId}');
        }

        final opRows = await db.query('tb_operarios', where: 'id = ?', whereArgs: [s.operarioId], limit: 1);
        if (opRows.isNotEmpty) {
          final op = Operario.fromMap(opRows.first);
          nombresOperarios.add(op.nombreCompleto);
        } else {
          nombresOperarios.add('Operario #${s.operarioId}');
        }
      }

      // Fecha de la siembra inicial en el ciclo activo actual
      final fInicio = parsearFechaSiembra(siembrasActivas.first.fecha) ?? DateTime.now();
      int diasTrans = fechaNueva.difference(fInicio).inDays;
      if (diasTrans < 0) diasTrans = 0;
      final int diasFalt = (maxDiasCicloReq - diasTrans) > 0 ? (maxDiasCicloReq - diasTrans) : 0;
      final fechaMin = fInicio.add(Duration(days: maxDiasCicloReq));

      // Si aún está dentro del período de ciclo activo
      if (diasTrans < maxDiasCicloReq) {
        final int cupoDisponible = (limiteCama - totalPlantado) > 0 ? (limiteCama - totalPlantado) : 0;

        // Caso A: Cama al 100% de capacidad agronómica (LLENA)
        if (cupoDisponible <= 0) {
          final fechaMinStr = "${fechaMin.day.toString().padLeft(2, '0')}/${fechaMin.month.toString().padLeft(2, '0')}/${fechaMin.year}";
          return ValidacionCicloResultado(
            esValido: false,
            esCicloActivo: true,
            esCamaLlena: true,
            esCamaCompartida: false,
            mensaje: 'Restricción Agronómica: La cama ya alcanzó el cupo máximo permitido ($totalPlantado de $limiteCama plantas) con siembras de ${nombresVariedades.join(", ")} por ${nombresOperarios.join(", ")}. Han transcurrido $diasTrans de $maxDiasCicloReq días de ciclo (faltan $diasFalt días). Cama disponible a partir del $fechaMinStr.',
            siembraPrevia: siembrasActivas.first,
            siembrasActivas: siembrasActivas,
            variedadPreviaNombre: nombresVariedades.join(", "),
            variedadesPresentes: nombresVariedades.toList(),
            operariosPresentes: nombresOperarios.toList(),
            cantidadOcupada: totalPlantado,
            limiteMaximo: limiteCama,
            cupoDisponible: 0,
            diasTranscurridos: diasTrans,
            diasRequeridos: maxDiasCicloReq,
            diasFaltantes: diasFalt,
            fechaMinimaPermitida: fechaMin,
          );
        }

        // Caso B: Cama con cupo disponible, pero la cantidad solicitada supera el cupo restante
        if (nuevaCantidad != null && nuevaCantidad > cupoDisponible) {
          return ValidacionCicloResultado(
            esValido: false,
            esCicloActivo: true,
            esCamaLlena: false,
            esCamaCompartida: true,
            mensaje: 'Límite agronómico de cama excedido: La cama ya tiene $totalPlantado plantas sembradas de un máximo de $limiteCama. Solo queda un cupo disponible de $cupoDisponible plantas y se intentó sembrar $nuevaCantidad.',
            siembraPrevia: siembrasActivas.first,
            siembrasActivas: siembrasActivas,
            variedadPreviaNombre: nombresVariedades.join(", "),
            variedadesPresentes: nombresVariedades.toList(),
            operariosPresentes: nombresOperarios.toList(),
            cantidadOcupada: totalPlantado,
            limiteMaximo: limiteCama,
            cupoDisponible: cupoDisponible,
            diasTranscurridos: diasTrans,
            diasRequeridos: maxDiasCicloReq,
            diasFaltantes: diasFalt,
            fechaMinimaPermitida: fechaMin,
          );
        }

        // Caso C: Cama compartida con cupo disponible (se permite sembrar nueva variedad o nuevo sembrador)
        return ValidacionCicloResultado(
          esValido: true,
          esCicloActivo: true,
          esCamaLlena: false,
          esCamaCompartida: true,
          mensaje: 'Cama compartida disponible: $totalPlantado de $limiteCama plantas ocupadas. Cupo disponible: $cupoDisponible plantas (${nombresVariedades.join(", ")} por ${nombresOperarios.join(", ")}).',
          siembraPrevia: siembrasActivas.first,
          siembrasActivas: siembrasActivas,
          variedadPreviaNombre: nombresVariedades.join(", "),
          variedadesPresentes: nombresVariedades.toList(),
          operariosPresentes: nombresOperarios.toList(),
          cantidadOcupada: totalPlantado,
          limiteMaximo: limiteCama,
          cupoDisponible: cupoDisponible,
          diasTranscurridos: diasTrans,
          diasRequeridos: maxDiasCicloReq,
          diasFaltantes: diasFalt,
          fechaMinimaPermitida: fechaMin,
        );
      }
      // Si diasTrans >= maxDiasCicloReq: El ciclo agronómico previo ya concluyó. La cama se libera.
    }

    // 3. Si no hay siembras activas, verificar si la última siembra registrada finalizó recientemente y aún no cumple el ciclo
    final ultimaSiembra = await obtenerUltimaSiembraPorCama(camaId, excluirSiembraId: excluirSiembraId);
    if (ultimaSiembra != null) {
      final fInicio = parsearFechaSiembra(ultimaSiembra.fecha);
      if (fInicio != null) {
        final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [ultimaSiembra.variedadId], limit: 1);
        final varPrevia = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
        final cfgVar = await obtenerConfigAgronomicaParaVariedad(varPrevia);
        final int diasReq = varPrevia?.diasCiclo ?? cfgVar.diasCiclo;

        int diasTrans = fechaNueva.difference(fInicio).inDays;
        if (diasTrans < 0) diasTrans = 0;

        if (ultimaSiembra.estado == 'FINALIZADA') {
          // El ciclo previo fue cortado y finalizado formalmente (por cosecha normal o anticipada por factores climáticos).
          // La cama se encuentra físicamente libre y disponible para la nueva siembra.
        } else if (diasTrans < diasReq) {
          final int diasFalt = diasReq - diasTrans;
          final fechaMin = fInicio.add(Duration(days: diasReq));
          final fechaMinStr = "${fechaMin.day.toString().padLeft(2, '0')}/${fechaMin.month.toString().padLeft(2, '0')}/${fechaMin.year}";

          return ValidacionCicloResultado(
            esValido: false,
            esCicloIncompleto: true,
            mensaje: 'Restricción de Ciclo Agronómico: La siembra previa de ${varPrevia?.nombre ?? "Variedad #${ultimaSiembra.variedadId}"} (iniciada el ${ultimaSiembra.fecha}) requiere un ciclo de $diasReq días (faltan $diasFalt días, estimado hasta: $fechaMinStr). Si la flor ya fue cortada o cosechada, seleccione "Finalizar Ciclo" en el registro previo para liberarla inmediatamente.',
            siembraPrevia: ultimaSiembra,
            variedadPreviaNombre: varPrevia?.nombre,
            diasTranscurridos: diasTrans,
            diasRequeridos: diasReq,
            diasFaltantes: diasFalt,
            fechaMinimaPermitida: fechaMin,
          );
        }
      }
    }

    // 4. Cama totalmente libre y disponible
    final int limiteDefault = nuevaVariedad?.limiteEsquejes ?? cfgNuevaVariedad?.limiteEsquejes ?? 3600;
    if (nuevaCantidad != null && nuevaCantidad > limiteDefault) {
      return ValidacionCicloResultado(
        esValido: false,
        mensaje: 'Límite agronómico excedido: La cantidad ingresada ($nuevaCantidad) supera el máximo de $limiteDefault plantas para ${nuevaVariedad?.nombre ?? "el cultivo"}.',
        limiteMaximo: limiteDefault,
        cupoDisponible: limiteDefault,
      );
    }

    return ValidacionCicloResultado(
      esValido: true,
      mensaje: 'Cama disponible para siembra y ciclo agronómico cumplido.',
      limiteMaximo: limiteDefault,
      cupoDisponible: limiteDefault,
    );
  }

  /// Retorna el estado detallado de ciclo para cada cama de un bloque
  Future<Map<int, ValidacionCicloResultado>> obtenerEstadoCicloCamasPorBloque(
    String bloqueCodigo,
    String fechaReferenciaStr,
  ) async {
    final camas = await obtenerCamasPorBloque(bloqueCodigo);
    final Map<int, ValidacionCicloResultado> map = {};
    for (final c in camas) {
      final res = await validarCicloYCamaParaSiembra(c.id, fechaReferenciaStr);
      map[c.id] = res;
    }
    return map;
  }

  Future<List<Operario>> obtenerOperarios() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_operarios', orderBy: 'nombre_completo ASC');
    return result.map((json) => Operario.fromMap(json)).toList();
  }

  // === MÉTODOS PARA SIEMBRAS Y CICLOS (Offline First) ===

  Future<int> registrarSiembraOffline(Siembra siembra) async {
    final db = await LocalDatabase.instance.database;

    // 1. Validación de Ciclo Agronómico y Capacidad de Cama (soporte multisembradores y multi-variedad)
    final validacionCiclo = await validarCicloYCamaParaSiembra(
      siembra.camaId,
      siembra.fecha,
      nuevaCantidad: siembra.cantidad,
      nuevaVariedadId: siembra.variedadId,
      nuevoOperarioId: siembra.operarioId,
    );
    if (!validacionCiclo.esValido) {
      throw AgronomicValidationException(validacionCiclo.mensaje);
    }

    // 2. Validación de Límite Agronómico de Esquejes / Plantas
    final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [siembra.variedadId], limit: 1);
    final varSiembra = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
    final cfgVar = await obtenerConfigAgronomicaParaVariedad(varSiembra);
    final int limitePermitido = varSiembra?.limiteEsquejes ?? cfgVar.limiteEsquejes;
    if (siembra.cantidad > limitePermitido) {
      throw AgronomicValidationException(
        'Límite agronómico excedido: La cantidad ingresada (${siembra.cantidad}) supera el máximo permitido de $limitePermitido esquejes/plantas para ${varSiembra?.nombre ?? "Variedad #${siembra.variedadId}"}.',
      );
    }

    // 2.1 Validación estricta para LIRIOS: Lote, Proveedor y Contenedor obligatorios
    final fam = (varSiembra?.familiaNombre ?? '').toUpperCase();
    final nom = (varSiembra?.nombre ?? '').toUpperCase();
    final famId = varSiembra?.familiaId ?? 0;
    final bool esLirios = fam.contains('LIRIO') ||
        fam.contains('LILIUM') ||
        fam.contains('LONGIFLORUM') ||
        fam.contains('ASIATICO') ||
        fam.contains('ORIENTAL') ||
        nom.contains('LIRIO') ||
        nom.contains('LILIUM') ||
        [199, 204, 309, 255].contains(famId);

    if (esLirios) {
      if (siembra.lote == null || siembra.lote!.trim().isEmpty ||
          siembra.proveedor == null || siembra.proveedor!.trim().isEmpty ||
          siembra.cont == null || siembra.cont!.trim().isEmpty) {
        throw AgronomicValidationException(
          'Trazabilidad obligatoria: Para el cultivo de LIRIOS, el Lote, Contenedor y Proveedor son campos estrictamente OBLIGATORIOS.',
        );
      }
    }

    // 3. ELIMINAR DE LA BASE DE DATOS LAS SIEMBRAS ANTERIORES QUE HAYAN CUMPLIDO EL CICLO EN ESTA CAMA
    await eliminarSiembrasCicloCumplidoPorCama(siembra.camaId, fechaNuevaStr: siembra.fecha);

    final map = siembra.toMap();
    if (!esLirios) {
      map['lote'] = null;
      map['proveedor'] = null;
      map['cont'] = null;
    }

    if (map['uuid'] == null || map['uuid'].toString().trim().isEmpty) {
      map['uuid'] = 'siembra-${DateTime.now().millisecondsSinceEpoch}-${siembra.camaId}';
    }

    final id = await db.insert('tb_siembras', map);
    await LocalDatabase.instance.checkpoint();
    await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
    return id;
  }

  /// Elimina de la base de datos local las siembras de una cama que ya hayan cumplido su ciclo agronómico
  Future<int> eliminarSiembrasCicloCumplidoPorCama(int camaId, {String? fechaNuevaStr}) async {
    final db = await LocalDatabase.instance.database;
    final fechaRef = parsearFechaSiembra(fechaNuevaStr ?? '') ?? DateTime.now();

    final previas = await db.query(
      'tb_siembras',
      where: 'cama_id = ?',
      whereArgs: [camaId],
    );

    int eliminadas = 0;
    for (final row in previas) {
      final s = Siembra.fromMap(row);
      bool debeEliminarse = false;

      // REGLA ESTRICTA DE CAMAS MULTIVARIEDAD Y CICLO AGRONÓMICO:
      // Al registrar otra variedad en una cama multivariedad, NUNCA se elimina el registro
      // anterior si su ciclo aún no se ha cumplido.
      // Únicamente si ya se cumplió la totalidad de los días de ciclo (diasTrans >= diasReq)
      // y con un umbral agronómico real (mínimo 30 días) se considera ciclo cumplido para su depuración.
      final fInicio = parsearFechaSiembra(s.fecha);
      if (fInicio != null) {
        final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [s.variedadId], limit: 1);
        final varObj = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
        final cfg = await obtenerConfigAgronomicaParaVariedad(varObj);
        final int diasReq = (varObj?.diasCiclo != null && varObj!.diasCiclo! > 0)
            ? varObj.diasCiclo!
            : (cfg.diasCiclo > 0 ? cfg.diasCiclo : 75);

        final diasTrans = fechaRef.difference(fInicio).inDays;
        if (diasTrans >= diasReq && diasTrans >= 30) {
          debeEliminarse = true;
        }
      }

      if (debeEliminarse && s.idLocal != null) {
        // SEGURIDAD: Nunca eliminar automáticamente siembras pendientes de sincronizar
        if (s.sincronizado == 0) {
          continue;
        }
        if (s.sincronizado == 1 && s.uuid != null && s.uuid!.isNotEmpty) {
          try {
            await db.insert('tb_eliminaciones_pendientes', {
              'uuid': s.uuid,
              'fecha_eliminacion': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        }
        await db.delete('tb_siembras', where: 'id_local = ?', whereArgs: [s.idLocal]);
        eliminadas++;
      }
    }

    if (eliminadas > 0) {
      await LocalDatabase.instance.checkpoint();
      await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
    }

    return eliminadas;
  }

  /// Finaliza el ciclo agronómico de una siembra y libera la cama
  Future<void> finalizarCicloSiembra(int idLocal, String fechaFin) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'tb_siembras',
      {
        'estado': 'FINALIZADA',
        'fecha_fin': fechaFin,
        'sincronizado': 0, // Reenviar al backend para liberar en Access (t49)
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
    await LocalDatabase.instance.checkpoint();
    await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
  }

  /// Libera de forma inmediata una cama finalizando todas las siembras activas o pendientes previas
  /// por corte anticipado (factores climáticos/naturales) o descarte agronómico.
  /// Retorna la cantidad de siembras que fueron finalizadas.
  Future<int> liberarCamaPorCorteAnticipado(int camaId, String fechaFin) async {
    final siembrasActivas = await obtenerSiembrasActivasPorCama(camaId);
    int liberadas = 0;
    for (final s in siembrasActivas) {
      if (s.idLocal != null) {
        await finalizarCicloSiembra(s.idLocal!, fechaFin);
        liberadas++;
      }
    }
    // Si no había siembras marcadas como activas pero la última siembra registrada tenía estado no finalizado:
    final ultima = await obtenerUltimaSiembraPorCama(camaId);
    if (ultima != null && ultima.estado != 'FINALIZADA' && ultima.idLocal != null) {
      if (!siembrasActivas.any((s) => s.idLocal == ultima.idLocal)) {
        await finalizarCicloSiembra(ultima.idLocal!, fechaFin);
        liberadas++;
      }
    }
    return liberadas;
  }

  Future<List<Siembra>> obtenerSiembrasPendientesSync() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_siembras', where: 'sincronizado = ?', whereArgs: [0]);
    return result.map((json) => Siembra.fromMap(json)).toList();
  }

  Future<void> marcarSiembraComoSincronizada(int idLocal) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'tb_siembras',
      {'sincronizado': 1},
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
    await LocalDatabase.instance.checkpoint();
    await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
  }

  /// Integra en SQLite las siembras activas recibidas desde el servidor ('pull')
  Future<int> integrarSiembrasDesdeServidor(List<dynamic> pullList) async {
    final db = await LocalDatabase.instance.database;
    int integradas = 0;
    for (final item in pullList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final uuid = map['uuid']?.toString();
      if (uuid == null || uuid.isEmpty) continue;

      final existing = await db.query('tb_siembras', where: 'uuid = ?', whereArgs: [uuid], limit: 1);
      if (existing.isEmpty) {
        final s = Siembra(
          uuid: uuid,
          fecha: map['fecha_str']?.toString() ?? '',
          bloqueCodigo: map['bloque_codigo']?.toString() ?? '',
          camaId: map['cama_id'] as int? ?? 0,
          variedadId: map['variedad_id'] as int? ?? 0,
          operarioId: map['operario_id'] as int? ?? 0,
          cantidad: map['cantidad_esquejes'] as int? ?? 0,
          lineas: map['lineas'] as int? ?? 14,
          lote: map['lote']?.toString(),
          proveedor: map['proveedor']?.toString(),
          cont: map['conteo']?.toString(),
          observaciones: map['observaciones']?.toString(),
          estado: map['estado']?.toString() ?? 'ACTIVA',
          fechaFin: map['fecha_fin_str']?.toString(),
          sincronizado: 1,
        );
        await db.insert('tb_siembras', s.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        integradas++;
      } else {
        await db.update(
          'tb_siembras',
          {
            'estado': map['estado']?.toString() ?? 'ACTIVA',
            'fecha_fin': map['fecha_fin_str']?.toString(),
            'sincronizado': 1,
          },
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
      }
    }
    if (integradas > 0) {
      await LocalDatabase.instance.checkpoint();
      await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
    }
    return integradas;
  }

  Future<List<Siembra>> obtenerHistorialSiembras() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_siembras', orderBy: 'id_local DESC');
    return result.map((json) => Siembra.fromMap(json)).toList();
  }

  /// Elimina un registro de siembra de la base de datos local SQLite
  Future<void> eliminarSiembra(int idLocal) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('tb_siembras', where: 'id_local = ?', whereArgs: [idLocal], limit: 1);
    if (rows.isNotEmpty) {
      final s = rows.first;
      final fechaStr = s['fecha']?.toString();
      if (!CalendarioUtil.puedeModificarSiembraPorFecha(fechaStr)) {
        final dias = CalendarioUtil.diasDesdeFecha(fechaStr);
        throw AgronomicValidationException(
          'Registro protegido: Este registro tiene $dias días de antigüedad (límite: 2 días). No se puede eliminar desde la app móvil; solo puede modificarse desde la base de datos empresarial.',
        );
      }

      try {
        final uuid = s['uuid']?.toString();
        final sync = s['sincronizado'] as int? ?? 0;
        if (sync == 1 && uuid != null && uuid.isNotEmpty) {
          await db.insert('tb_eliminaciones_pendientes', {
            'uuid': uuid,
            'fecha_eliminacion': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}
    }

    await db.delete(
      'tb_siembras',
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
    await LocalDatabase.instance.checkpoint();
    await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
  }

  /// Actualiza los datos de un registro de siembra en la base de datos local SQLite
  Future<void> actualizarSiembra(Siembra siembra) async {
    if (siembra.idLocal == null) return;
    final db = await LocalDatabase.instance.database;

    // 0. Validación de Antigüedad: solo modificable dentro de los primeros 2 días
    final rowsOriginal = await db.query('tb_siembras', where: 'id_local = ?', whereArgs: [siembra.idLocal], limit: 1);
    if (rowsOriginal.isNotEmpty) {
      final fechaOriginal = rowsOriginal.first['fecha']?.toString();
      if (!CalendarioUtil.puedeModificarSiembraPorFecha(fechaOriginal)) {
        final dias = CalendarioUtil.diasDesdeFecha(fechaOriginal);
        throw AgronomicValidationException(
          'Registro protegido: Este registro tiene $dias días de antigüedad (límite: 2 días). No se puede modificar desde la app móvil; cualquier modificación debe realizarse directamente desde la base de datos empresarial.',
        );
      }
    }
    if (!CalendarioUtil.puedeModificarSiembraPorFecha(siembra.fecha)) {
      final dias = CalendarioUtil.diasDesdeFecha(siembra.fecha);
      throw AgronomicValidationException(
        'Fecha restringida: La fecha especificada tiene $dias días de antigüedad (límite: 2 días). No es posible asignar fechas anteriores a 2 días desde la app móvil.',
      );
    }

    // 1. Validación de Ciclo Agronómico y Capacidad de Cama al actualizar
    final validacionCiclo = await validarCicloYCamaParaSiembra(
      siembra.camaId,
      siembra.fecha,
      nuevaCantidad: siembra.cantidad,
      nuevaVariedadId: siembra.variedadId,
      nuevoOperarioId: siembra.operarioId,
      excluirSiembraId: siembra.idLocal,
    );
    if (!validacionCiclo.esValido) {
      throw AgronomicValidationException(validacionCiclo.mensaje);
    }

    // 2. Validación de Límite Agronómico al actualizar
    final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [siembra.variedadId], limit: 1);
    final varSiembra = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
    final cfgVar = await obtenerConfigAgronomicaParaVariedad(varSiembra);
    final int limitePermitido = varSiembra?.limiteEsquejes ?? cfgVar.limiteEsquejes;
    if (siembra.cantidad > limitePermitido) {
      throw AgronomicValidationException(
        'Límite agronómico excedido: La cantidad ingresada (${siembra.cantidad}) supera el máximo permitido de $limitePermitido esquejes/plantas para ${varSiembra?.nombre ?? "Variedad #${siembra.variedadId}"}.',
      );
    }

    // 2.1 Validación estricta para LIRIOS: Lote, Proveedor y Contenedor obligatorios
    final fam = (varSiembra?.familiaNombre ?? '').toUpperCase();
    final nom = (varSiembra?.nombre ?? '').toUpperCase();
    final famId = varSiembra?.familiaId ?? 0;
    final bool esLirios = fam.contains('LIRIO') ||
        fam.contains('LILIUM') ||
        fam.contains('LONGIFLORUM') ||
        fam.contains('ASIATICO') ||
        fam.contains('ORIENTAL') ||
        nom.contains('LIRIO') ||
        nom.contains('LILIUM') ||
        [199, 204, 309, 255].contains(famId);

    if (esLirios) {
      if (siembra.lote == null || siembra.lote!.trim().isEmpty ||
          siembra.proveedor == null || siembra.proveedor!.trim().isEmpty ||
          siembra.cont == null || siembra.cont!.trim().isEmpty) {
        throw AgronomicValidationException(
          'Trazabilidad obligatoria: Para el cultivo de LIRIOS, el Lote, Contenedor y Proveedor son campos estrictamente OBLIGATORIOS.',
        );
      }
    }

    final map = siembra.toMap();
    if (!esLirios) {
      map['lote'] = null;
      map['proveedor'] = null;
      map['cont'] = null;
    }
    map['sincronizado'] = 0; // Marcar para re-sincronizar con backend Access
    await db.update(
      'tb_siembras',
      map,
      where: 'id_local = ?',
      whereArgs: [siembra.idLocal],
    );
    await LocalDatabase.instance.checkpoint();
    await PersistentBackupService.instance.resguardarSiembras(dbExecutor: db);
  }

  /// Estadísticas de la base de datos SQLite offline local
  Future<Map<String, dynamic>> obtenerEstadisticasOffline() async {
    final db = await LocalDatabase.instance.database;
    final totalSiembras = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_siembras')) ?? 0;
    final pendientesSync = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_siembras WHERE sincronizado = 0')) ?? 0;
    final sincronizadas = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_siembras WHERE sincronizado = 1')) ?? 0;
    final variedades = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_variedades')) ?? 0;
    final camas = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_camas')) ?? 0;
    final bloques = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_bloques')) ?? 0;
    final operarios = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tb_operarios')) ?? 0;
    return {
      'total_siembras': totalSiembras,
      'pendientes_sync': pendientesSync,
      'sincronizadas': sincronizadas,
      'variedades': variedades,
      'camas': camas,
      'bloques': bloques,
      'operarios': operarios,
    };
  }

  /// Obtiene un valor de configuración persistente (como la URL del servidor)
  Future<String?> obtenerAjuste(String clave) async {
    final db = await LocalDatabase.instance.database;
    try {
      await db.execute('CREATE TABLE IF NOT EXISTS tb_app_settings (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
      final res = await db.query('tb_app_settings', where: 'clave = ?', whereArgs: [clave], limit: 1);
      if (res.isNotEmpty) return res.first['valor'] as String?;
    } catch (_) {}
    return null;
  }

  /// Guarda o actualiza un valor de configuración persistente
  Future<void> guardarAjuste(String clave, String valor) async {
    final db = await LocalDatabase.instance.database;
    try {
      await db.execute('CREATE TABLE IF NOT EXISTS tb_app_settings (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
      await db.insert(
        'tb_app_settings',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Obtiene los UUIDs de siembras eliminadas localmente para enviar al backend
  Future<List<String>> obtenerUuidsEliminacionesPendientes() async {
    final db = await LocalDatabase.instance.database;
    try {
      final res = await db.query('tb_eliminaciones_pendientes', columns: ['uuid']);
      return res.map((r) => r['uuid'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Limpia los UUIDs de eliminaciones confirmadas por el backend
  Future<void> limpiarEliminacionesPendientes(List<String> uuids) async {
    final db = await LocalDatabase.instance.database;
    try {
      for (var u in uuids) {
        await db.delete('tb_eliminaciones_pendientes', where: 'uuid = ?', whereArgs: [u]);
      }
    } catch (_) {}
  }

  // === MÉTODOS CATÁLOGO LIRIOS TABLA 187 (Proveedor, Contenedor, Lote, Variedad) ===

  /// Reemplaza todos los registros del catálogo de la tabla 187 de Lirios
  Future<void> reemplazarLirios187(List<LirioItem187> lirios) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('tb_lirios_187');
      final batch = txn.batch();
      for (var l in lirios) {
        batch.insert('tb_lirios_187', l.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// Obtiene los proveedores únicos registrados en la tabla 187
  Future<List<String>> obtenerProveedoresLirios() async {
    final db = await LocalDatabase.instance.database;
    try {
      final res = await db.rawQuery(
        'SELECT DISTINCT proveedor FROM tb_lirios_187 WHERE proveedor IS NOT NULL AND proveedor != "" ORDER BY proveedor ASC',
      );
      return res.map((r) => r['proveedor'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene los contenedores únicos registrados en la tabla 187 (opcionalmente filtrados por proveedor)
  Future<List<String>> obtenerContenedoresLirios({String? proveedor}) async {
    final db = await LocalDatabase.instance.database;
    try {
      String sql = 'SELECT DISTINCT contenedor FROM tb_lirios_187 WHERE contenedor IS NOT NULL AND contenedor != ""';
      List<dynamic> args = [];
      if (proveedor != null && proveedor.trim().isNotEmpty) {
        sql += ' AND proveedor = ?';
        args.add(proveedor.trim());
      }
      sql += ' ORDER BY CAST(contenedor AS INTEGER), contenedor ASC';
      final res = await db.rawQuery(sql, args);
      return res.map((r) => r['contenedor'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene los lotes únicos registrados en la tabla 187 (opcionalmente filtrados por proveedor y contenedor)
  Future<List<String>> obtenerLotesLirios({String? proveedor, String? contenedor}) async {
    final db = await LocalDatabase.instance.database;
    try {
      String sql = 'SELECT DISTINCT lote FROM tb_lirios_187 WHERE lote IS NOT NULL AND lote != ""';
      List<dynamic> args = [];
      if (proveedor != null && proveedor.trim().isNotEmpty) {
        sql += ' AND proveedor = ?';
        args.add(proveedor.trim());
      }
      if (contenedor != null && contenedor.trim().isNotEmpty) {
        sql += ' AND contenedor = ?';
        args.add(contenedor.trim());
      }
      sql += ' ORDER BY lote ASC';
      final res = await db.rawQuery(sql, args);
      return res.map((r) => r['lote'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca registros completos de la tabla 187 (para auto-completar proveedor/contenedor al elegir lote)
  Future<List<LirioItem187>> obtenerRegistrosLirios187({
    String? proveedor,
    String? contenedor,
    String? lote,
  }) async {
    final db = await LocalDatabase.instance.database;
    try {
      String sql = 'SELECT * FROM tb_lirios_187 WHERE 1=1';
      List<dynamic> args = [];
      if (proveedor != null && proveedor.trim().isNotEmpty) {
        sql += ' AND proveedor = ?';
        args.add(proveedor.trim());
      }
      if (contenedor != null && contenedor.trim().isNotEmpty) {
        sql += ' AND contenedor = ?';
        args.add(contenedor.trim());
      }
      if (lote != null && lote.trim().isNotEmpty) {
        sql += ' AND lote = ?';
        args.add(lote.trim());
      }
      sql += ' ORDER BY lote ASC';
      final res = await db.rawQuery(sql, args);
      return res.map((r) => LirioItem187.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Realiza la verificación y restauración manual desde el almacenamiento persistente
  Future<ResultadoRecuperacion> restaurarDesdeRespaldoPersistente() async {
    final db = await LocalDatabase.instance.database;
    return await PersistentBackupService.instance.verificarYRecuperar(db);
  }
}



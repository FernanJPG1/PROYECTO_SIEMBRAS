import 'package:app_movil/database/local_db.dart';
import 'package:app_movil/models/entidades.dart';
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
  final String mensaje;
  final Siembra? siembraPrevia;
  final String? variedadPreviaNombre;
  final int diasTranscurridos;
  final int diasRequeridos;
  final int diasFaltantes;
  final DateTime? fechaMinimaPermitida;

  ValidacionCicloResultado({
    required this.esValido,
    this.esCicloActivo = false,
    this.esCicloIncompleto = false,
    required this.mensaje,
    this.siembraPrevia,
    this.variedadPreviaNombre,
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
        batch.insert('tb_variedades', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
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
    if (cName == 'LA' || cName == 'LO' || cName == 'OT' || cName.contains('LIRIO')) {
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

    return ConfigAgronomica(cultivo: 'GENERAL', limiteEsquejes: 2600, diasCiclo: 75, densidadLinea: 20);
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
        cultivoDeducido = 'LIRIOS';
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

  Future<List<Variedad>> obtenerVariedadesPorFamilia(List<int> familiaIds, {bool soloActivas = true}) async {
    final db = await LocalDatabase.instance.database;
    if (familiaIds.isEmpty) {
      return obtenerVariedades(soloActivas: soloActivas);
    }
    final placeholders = List.filled(familiaIds.length, '?').join(',');
    final whereArgs = [...familiaIds];
    String whereClause = 'familia_id IN ($placeholders)';
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

  /// Retorna los IDs de las camas que tienen una siembra ACTIVA (ocupadas)
  Future<Set<int>> obtenerIdsCamasOcupadas({String? bloqueCodigo}) async {
    final db = await LocalDatabase.instance.database;
    String whereClause = "estado = 'ACTIVA'";
    List<dynamic> whereArgs = [];
    if (bloqueCodigo != null && bloqueCodigo.isNotEmpty) {
      whereClause += ' AND bloque_codigo = ?';
      whereArgs.add(bloqueCodigo);
    }
    final result = await db.query(
      'tb_siembras',
      columns: ['cama_id'],
      where: whereClause,
      whereArgs: whereArgs,
    );
    return result.map((row) => row['cama_id'] as int).toSet();
  }

  /// Retorna la siembra activa para una cama específica si existe
  Future<Siembra?> obtenerSiembraActivaPorCama(int camaId, {int? excluirSiembraId}) async {
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
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Siembra.fromMap(result.first);
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

  /// Valida de forma estricta las restricciones de ciclo agronómico y disponibilidad para una cama
  Future<ValidacionCicloResultado> validarCicloYCamaParaSiembra(
    int camaId,
    String fechaNuevaStr, {
    int? excluirSiembraId,
  }) async {
    final db = await LocalDatabase.instance.database;
    final fechaNueva = parsearFechaSiembra(fechaNuevaStr) ?? DateTime.now();

    // 1. Verificar si existe siembra ACTIVA
    final sActiva = await obtenerSiembraActivaPorCama(camaId, excluirSiembraId: excluirSiembraId);
    if (sActiva != null) {
      final fInicio = parsearFechaSiembra(sActiva.fecha) ?? DateTime.now();
      
      // Consultar variedad previa y su configuración
      final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [sActiva.variedadId], limit: 1);
      final varPrevia = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
      final cfgVar = await obtenerConfigAgronomicaParaVariedad(varPrevia);
      final int diasReq = varPrevia?.diasCiclo ?? cfgVar.diasCiclo;

      int diasTrans = fechaNueva.difference(fInicio).inDays;
      if (diasTrans < 0) diasTrans = 0;
      final int diasFalt = (diasReq - diasTrans) > 0 ? (diasReq - diasTrans) : 0;
      final fechaMin = fInicio.add(Duration(days: diasReq));

      // Si aún NO ha cumplido el ciclo requerido, bloquear la resiembra
      if (diasTrans < diasReq) {
        final fechaMinStr = "${fechaMin.day.toString().padLeft(2, '0')}/${fechaMin.month.toString().padLeft(2, '0')}/${fechaMin.year}";
        return ValidacionCicloResultado(
          esValido: false,
          esCicloActivo: true,
          mensaje: 'Restricción de Ciclo Agronómico: La cama tiene una siembra de ${varPrevia?.nombre ?? "Variedad #${sActiva.variedadId}"} (iniciada el ${sActiva.fecha}) que requiere $diasReq días de ciclo. Solo han transcurrido $diasTrans días (faltan $diasFalt días). Estará disponible el $fechaMinStr.',
          siembraPrevia: sActiva,
          variedadPreviaNombre: varPrevia?.nombre,
          diasTranscurridos: diasTrans,
          diasRequeridos: diasReq,
          diasFaltantes: diasFalt,
          fechaMinimaPermitida: fechaMin,
        );
      }
      // Si diasTrans >= diasReq: El ciclo agronómico YA SE CUMPLIÓ. Se permite la siembra y se limpiará la anterior.
    }

    // 2. Verificar si la última siembra registrada en la cama ha cumplido el ciclo de desarrollo
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

        if (diasTrans < diasReq) {
          final int diasFalt = diasReq - diasTrans;
          final fechaMin = fInicio.add(Duration(days: diasReq));
          final fechaMinStr = "${fechaMin.day.toString().padLeft(2, '0')}/${fechaMin.month.toString().padLeft(2, '0')}/${fechaMin.year}";

          return ValidacionCicloResultado(
            esValido: false,
            esCicloIncompleto: true,
            mensaje: 'Restricción de Ciclo Agronómico: La siembra previa de ${varPrevia?.nombre ?? "Variedad #${ultimaSiembra.variedadId}"} (iniciada el ${ultimaSiembra.fecha}) requiere un ciclo mínimo de $diasReq días. Solo han transcurrido $diasTrans días (faltan $diasFalt días). La cama estará disponible a partir del $fechaMinStr.',
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

    return ValidacionCicloResultado(
      esValido: true,
      mensaje: 'Cama disponible para siembra y ciclo agronómico cumplido.',
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

    // 1. Validación de Ciclo Agronómico y Cama Activa
    final validacionCiclo = await validarCicloYCamaParaSiembra(siembra.camaId, siembra.fecha);
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

    // 3. ELIMINAR DE LA BASE DE DATOS LAS SIEMBRAS ANTERIORES QUE HAYAN CUMPLIDO EL CICLO EN ESTA CAMA
    await eliminarSiembrasCicloCumplidoPorCama(siembra.camaId, fechaNuevaStr: siembra.fecha);

    return await db.insert('tb_siembras', siembra.toMap());
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

      if (s.estado == 'FINALIZADA') {
        debeEliminarse = true;
      } else {
        final fInicio = parsearFechaSiembra(s.fecha);
        if (fInicio != null) {
          final vars = await db.query('tb_variedades', where: 'id = ?', whereArgs: [s.variedadId], limit: 1);
          final varObj = vars.isNotEmpty ? Variedad.fromMap(vars.first) : null;
          final cfg = await obtenerConfigAgronomicaParaVariedad(varObj);
          final diasReq = varObj?.diasCiclo ?? cfg.diasCiclo;

          final diasTrans = fechaRef.difference(fInicio).inDays;
          if (diasTrans >= diasReq) {
            debeEliminarse = true;
          }
        }
      }

      if (debeEliminarse && s.idLocal != null) {
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
  }

  Future<List<Siembra>> obtenerHistorialSiembras() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('tb_siembras', orderBy: 'id_local DESC');
    return result.map((json) => Siembra.fromMap(json)).toList();
  }

  /// Elimina un registro de siembra de la base de datos local SQLite
  Future<void> eliminarSiembra(int idLocal) async {
    final db = await LocalDatabase.instance.database;
    try {
      final rows = await db.query('tb_siembras', where: 'id_local = ?', whereArgs: [idLocal], limit: 1);
      if (rows.isNotEmpty) {
        final s = rows.first;
        final uuid = s['uuid']?.toString();
        final sync = s['sincronizado'] as int? ?? 0;
        if (sync == 1 && uuid != null && uuid.isNotEmpty) {
          await db.insert('tb_eliminaciones_pendientes', {
            'uuid': uuid,
            'fecha_eliminacion': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {}

    await db.delete(
      'tb_siembras',
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  /// Actualiza los datos de un registro de siembra en la base de datos local SQLite
  Future<void> actualizarSiembra(Siembra siembra) async {
    if (siembra.idLocal == null) return;
    final db = await LocalDatabase.instance.database;

    // 1. Validación de Ciclo Agronómico al actualizar
    final validacionCiclo = await validarCicloYCamaParaSiembra(
      siembra.camaId,
      siembra.fecha,
      excluirSiembraId: siembra.idLocal,
    );
    if (!validacionCiclo.esValido && validacionCiclo.esCicloIncompleto) {
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

    final map = siembra.toMap();
    map['sincronizado'] = 0; // Marcar para re-sincronizar con backend Access
    await db.update(
      'tb_siembras',
      map,
      where: 'id_local = ?',
      whereArgs: [siembra.idLocal],
    );
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
}



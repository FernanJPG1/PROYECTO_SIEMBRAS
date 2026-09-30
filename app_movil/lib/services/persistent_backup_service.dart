import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/models/entidades.dart';

/// Resultado del proceso de verificación y recuperación de siembras
class ResultadoRecuperacion {
  final int totalLocal;
  final int totalRespaldo;
  final int recuperadas;
  final int pendientesSync;
  final String mensaje;
  final bool huboRecuperacion;

  ResultadoRecuperacion({
    required this.totalLocal,
    required this.totalRespaldo,
    required this.recuperadas,
    required this.pendientesSync,
    required this.mensaje,
    required this.huboRecuperacion,
  });
}

/// Servicio de Almacenamiento Permanente y Respaldo Antidescarga/Reinicio
///
/// Protege las siembras offline contra:
/// 1. Apagado repentino de tablets (corte abrupto de energía / 0% batería).
/// 2. Reinicio de tablets (reboots forzados o actualizaciones).
/// 3. Limpieza de memoria caché del sistema operativo Android o aplicaciones de limpieza.
///
/// Implementa escritura atómica con fsync en almacenamiento permanente (Files/Documents),
/// copias espejo .bak y reconciliación automática bidireccional al iniciar la app.
class PersistentBackupService {
  static final PersistentBackupService instance = PersistentBackupService._init();
  PersistentBackupService._init();

  static const String _archivoPrincipal = 'siembras_respaldo_persistente.json';
  static const String _archivoBak = 'siembras_respaldo_persistente.bak';
  static const String _archivoBorradores = 'borradores_formularios.json';

  /// Obtiene la lista de directorios de almacenamiento permanente seguros (NO caché)
  Future<List<Directory>> _obtenerDirectoriosSeguros() async {
    final List<Directory> dirs = [];

    // 1. Directorio de Documentos de la App (Interno persistente - Android nunca borra en "Limpiar Caché")
    try {
      final docDir = await getApplicationDocumentsDirectory();
      if (!dirs.any((d) => d.path == docDir.path)) {
        dirs.add(docDir);
      }
    } catch (e) {
      debugPrint('[PersistentBackup] Error al obtener ApplicationDocumentsDirectory: $e');
    }

    // 2. Directorio de Soporte de la App (Interno secundario persistente)
    try {
      final supportDir = await getApplicationSupportDirectory();
      if (!dirs.any((d) => d.path == supportDir.path)) {
        dirs.add(supportDir);
      }
    } catch (_) {}

    // 3. Directorio en Almacenamiento Externo / SD si está disponible (Resistente a reinstalación o borrado de datos)
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null && !dirs.any((d) => d.path == extDir.path)) {
        dirs.add(extDir);
      }
    } catch (_) {}

    // 4. Directorio público en /sdcard/Documents/Siembras_Respaldos (Fallback en Android para máxima supervivencia)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final publicDoc = Directory('/storage/emulated/0/Documents/Siembras_Respaldos');
        if (!await publicDoc.exists()) {
          await publicDoc.create(recursive: true);
        }
        if (!dirs.any((d) => d.path == publicDoc.path)) {
          dirs.add(publicDoc);
        }
      } catch (_) {
        // Puede requerir permisos según versión de Android, se ignora si falla
      }
    }

    return dirs;
  }

  /// Guarda todas las siembras actuales y eliminaciones pendientes de forma atómica en todos los directorios seguros
  Future<bool> resguardarSiembras({
    List<Siembra>? siembrasDirectas,
    List<String>? eliminaciones,
    Database? dbExecutor,
  }) async {
    try {
      List<Siembra> listaSiembras = siembrasDirectas ?? [];
      List<String> listaEliminaciones = eliminaciones ?? [];

      // Si no se pasaron directamente, consultar la base de datos SQLite
      if (siembrasDirectas == null) {
        Database? db = dbExecutor;
        if (db == null) {
          final dbPath = await getDatabasesPath();
          final path = p.join(dbPath, 'siembras_local.db');
          if (await databaseExists(path)) {
            db = await openDatabase(path);
          }
        }

        if (db != null) {
          final rows = await db.query('tb_siembras', orderBy: 'id_local DESC');
          listaSiembras = rows.map((r) => Siembra.fromMap(r)).toList();

          try {
            final delRows = await db.query('tb_eliminaciones_pendientes');
            listaEliminaciones = delRows.map((r) => r['uuid'].toString()).toList();
          } catch (_) {}
        }
      }

      final int pendientes = listaSiembras.where((s) => s.sincronizado == 0).length;

      final Map<String, dynamic> backupData = {
        'version': 2,
        'fecha_respaldo': DateTime.now().toIso8601String(),
        'total_registros': listaSiembras.length,
        'pendientes_sincronizacion': pendientes,
        'eliminaciones_pendientes': listaEliminaciones,
        'siembras': listaSiembras.map((s) => s.toMap()).toList(),
      };

      final jsonStr = jsonEncode(backupData);
      final directorios = await _obtenerDirectoriosSeguros();

      int guardadosExitosos = 0;

      for (final dir in directorios) {
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          final archivoFinal = File(p.join(dir.path, _archivoPrincipal));
          final archivoBak = File(p.join(dir.path, _archivoBak));
          final archivoTmp = File(p.join(dir.path, '$_archivoPrincipal.tmp'));

          // Escritura Atómica: Escribir en .tmp primero con flush: true (fuerza fsync a disco NAND)
          await archivoTmp.writeAsString(jsonStr, flush: true, encoding: utf8);

          // Si el archivo principal ya existe, conservarlo como .bak de respaldo de emergencia
          if (await archivoFinal.exists()) {
            try {
              if (await archivoBak.exists()) await archivoBak.delete();
              await archivoFinal.copy(archivoBak.path);
            } catch (_) {}
          }

          // Renombrar .tmp a .json (operación atómica en el sistema de archivos)
          if (await archivoFinal.exists()) {
            await archivoFinal.delete();
          }
          await archivoTmp.rename(archivoFinal.path);

          guardadosExitosos++;
        } catch (e) {
          debugPrint('[PersistentBackup] Error guardando en ${dir.path}: $e');
        }
      }

      debugPrint('[PersistentBackup] Respaldo permanente completado en $guardadosExitosos ubicaciones. Total: ${listaSiembras.length}, Pendientes: $pendientes');
      return guardadosExitosos > 0;
    } catch (e) {
      debugPrint('[PersistentBackup] Error crítico en resguardarSiembras: $e');
      return false;
    }
  }

  /// Lee los datos del respaldo persistente buscando en los directorios seguros (principal y .bak)
  Future<Map<String, dynamic>?> leerDatosRespaldo() async {
    final directorios = await _obtenerDirectoriosSeguros();

    for (final dir in directorios) {
      final archivo = File(p.join(dir.path, _archivoPrincipal));
      if (await archivo.exists()) {
        try {
          final content = await archivo.readAsString(encoding: utf8);
          if (content.trim().isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            if (data.containsKey('siembras')) {
              return data;
            }
          }
        } catch (e) {
          debugPrint('[PersistentBackup] Error leyendo ${archivo.path}: $e');
        }
      }

      // Probar archivo .bak si el principal estaba dañado o vacío
      final archivoBak = File(p.join(dir.path, _archivoBak));
      if (await archivoBak.exists()) {
        try {
          final content = await archivoBak.readAsString(encoding: utf8);
          if (content.trim().isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            if (data.containsKey('siembras')) {
              return data;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Verifica la integridad entre SQLite y el Respaldo Persistente.
  /// Si la tablet se apagó, se reinició o la caché fue eliminada, restaura automáticamente
  /// las siembras que falten en SQLite, garantizando que NINGUNA siembra pendiente de sincronizar se pierda.
  Future<ResultadoRecuperacion> verificarYRecuperar(Database db) async {
    try {
      // 1. Obtener registros actuales en SQLite
      final rowsLocal = await db.query('tb_siembras');
      final List<Siembra> locales = rowsLocal.map((r) => Siembra.fromMap(r)).toList();

      // Set para identificación rápida de siembras existentes en SQLite
      final Set<String> firmasLocales = {};
      final Set<String> uuidsLocales = {};

      for (var s in locales) {
        if (s.uuid != null && s.uuid!.isNotEmpty) {
          uuidsLocales.add(s.uuid!);
        }
        // Firma de unicidad física: fecha + cama_id + variedad_id + cantidad + estado
        firmasLocales.add('${s.fecha}_${s.camaId}_${s.variedadId}_${s.cantidad}_${s.estado}');
      }

      // 2. Leer respaldo persistente de disco seguro
      final respaldo = await leerDatosRespaldo();

      if (respaldo == null || !respaldo.containsKey('siembras')) {
        // Si no hay archivo de respaldo pero sí hay datos en SQLite, crear el primer respaldo persistente
        if (locales.isNotEmpty) {
          await resguardarSiembras(siembrasDirectas: locales, dbExecutor: db);
        }
        final pendientes = locales.where((s) => s.sincronizado == 0).length;
        return ResultadoRecuperacion(
          totalLocal: locales.length,
          totalRespaldo: locales.length,
          recuperadas: 0,
          pendientesSync: pendientes,
          mensaje: 'Almacenamiento permanente sincronizado con SQLite.',
          huboRecuperacion: false,
        );
      }

      final List<dynamic> siembrasRaw = respaldo['siembras'] as List<dynamic>;
      final List<Siembra> enRespaldo = siembrasRaw.map((m) => Siembra.fromMap(m as Map<String, dynamic>)).toList();

      int recuperadas = 0;
      final batch = db.batch();

      for (var s in enRespaldo) {
        bool yaExiste = false;

        if (s.uuid != null && s.uuid!.isNotEmpty) {
          if (uuidsLocales.contains(s.uuid)) {
            yaExiste = true;
          }
        }

        final firma = '${s.fecha}_${s.camaId}_${s.variedadId}_${s.cantidad}_${s.estado}';
        if (firmasLocales.contains(firma)) {
          yaExiste = true;
        }

        // Si la siembra NO está en SQLite, fue eliminada por apagado/reinicio/limpieza de caché!
        // Reinsertarla inmediatamente con máxima prioridad si está pendiente de sincronización.
        if (!yaExiste) {
          final map = s.toMap();
          // Asegurar inserción limpia (SQLite asignará un id_local nuevo si es necesario)
          map.remove('id_local');
          batch.insert('tb_siembras', map, conflictAlgorithm: ConflictAlgorithm.replace);
          recuperadas++;
          uuidsLocales.add(s.uuid ?? '');
          firmasLocales.add(firma);
        }
      }

      if (recuperadas > 0) {
        await batch.commit(noResult: true);
        // Forzar fsync inmediato en SQLite para sellar los datos recuperados
        try {
          await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
        } catch (_) {}
      }

      // Reconciliar eliminaciones pendientes que puedan haberse perdido
      if (respaldo.containsKey('eliminaciones_pendientes')) {
        final List<dynamic> dels = respaldo['eliminaciones_pendientes'] as List<dynamic>;
        for (var u in dels) {
          final uuidStr = u.toString();
          if (uuidStr.isNotEmpty) {
            try {
              final exists = await db.query(
                'tb_eliminaciones_pendientes',
                where: 'uuid = ?',
                whereArgs: [uuidStr],
                limit: 1,
              );
              if (exists.isEmpty) {
                await db.insert('tb_eliminaciones_pendientes', {
                  'uuid': uuidStr,
                  'fecha_eliminacion': DateTime.now().toIso8601String(),
                }, conflictAlgorithm: ConflictAlgorithm.ignore);
              }
            } catch (_) {}
          }
        }
      }

      // Actualizar el respaldo persistente con la unión completa
      final rowsFinales = await db.query('tb_siembras');
      final List<Siembra> totalesFinales = rowsFinales.map((r) => Siembra.fromMap(r)).toList();
      await resguardarSiembras(siembrasDirectas: totalesFinales, dbExecutor: db);

      final pendientesFinales = totalesFinales.where((s) => s.sincronizado == 0).length;

      final mensaje = recuperadas > 0
          ? '¡Éxito! Se recuperaron $recuperadas siembras que estaban protegidas en el almacenamiento permanente.'
          : 'Todos los registros ($pendientesFinales pendientes) están protegidos de forma segura.';

      return ResultadoRecuperacion(
        totalLocal: totalesFinales.length,
        totalRespaldo: enRespaldo.length,
        recuperadas: recuperadas,
        pendientesSync: pendientesFinales,
        mensaje: mensaje,
        huboRecuperacion: recuperadas > 0,
      );
    } catch (e) {
      debugPrint('[PersistentBackup] Error en verificarYRecuperar: $e');
      return ResultadoRecuperacion(
        totalLocal: 0,
        totalRespaldo: 0,
        recuperadas: 0,
        pendientesSync: 0,
        mensaje: 'Error al verificar respaldo: $e',
        huboRecuperacion: false,
      );
    }
  }

  // === GESTIÓN DE BORRADORES DE FORMULARIO (Si la tablet se apaga mientras digitan) ===

  /// Guarda en almacenamiento permanente el borrador que el operario está digitando
  Future<void> guardarBorrador(String formularioId, Map<String, dynamic> datos) async {
    try {
      final directorios = await _obtenerDirectoriosSeguros();
      if (directorios.isEmpty) return;

      Map<String, dynamic> todosBorradores = {};
      final file = File(p.join(directorios.first.path, _archivoBorradores));

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            todosBorradores = jsonDecode(content) as Map<String, dynamic>;
          }
        } catch (_) {}
      }

      datos['timestamp'] = DateTime.now().toIso8601String();
      todosBorradores[formularioId] = datos;

      await file.writeAsString(jsonEncode(todosBorradores), flush: true);
    } catch (e) {
      debugPrint('[PersistentBackup] Error guardando borrador: $e');
    }
  }

  /// Recupera un borrador no guardado si la tablet se apagó o reinició a mitad de digitación
  Future<Map<String, dynamic>?> obtenerBorrador(String formularioId) async {
    try {
      final directorios = await _obtenerDirectoriosSeguros();
      for (final dir in directorios) {
        final file = File(p.join(dir.path, _archivoBorradores));
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            if (data.containsKey(formularioId)) {
              return data[formularioId] as Map<String, dynamic>?;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Elimina el borrador una vez que la siembra se guardó exitosamente
  Future<void> limpiarBorrador(String formularioId) async {
    try {
      final directorios = await _obtenerDirectoriosSeguros();
      for (final dir in directorios) {
        final file = File(p.join(dir.path, _archivoBorradores));
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            data.remove(formularioId);
            await file.writeAsString(jsonEncode(data), flush: true);
          }
        }
      }
    } catch (_) {}
  }

  /// Consulta el estado de salud y estadísticas del respaldo persistente
  Future<Map<String, dynamic>> obtenerDiagnosticoRespaldo() async {
    final directorios = await _obtenerDirectoriosSeguros();
    final datos = await leerDatosRespaldo();

    final List<Map<String, dynamic>> listaUbicaciones = [];
    for (var d in directorios) {
      final f = File(p.join(d.path, _archivoPrincipal));
      final exists = await f.exists();
      int size = 0;
      DateTime? mod;
      if (exists) {
        try {
          size = await f.length();
          mod = await f.lastModified();
        } catch (_) {}
      }
      listaUbicaciones.add({
        'ruta': f.path,
        'existe': exists,
        'tamano_bytes': size,
        'ultima_modificacion': mod?.toIso8601String(),
      });
    }

    return {
      'activo': datos != null,
      'fecha_ultimo_respaldo': datos?['fecha_respaldo'],
      'total_siembras_respaldo': datos?['total_registros'] ?? 0,
      'pendientes_respaldo': datos?['pendientes_sincronizacion'] ?? 0,
      'ubicaciones': listaUbicaciones,
    };
  }
}

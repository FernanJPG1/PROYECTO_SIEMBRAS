// ============================================================================
// ARCHIVO: local_db.dart
// ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
// Imagínate que este archivo es LA CAJA FUERTE O EL CUADERNO PRINCIPAL de la finca.
// En los invernaderos a veces se va el internet o no entra la señal del celular.
// Si el sembrador anota una siembra y se va la señal o se apaga el teléfono,
// ¡la información jamás se puede perder!
//
// Este archivo crea una base de datos adentro del teléfono (llamada SQLite),
// que funciona igual que un libro de contabilidad empastado con tinta indeleble.
// Todo lo que anotes aquí queda grabado en la memoria del teléfono de inmediato.
//
// ¿QUÉ GUARDA ESTA CAJA FUERTE?
// 1. tb_bloques: Los sectores o invernaderos de la finca (Bloque 01, Bloque 02, etc.).
// 2. tb_variedades: El catálogo de flores (Pompón, Crisantemo, Lirio, Girasol, etc.).
// 3. tb_camas: Las camas o surcos de tierra preparados para sembrar.
// 4. tb_operarios: Los sembradores y cortadores con su nombre y cédula.
// 5. tb_config_agronomica: La cartilla de reglas (cuántas matas caben y cuántos días dura el ciclo).
// 6. tb_siembras: El diario de campo con cada siembra real hecha por los trabajadores.
// 7. tb_eliminaciones_pendientes: Si borraste una siembra por error, aquí se anota para borrarla también en la oficina.
// 8. tb_lirios_187: Los viajes de bulbos de lirio (quién los vendió, en qué contenedor llegaron y qué lote traen).
// 9. tb_lirios_canastas: La cuenta de cuántas canastas de lirios cosechó cada trabajador.
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:app_movil/database/seed_data.dart';
import 'package:app_movil/services/persistent_backup_service.dart';

/// [LocalDatabase]: El Administrador de la Caja Fuerte Local.
/// Se asegura de que haya una sola llave para abrir el cuaderno en todo el celular.
class LocalDatabase {
  // Patrón Singleton: Una sola caja fuerte abierta a la vez para no enredar las cuentas
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  /// Abre la caja fuerte si está cerrada, o entrega la que ya está abierta
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('siembras_local.db');
    return _database!;
  }

  /// Esta función busca la memoria del celular y crea el archivo 'siembras_local.db'
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 14, // Versión 14 del cuaderno (cada mejora le sube un número a la versión)
      onConfigure: (db) async {
        // REGLAS DE SEGURIDAD FÍSICA:
        // 1. foreign_keys = ON: Nadie puede sembrar en una cama que no exista o con una variedad fantasma.
        try {
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (_) {}
        // 2. journal_mode = WAL: Modo libreta rápida. Escribe de inmediato sin frenar el celular.
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {}
        // 3. synchronous = FULL: Si el celular se apaga de golpe por batería baja, no se daña ningún dato.
        try {
          await db.execute('PRAGMA synchronous = FULL');
        } catch (_) {}
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        // Al abrir el cuaderno cada día, revisamos que todas las tablas y reglas estén al día
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL,
              fecha_eliminacion TEXT NOT NULL
            )
          ''');
          // Aplicar configuraciones agronómicas oficiales de la base de datos empresarial (t09_mfamvar y t11_mcolorsseries)
          await _crearTablaConfigAgronomica(db);
          
          // Actualizar variedades existentes según su familia agronómica oficial
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 4050, dias_ciclo = 98, densidad_linea = 28 
            WHERE familia_id = 147 OR UPPER(familia_nombre) LIKE '%POMPON%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 3645, dias_ciclo = 70, densidad_linea = 24 
            WHERE familia_id = 193 OR UPPER(familia_nombre) LIKE '%CREMON%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 3240, dias_ciclo = 70, densidad_linea = 24 
            WHERE familia_id = 148 OR UPPER(familia_nombre) LIKE '%FUJI%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 3402, dias_ciclo = 84, densidad_linea = 15 
            WHERE familia_id = 114 OR UPPER(familia_nombre) LIKE '%MATSUMOTO%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 2916, dias_ciclo = 105, densidad_linea = 143 
            WHERE familia_id IN (199, 255) OR UPPER(familia_nombre) LIKE '%ASIAT%' OR UPPER(familia_nombre) = 'LILIUM (LIRIOS)'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 2430, dias_ciclo = 56, densidad_linea = 63 
            WHERE familia_id IN (204, 309) OR UPPER(familia_nombre) LIKE '%ORIENTAL%' OR UPPER(familia_nombre) LIKE '% OT%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 2430, dias_ciclo = 70, densidad_linea = 12 
            WHERE familia_id = 213 OR UPPER(familia_nombre) LIKE '%SUNFLOWER%' OR UPPER(familia_nombre) LIKE '%GIRASOL%'
          ''');
          await db.execute("UPDATE tb_config_agronomica SET densidad_linea = 15 WHERE UPPER(cultivo) = 'MATSUMOTO'");
          await db.execute("UPDATE tb_config_agronomica SET densidad_linea = 12 WHERE UPPER(cultivo) = 'GIRASOL'");
          await db.execute("UPDATE tb_config_agronomica SET densidad_linea = 143 WHERE UPPER(cultivo) IN ('LA', 'LIRIOS')");
          await db.execute("UPDATE tb_config_agronomica SET densidad_linea = 63 WHERE UPPER(cultivo) IN ('LO', 'OT', 'ORIENTAL')");
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 4151, dias_ciclo = 35, densidad_linea = 28 
            WHERE familia_id = 257 OR UPPER(familia_nombre) LIKE '%STOCK%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 1274, dias_ciclo = 98, densidad_linea = 16 
            WHERE familia_id IN (154, 158) OR UPPER(familia_nombre) LIKE '%CARNATION%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 1760, dias_ciclo = 84, densidad_linea = 18 
            WHERE familia_id = 129 OR UPPER(familia_nombre) LIKE '%SOLIDAGO%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 150, dias_ciclo = 35, densidad_linea = 10 
            WHERE familia_id = 146 OR UPPER(familia_nombre) LIKE '%GERBERA%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 120, dias_ciclo = 84, densidad_linea = 8 
            WHERE familia_id = 155 OR UPPER(familia_nombre) LIKE '%ALSTROEMERIA%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 150, dias_ciclo = 70, densidad_linea = 10 
            WHERE familia_id = 143 OR UPPER(familia_nombre) LIKE '%STATICE%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 150, dias_ciclo = 133, densidad_linea = 10 
            WHERE familia_id = 195 OR UPPER(familia_nombre) LIKE '%LIMONIUM%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 750, dias_ciclo = 70, densidad_linea = 12 
            WHERE familia_id = 262 OR UPPER(familia_nombre) LIKE '%VERONICA%'
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 600, dias_ciclo = 21, densidad_linea = 12 
            WHERE familia_id = 214 OR UPPER(familia_nombre) LIKE '%RANUNCULUS%'
          ''');
          // Asegurar que la columna densidad_linea y es_temporal existan
          try {
            await db.execute('ALTER TABLE tb_variedades ADD COLUMN densidad_linea INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE tb_variedades ADD COLUMN es_temporal INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE tb_config_agronomica ADD COLUMN densidad_linea INTEGER NOT NULL DEFAULT 20');
          } catch (_) {}

          // Asegurar existencia y datos de tb_lirios_187 (Tabla 187 de Access)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_lirios_187 (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              proveedor TEXT NOT NULL,
              contenedor TEXT NOT NULL,
              lote TEXT NOT NULL,
              variedad TEXT,
              variedad_id INTEGER
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_proveedor ON tb_lirios_187 (proveedor)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_contenedor ON tb_lirios_187 (contenedor)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_lote ON tb_lirios_187 (lote)');

          final cRes = await db.rawQuery('SELECT COUNT(*) as total FROM tb_lirios_187');
          final total187 = Sqflite.firstIntValue(cRes) ?? 0;
          if (total187 == 0) {
            final batch187 = db.batch();
            for (var l in kSeedLirios187) {
              batch187.insert('tb_lirios_187', l);
            }
            await batch187.commit(noResult: true);
          }

          // Asegurar existencia de tb_lirios_canastas (Rendimiento por Canastas en Lirios)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_lirios_canastas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT UNIQUE,
              fecha TEXT NOT NULL,
              subgrupo TEXT NOT NULL,
              operario_id INTEGER NOT NULL,
              operario_nombre TEXT NOT NULL,
              cantidad_bulbos INTEGER NOT NULL,
              hora TEXT NOT NULL,
              sincronizado INTEGER NOT NULL DEFAULT 0,
              observaciones TEXT
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_fecha ON tb_lirios_canastas (fecha)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_subgrupo ON tb_lirios_canastas (subgrupo)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_operario ON tb_lirios_canastas (operario_id)');

          // Sincronizar y verificar automáticamente el respaldo persistente antidescarga/apagado
          try {
            await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
          } catch (_) {}
          await PersistentBackupService.instance.verificarYRecuperar(db);
          // Garantizar que solo los Lirios conserven lote, proveedor y cont
          await db.execute('''
            UPDATE tb_siembras
            SET lote = NULL, proveedor = NULL, cont = NULL
            WHERE variedad_id NOT IN (
              SELECT id FROM tb_variedades 
              WHERE UPPER(COALESCE(familia_nombre, '')) LIKE '%LIRIO%' 
                 OR UPPER(COALESCE(familia_nombre, '')) LIKE '%LILIUM%'
                 OR UPPER(COALESCE(familia_nombre, '')) LIKE '%LONGIFLORUM%'
                 OR UPPER(COALESCE(familia_nombre, '')) LIKE '%ASIATICO%'
                 OR UPPER(COALESCE(familia_nombre, '')) LIKE '%ORIENTAL%'
                 OR UPPER(COALESCE(nombre, '')) LIKE '%LIRIO%'
                 OR UPPER(COALESCE(nombre, '')) LIKE '%LILIUM%'
                 OR familia_id IN (199, 204, 309, 255)
            )
          ''');

          // Asegurar existencia y población de tb_sembradores_activos
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_sembradores_activos (
              operario_id INTEGER PRIMARY KEY,
              fecha_asignacion TEXT NOT NULL
            )
          ''');

          final cSembradores = await db.rawQuery('SELECT COUNT(*) as total FROM tb_sembradores_activos');
          final totalSembradores = Sqflite.firstIntValue(cSembradores) ?? 0;
          if (totalSembradores == 0) {
            await db.execute('''
              INSERT OR IGNORE INTO tb_sembradores_activos (operario_id, fecha_asignacion)
              SELECT DISTINCT operario_id, datetime('now', 'localtime')
              FROM tb_siembras
              WHERE operario_id > 0
            ''');
          }
        } catch (_) {}
      },
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await db.execute('DROP TABLE IF EXISTS tb_siembras');
      await db.execute('DROP TABLE IF EXISTS tb_variedades');
      await db.execute('DROP TABLE IF EXISTS tb_camas');
      await db.execute('DROP TABLE IF EXISTS tb_operarios');
      await db.execute('DROP TABLE IF EXISTS tb_bloques');
      await _createDB(db, newVersion);
      return;
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE tb_siembras ADD COLUMN uuid TEXT');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tb_siembras ADD COLUMN estado TEXT NOT NULL DEFAULT 'ACTIVA'");
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tb_siembras ADD COLUMN fecha_fin TEXT');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      await _crearTablaConfigAgronomica(db);
    }

    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            fecha_eliminacion TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_sincronizado ON tb_siembras (sincronizado)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_cama_estado ON tb_siembras (cama_id, estado)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_fecha ON tb_siembras (fecha)');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE tb_variedades ADD COLUMN limite_esquejes INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tb_variedades ADD COLUMN dias_ciclo INTEGER');
      } catch (_) {}
    }

    if (oldVersion < 12) {
      try {
        await _crearTablaConfigAgronomica(db);
      } catch (_) {}
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE tb_variedades ADD COLUMN densidad_linea INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tb_config_agronomica ADD COLUMN densidad_linea INTEGER NOT NULL DEFAULT 20');
      } catch (_) {}
      try {
        final densidadesBase = [
          {'cultivo': 'GENERAL', 'densidad_linea': 20},
          {'cultivo': 'POMPON', 'densidad_linea': 20},
          {'cultivo': 'CREMON', 'densidad_linea': 22},
          {'cultivo': 'GIRASOL', 'densidad_linea': 12},
          {'cultivo': 'MATSUMOTO', 'densidad_linea': 15},
          {'cultivo': 'LIRIOS', 'densidad_linea': 15},
          {'cultivo': 'LA', 'densidad_linea': 15},
          {'cultivo': 'LO', 'densidad_linea': 15},
          {'cultivo': 'OT', 'densidad_linea': 15},
          {'cultivo': 'GERBERA', 'densidad_linea': 20},
          {'cultivo': 'ALSTROEMERIA', 'densidad_linea': 18},
          {'cultivo': 'BANCOS', 'densidad_linea': 25},
          {'cultivo': 'NUCLEOS', 'densidad_linea': 20},
        ];
        for (var d in densidadesBase) {
          await db.update(
            'tb_config_agronomica',
            {'densidad_linea': d['densidad_linea']},
            where: 'cultivo = ?',
            whereArgs: [d['cultivo']],
          );
        }
      } catch (_) {}
    }

    if (oldVersion < 14) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tb_lirios_187 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            proveedor TEXT NOT NULL,
            contenedor TEXT NOT NULL,
            lote TEXT NOT NULL,
            variedad TEXT,
            variedad_id INTEGER
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_proveedor ON tb_lirios_187 (proveedor)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_contenedor ON tb_lirios_187 (contenedor)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_lote ON tb_lirios_187 (lote)');

        final countRes = await db.rawQuery('SELECT COUNT(*) as total FROM tb_lirios_187');
        final total = Sqflite.firstIntValue(countRes) ?? 0;
        if (total == 0) {
          final batch = db.batch();
          for (var l in kSeedLirios187) {
            batch.insert('tb_lirios_187', l);
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}
    }
  }

  Future<void> _crearTablaConfigAgronomica(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tb_config_agronomica (
        cultivo TEXT PRIMARY KEY,
        limite_esquejes INTEGER NOT NULL DEFAULT 3600,
        dias_ciclo INTEGER NOT NULL DEFAULT 75,
        densidad_linea INTEGER NOT NULL DEFAULT 20,
        fecha_actualizacion TEXT
      )
    ''');

    final configs = [
      {'cultivo': 'GENERAL', 'limite_esquejes': 3600, 'dias_ciclo': 75, 'densidad_linea': 20},
      {'cultivo': 'POMPON', 'limite_esquejes': 4050, 'dias_ciclo': 98, 'densidad_linea': 28},
      {'cultivo': 'CREMON', 'limite_esquejes': 3645, 'dias_ciclo': 70, 'densidad_linea': 24},
      {'cultivo': 'FUJI', 'limite_esquejes': 3240, 'dias_ciclo': 70, 'densidad_linea': 24},
      {'cultivo': 'MATSUMOTO', 'limite_esquejes': 3402, 'dias_ciclo': 84, 'densidad_linea': 15},
      {'cultivo': 'LIRIOS', 'limite_esquejes': 2916, 'dias_ciclo': 105, 'densidad_linea': 143},
      {'cultivo': 'LA', 'limite_esquejes': 2916, 'dias_ciclo': 105, 'densidad_linea': 143},
      {'cultivo': 'LO', 'limite_esquejes': 2430, 'dias_ciclo': 56, 'densidad_linea': 63},
      {'cultivo': 'OT', 'limite_esquejes': 2430, 'dias_ciclo': 56, 'densidad_linea': 63},
      {'cultivo': 'ORIENTAL', 'limite_esquejes': 2430, 'dias_ciclo': 56, 'densidad_linea': 63},
      {'cultivo': 'GIRASOL', 'limite_esquejes': 2430, 'dias_ciclo': 70, 'densidad_linea': 12},
      {'cultivo': 'STOCK', 'limite_esquejes': 4151, 'dias_ciclo': 35, 'densidad_linea': 28},
      {'cultivo': 'CARNATIONS', 'limite_esquejes': 1274, 'dias_ciclo': 98, 'densidad_linea': 16},
      {'cultivo': 'SOLIDAGO', 'limite_esquejes': 1760, 'dias_ciclo': 84, 'densidad_linea': 18},
      {'cultivo': 'GERBERA', 'limite_esquejes': 150, 'dias_ciclo': 35, 'densidad_linea': 10},
      {'cultivo': 'ALSTROEMERIA', 'limite_esquejes': 120, 'dias_ciclo': 84, 'densidad_linea': 8},
      {'cultivo': 'STATICE', 'limite_esquejes': 150, 'dias_ciclo': 70, 'densidad_linea': 10},
      {'cultivo': 'LIMONIUM', 'limite_esquejes': 150, 'dias_ciclo': 133, 'densidad_linea': 10},
      {'cultivo': 'VERONICA', 'limite_esquejes': 750, 'dias_ciclo': 70, 'densidad_linea': 12},
      {'cultivo': 'RANUNCULUS', 'limite_esquejes': 600, 'dias_ciclo': 21, 'densidad_linea': 12},
      {'cultivo': 'BANCOS', 'limite_esquejes': 3500, 'dias_ciclo': 45, 'densidad_linea': 25},
      {'cultivo': 'NUCLEOS', 'limite_esquejes': 2000, 'dias_ciclo': 60, 'densidad_linea': 20},
    ];

    for (var cfg in configs) {
      await db.insert('tb_config_agronomica', cfg, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// _createDB: Se ejecuta cuando se instala la app por primera vez.
  /// Dibuja las 9 hojas del cuaderno con sus columnas y llena los datos iniciales de la finca.
  Future _createDB(Database db, int version) async {
    // ------------------------------------------------------------------------
    // HOJA 1: BLOQUES DE LA FINCA (tb_bloques)
    // Aquí se anota cada invernadero o nave (ej: Bloque 01, Bloque 02, etc.).
    // Sirve para saber exactamente en qué parte del terreno estamos parados.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_bloques (
        codigo TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        sector INTEGER
      )
    ''');

    // ------------------------------------------------------------------------
    // HOJA 2: CATÁLOGO DE FLORES Y VARIEDADES (tb_variedades)
    // Cada tipo de flor tiene sus mañas y sus medidas:
    // - nombre: Nombre comercial (ej: Anastasia, Baltica, Siberia).
    // - limite_esquejes: Cuántas matas caben en una cama (para no apretarlas).
    // - dias_ciclo: Cuántos días tarda en florecer y estar lista para el corte.
    // - es_temporal: Si el supervisor creó una flor nueva en campo que aún no está en la oficina.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_variedades (
        id INTEGER PRIMARY KEY,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        estado INTEGER NOT NULL DEFAULT 1,
        familia_id INTEGER,
        familia_nombre TEXT,
        color TEXT,
        color_nombre TEXT,
        subvar_nombre TEXT,
        limite_esquejes INTEGER,
        dias_ciclo INTEGER,
        densidad_linea INTEGER,
        es_temporal INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_variedades_familia ON tb_variedades (familia_id)');

    // ------------------------------------------------------------------------
    // HOJA 3: CAMAS O SURCOS DE TIERRA (tb_camas)
    // Cada cama es una franja de tierra preparada con mallas para sostener los tallos.
    // Está numerada y pertenece a un bloque específico.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_camas (
        id INTEGER PRIMARY KEY,
        cama TEXT NOT NULL,
        bloque TEXT NOT NULL,
        nave TEXT NOT NULL,
        referencia_actual_id INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_camas_bloque ON tb_camas (bloque)');

    // ------------------------------------------------------------------------
    // HOJA 4: OPERARIOS Y TRABAJADORES (tb_operarios)
    // La lista del personal de la finca con nombre y número de cédula.
    // Sirve para saber quién sembró cada cama y calcular cuánto se le debe pagar.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_operarios (
        id INTEGER PRIMARY KEY,
        cedula TEXT NOT NULL,
        nombre_completo TEXT NOT NULL
      )
    ''');

    // ------------------------------------------------------------------------
    // HOJA 5: CARTILLA DE REGLAS AGRONÓMICAS (tb_config_agronomica)
    // Las normas del agrónomo jefe: cuántos esquejes por cama y cuántos días
    // de espera para cada familia de flor (Pompón, Cremón, Girasol, Lirio, etc.).
    // ------------------------------------------------------------------------
    await _crearTablaConfigAgronomica(db);

    // ------------------------------------------------------------------------
    // HOJA 6: DIARIO DE SIEMBRAS EN CAMPO (tb_siembras)
    // ¡EL CORAZÓN DEL SISTEMA! Aquí se anota cada siembra en tiempo real:
    // - fecha: Cuándo se sembró.
    // - variedad_id, cama_id, operario_id: Qué flor, en qué cama y quién la sembró.
    // - cantidad: Cuántas matitas se clavaron en la tierra.
    // - estado: 'ACTIVA' (está creciendo) o 'FINALIZADA' (ya se cortó y la cama quedó libre).
    // - sincronizado: 0 si está pendiente de enviar a la oficina, 1 si ya llegó a la oficina.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_siembras (
        id_local INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        fecha TEXT NOT NULL,
        bloque_codigo TEXT,
        variedad_id INTEGER NOT NULL,
        cama_id INTEGER NOT NULL,
        operario_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        estado TEXT NOT NULL DEFAULT 'ACTIVA',
        fecha_fin TEXT,
        lineas INTEGER,
        observaciones TEXT,
        corte TEXT,
        lote TEXT,
        proveedor TEXT,
        cont TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (variedad_id) REFERENCES tb_variedades (id),
        FOREIGN KEY (cama_id) REFERENCES tb_camas (id),
        FOREIGN KEY (operario_id) REFERENCES tb_operarios (id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_sincronizado ON tb_siembras (sincronizado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_cama_estado ON tb_siembras (cama_id, estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_siembras_fecha ON tb_siembras (fecha)');

    // ------------------------------------------------------------------------
    // HOJA 7: COLA DE ELIMINACIONES PENDIENTES (tb_eliminaciones_pendientes)
    // Si un supervisor borra una siembra en el celular porque se equivocó de cama,
    // aquí se anota el número único (UUID) para borrarla también en la oficina
    // en cuanto el celular vuelva a conectarse al Wi-Fi.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        fecha_eliminacion TEXT NOT NULL
      )
    ''');

    // ------------------------------------------------------------------------
    // HOJA 8: CATÁLOGO DE BULBOS DE LIRIOS IMPORTADOS (tb_lirios_187)
    // En lirios, los bulbos vienen en barco desde Holanda o Chile.
    // Aquí se anota el Proveedor (Onings, Vletter), el Contenedor y el Lote.
    // Al sembrar un lirio, el supervisor escoge estos datos para trazabilidad.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE tb_lirios_187 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proveedor TEXT NOT NULL,
        contenedor TEXT NOT NULL,
        lote TEXT NOT NULL,
        variedad TEXT,
        variedad_id INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_proveedor ON tb_lirios_187 (proveedor)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_contenedor ON tb_lirios_187 (contenedor)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_187_lote ON tb_lirios_187 (lote)');

    // ------------------------------------------------------------------------
    // HOJA 9: CANASTAS COSECHADAS DE LIRIOS (tb_lirios_canastas)
    // Cuenta cuántas canastas o bultos de bulbos descargó y sembró cada trabajador.
    // Sirve para pagar el rendimiento exacto del día.
    // ------------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tb_lirios_canastas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        fecha TEXT NOT NULL,
        subgrupo TEXT NOT NULL,
        operario_id INTEGER NOT NULL,
        operario_nombre TEXT NOT NULL,
        cantidad_bulbos INTEGER NOT NULL,
        hora TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        observaciones TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_fecha ON tb_lirios_canastas (fecha)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_subgrupo ON tb_lirios_canastas (subgrupo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lirios_canastas_operario ON tb_lirios_canastas (operario_id)');

    // --- LLENAR CON LOS DATOS OFICIALES DE LA EMPRESA (Semilla inicial) ---
    final batch = db.batch();

    for (var b in kSeedBloques) {
      batch.insert('tb_bloques', b);
    }
    for (var v in kSeedVariedades) {
      batch.insert('tb_variedades', v);
    }
    for (var o in kSeedOperarios) {
      batch.insert('tb_operarios', o);
    }
    for (var c in kSeedCamas) {
      batch.insert('tb_camas', c);
    }
    for (var l in kSeedLirios187) {
      batch.insert('tb_lirios_187', l);
    }
    for (var s in kSeedSiembras) {
      batch.insert('tb_siembras', s);
    }

    await batch.commit(noResult: true);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tb_sembradores_activos (
        operario_id INTEGER PRIMARY KEY,
        fecha_asignacion TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO tb_sembradores_activos (operario_id, fecha_asignacion)
      SELECT DISTINCT operario_id, datetime('now', 'localtime')
      FROM tb_siembras
      WHERE operario_id > 0
    ''');
  }

  /// CHECKPOINT (ASEGURADOR FÍSICO):
  /// Imagínate que escribiste en un borrador con lápiz. Esta función pasa el borrador
  /// a tinta en la hoja física del libro de contabilidad.
  /// Si el celular se apaga, se queda sin pila o se reinicia de repente,
  /// no se pierde ni una sola letra porque ya quedó sellado en el disco.
  Future<void> checkpoint() async {
    try {
      final db = await database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
  }

  /// Cierra el cuaderno de forma ordenada si se apaga la app
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

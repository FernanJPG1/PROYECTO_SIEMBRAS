import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:app_movil/database/seed_data.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('siembras_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 14,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL,
              fecha_eliminacion TEXT NOT NULL
            )
          ''');
          // Garantizar que ninguna configuración supere 2600 para cultivos estándar
          await db.execute('''
            UPDATE tb_config_agronomica 
            SET limite_esquejes = 2600 
            WHERE limite_esquejes > 2600 AND cultivo NOT IN ('BANCOS')
          ''');
          await db.execute('''
            UPDATE tb_variedades 
            SET limite_esquejes = 2600 
            WHERE limite_esquejes > 2600
          ''');
          // Asegurar que la columna densidad_linea exista
          try {
            await db.execute('ALTER TABLE tb_variedades ADD COLUMN densidad_linea INTEGER');
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

    if (oldVersion < 11) {
      try {
        // Reducir y sincronizar cualquier límite configurado previamente que supere 2600
        await db.execute('''
          UPDATE tb_config_agronomica 
          SET limite_esquejes = 2600 
          WHERE limite_esquejes > 2600
        ''');
        final configsV11 = [
          {'cultivo': 'GENERAL', 'limite_esquejes': 2600, 'dias_ciclo': 75},
          {'cultivo': 'POMPON', 'limite_esquejes': 2600, 'dias_ciclo': 75},
          {'cultivo': 'CREMON', 'limite_esquejes': 2600, 'dias_ciclo': 75},
          {'cultivo': 'LIRIOS', 'limite_esquejes': 2600, 'dias_ciclo': 90},
          {'cultivo': 'LA', 'limite_esquejes': 2600, 'dias_ciclo': 90},
          {'cultivo': 'LO', 'limite_esquejes': 2600, 'dias_ciclo': 90},
          {'cultivo': 'OT', 'limite_esquejes': 2600, 'dias_ciclo': 90},
          {'cultivo': 'MATSUMOTO', 'limite_esquejes': 2600, 'dias_ciclo': 70},
          {'cultivo': 'GERBERA', 'limite_esquejes': 2500, 'dias_ciclo': 120},
          {'cultivo': 'GIRASOL', 'limite_esquejes': 2600, 'dias_ciclo': 65},
          {'cultivo': 'ALSTROEMERIA', 'limite_esquejes': 2600, 'dias_ciclo': 85},
        ];
        for (var c in configsV11) {
          await db.insert('tb_config_agronomica', c, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}
    }

    if (oldVersion < 12) {
      try {
        await _crearTablaConfigAgronomica(db);
        await db.execute('''
          UPDATE tb_config_agronomica 
          SET limite_esquejes = 2600 
          WHERE limite_esquejes > 2600 AND cultivo NOT IN ('BANCOS')
        ''');
        await db.execute('''
          UPDATE tb_variedades 
          SET limite_esquejes = 2600 
          WHERE limite_esquejes > 2600
        ''');
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
        limite_esquejes INTEGER NOT NULL DEFAULT 2600,
        dias_ciclo INTEGER NOT NULL DEFAULT 75,
        densidad_linea INTEGER NOT NULL DEFAULT 20,
        fecha_actualizacion TEXT
      )
    ''');

    final configs = [
      {'cultivo': 'GENERAL', 'limite_esquejes': 2600, 'dias_ciclo': 75, 'densidad_linea': 20},
      {'cultivo': 'POMPON', 'limite_esquejes': 2600, 'dias_ciclo': 75, 'densidad_linea': 20},
      {'cultivo': 'CREMON', 'limite_esquejes': 2600, 'dias_ciclo': 75, 'densidad_linea': 22},
      {'cultivo': 'LIRIOS', 'limite_esquejes': 2600, 'dias_ciclo': 90, 'densidad_linea': 15},
      {'cultivo': 'LA', 'limite_esquejes': 2600, 'dias_ciclo': 90, 'densidad_linea': 15},
      {'cultivo': 'LO', 'limite_esquejes': 2600, 'dias_ciclo': 90, 'densidad_linea': 15},
      {'cultivo': 'OT', 'limite_esquejes': 2600, 'dias_ciclo': 90, 'densidad_linea': 15},
      {'cultivo': 'MATSUMOTO', 'limite_esquejes': 2600, 'dias_ciclo': 70, 'densidad_linea': 15},
      {'cultivo': 'GERBERA', 'limite_esquejes': 2500, 'dias_ciclo': 120, 'densidad_linea': 20},
      {'cultivo': 'GIRASOL', 'limite_esquejes': 2600, 'dias_ciclo': 65, 'densidad_linea': 12},
      {'cultivo': 'ALSTROEMERIA', 'limite_esquejes': 2600, 'dias_ciclo': 85, 'densidad_linea': 18},
      {'cultivo': 'BANCOS', 'limite_esquejes': 3500, 'dias_ciclo': 45, 'densidad_linea': 25},
      {'cultivo': 'NUCLEOS', 'limite_esquejes': 2000, 'dias_ciclo': 60, 'densidad_linea': 20},
    ];

    for (var cfg in configs) {
      await db.insert('tb_config_agronomica', cfg, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Tabla Bloques (t17)
    await db.execute('''
      CREATE TABLE tb_bloques (
        codigo TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        sector INTEGER
      )
    ''');

    // 2. Tabla Variedades (t11_mcolorsseries -> t10_mservar -> t09_mfamvar)
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
        densidad_linea INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_variedades_familia ON tb_variedades (familia_id)');

    // 3. Tabla Camas (t49)
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

    // 4. Tabla Operarios (t159)
    await db.execute('''
      CREATE TABLE tb_operarios (
        id INTEGER PRIMARY KEY,
        cedula TEXT NOT NULL,
        nombre_completo TEXT NOT NULL
      )
    ''');

    // 5. Tabla Configuración Agronómica Independiente
    await _crearTablaConfigAgronomica(db);

    // 6. Tabla Siembras (Offline First con Ciclos y Estado)
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

    // 7. Cola de eliminaciones offline
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        fecha_eliminacion TEXT NOT NULL
      )
    ''');

    // 8. Tabla Catálogo Lirios 187 (t187_salidaslirioscomp + t185 + t23)
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

    // --- Poblar con Seed Data Real Empresarial ---
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

    await batch.commit(noResult: true);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

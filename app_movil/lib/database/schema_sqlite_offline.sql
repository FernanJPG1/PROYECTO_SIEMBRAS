-- ============================================================================
-- PROYECTO SIEMBRAS - ESQUEMA DE BASE DE DATOS SQLITE PARA DISPOSITIVO MÓVIL
-- Base de datos local: siembras_local.db (Arquitectura Offline-First)
-- Versión del esquema: 9
-- Motor: SQLite 3 / sqflite (Android & iOS)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. TABLA: tb_bloques (Catálogo Maestro de Bloques / Invernaderos)
-- Origen remoto: Tabla t17 del sistema empresarial
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_bloques (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  sector INTEGER
);

-- ----------------------------------------------------------------------------
-- 2. TABLA: tb_variedades (Catálogo de Variedades con Jerarquía y Parámetros)
-- Origen remoto: t11_mcolorsseries -> t10_mservar -> t09_mfamvar
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_variedades (
  id INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  estado INTEGER NOT NULL DEFAULT 1,
  familia_id INTEGER,
  familia_nombre TEXT,
  color TEXT,
  color_nombre TEXT,
  subvar_nombre TEXT
);

CREATE INDEX IF NOT EXISTS idx_variedades_familia ON tb_variedades (familia_id);
CREATE INDEX IF NOT EXISTS idx_variedades_nombre ON tb_variedades (nombre);

-- ----------------------------------------------------------------------------
-- 3. TABLA: tb_camas (Catálogo de Camas por Bloque y Nave)
-- Origen remoto: Tabla t49
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_camas (
  id INTEGER PRIMARY KEY,
  cama TEXT NOT NULL,
  bloque TEXT NOT NULL,
  nave TEXT NOT NULL,
  referencia_actual_id INTEGER
);

CREATE INDEX IF NOT EXISTS idx_camas_bloque ON tb_camas (bloque);

-- ----------------------------------------------------------------------------
-- 4. TABLA: tb_operarios (Catálogo de Personal y Sembradores)
-- Origen remoto: Tabla t159
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_operarios (
  id INTEGER PRIMARY KEY,
  cedula TEXT NOT NULL,
  nombre_completo TEXT NOT NULL
);

-- ----------------------------------------------------------------------------
-- 5. TABLA: tb_config_agronomica (Límites de Densidad y Ciclos Agronómicos)
-- Configuración gestionada por el Administrador para validar en campo
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_config_agronomica (
  cultivo TEXT PRIMARY KEY,
  limite_esquejes INTEGER NOT NULL DEFAULT 2600,
  dias_ciclo INTEGER NOT NULL DEFAULT 75,
  fecha_actualizacion TEXT
);

-- ----------------------------------------------------------------------------
-- 6. TABLA: tb_siembras (Registro Operacional de Siembra - Offline First)
-- Permite guardar en el dispositivo sin conexión y sincronizar posteriormente
-- sincronizado: 0 = Pendiente de subir / 1 = Sincronizado con Access
-- estado: 'ACTIVA' (en desarrollo) / 'FINALIZADA' (cama liberada)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_siembras (
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
);

CREATE INDEX IF NOT EXISTS idx_siembras_sincronizado ON tb_siembras (sincronizado);
CREATE INDEX IF NOT EXISTS idx_siembras_cama_estado ON tb_siembras (cama_id, estado);
CREATE INDEX IF NOT EXISTS idx_siembras_fecha ON tb_siembras (fecha);

-- ----------------------------------------------------------------------------
-- 7. TABLA: tb_eliminaciones_pendientes (Cola de Bajas Offline)
-- Si un registro sincronizado se elimina sin conexión, se encola aquí
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_eliminaciones_pendientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL,
  fecha_eliminacion TEXT NOT NULL
);

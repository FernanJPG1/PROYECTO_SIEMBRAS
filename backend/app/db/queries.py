import pyodbc
from typing import List, Optional
from datetime import datetime, timedelta
import logging
from app.models.schemas import (
    Bloque, Cama, FamiliaVariedad, SubvariedadSerie, ColorVariedad,
    Variedad, VariedadCreate, VariedadUpdate, Operario, SiembraSync,
    LirioRegistro187, LiriosCatalogo187
)
import json
from pathlib import Path
from app.db.connection import safe_backup_database, ensure_database_schema

logger = logging.getLogger(__name__)

# --- Bloques (t17_mbloques) ---

def get_bloques(conn: pyodbc.Connection) -> List[Bloque]:
    cursor = conn.cursor()
    query = "SELECT t17_codigo, t17_nombre, t17_sector FROM t17_mbloques ORDER BY t17_codigo"
    try:
        cursor.execute(query)
        rows = cursor.fetchall()
        bloques = []
        for r in rows:
            bloques.append(Bloque(
                codigo=str(r.t17_codigo).strip() if r.t17_codigo else "",
                nombre=str(r.t17_nombre).strip() if r.t17_nombre else "",
                sector=int(r.t17_sector) if r.t17_sector is not None else None
            ))
        return bloques
    except Exception as e:
        logger.error(f"Error en get_bloques: {e}")
        return []

# --- Camas (t49_mcamas) ---

def get_camas(conn: pyodbc.Connection, bloque_codigo: Optional[str] = None) -> List[Cama]:
    cursor = conn.cursor()
    try:
        if bloque_codigo:
            cursor.execute("""
                SELECT t49_interno, t49_cama, t49_bloque, t49_nave, t49_lado, t49_referencia 
                FROM t49_mcamas 
                WHERE t49_bloque = ?
                ORDER BY t49_cama
            """, (bloque_codigo.strip(),))
        else:
            cursor.execute("""
                SELECT t49_interno, t49_cama, t49_bloque, t49_nave, t49_lado, t49_referencia 
                FROM t49_mcamas 
                ORDER BY t49_bloque, t49_cama
            """)
        rows = cursor.fetchall()
        camas = []
        for r in rows:
            cama_cod = str(r.t49_cama).strip() if r.t49_cama else ""
            camas.append(Cama(
                id=int(r.t49_interno) if r.t49_interno else 0,
                codigo=cama_cod,
                cama=cama_cod,
                bloque_codigo=str(r.t49_bloque).strip() if r.t49_bloque else "",
                nave=str(r.t49_nave).strip() if r.t49_nave else "0",
                lado=int(r.t49_lado) if r.t49_lado is not None else None,
                referencia_actual_id=int(r.t49_referencia) if r.t49_referencia else None
            ))
        return camas
    except Exception as e:
        logger.error(f"Error en get_camas: {e}")
        return []

# --- Familias / Especies (Nivel 1: t09_mfamvar) ---

def get_familias(conn: pyodbc.Connection, solo_activas: bool = True) -> List[FamiliaVariedad]:
    cursor = conn.cursor()
    try:
        where_clause = "WHERE t09_estado = 1" if solo_activas else ""
        cursor.execute(f"""
            SELECT t09_interno, t09_codigo, t09_nombre, t09_estado 
            FROM t09_mfamvar 
            {where_clause} 
            ORDER BY t09_nombre
        """)
        rows = cursor.fetchall()
        return [
            FamiliaVariedad(
                id=int(r.t09_interno),
                codigo=str(r.t09_codigo).strip() if r.t09_codigo else "",
                nombre=str(r.t09_nombre).strip() if r.t09_nombre else "",
                estado=int(r.t09_estado) if r.t09_estado is not None else 1
            ) for r in rows
        ]
    except Exception as e:
        logger.error(f"Error en get_familias: {e}")
        return []

# --- Subvariedades / Series (Nivel 2: t10_mservar) ---

def get_subvariedades(conn: pyodbc.Connection, familia_id: Optional[int] = None, solo_activas: bool = True) -> List[SubvariedadSerie]:
    cursor = conn.cursor()
    try:
        conditions = []
        params = []
        if solo_activas:
            conditions.append("t10_estado = 1")
        if familia_id is not None:
            conditions.append("t10_variedad = ?")
            params.append(familia_id)
        
        where_sql = ("WHERE " + " AND ".join(conditions)) if conditions else ""
        query = f"""
            SELECT t10_interno, t10_codigo, t10_nombre, t10_variedad, t10_estado
            FROM t10_mservar
            {where_sql}
            ORDER BY t10_nombre
        """
        cursor.execute(query, params)
        rows = cursor.fetchall()
        return [
            SubvariedadSerie(
                id=int(r.t10_interno),
                codigo=str(r.t10_codigo).strip() if r.t10_codigo else "",
                nombre=str(r.t10_nombre).strip() if r.t10_nombre else "",
                familia_id=int(r.t10_variedad) if r.t10_variedad is not None else None,
                estado=int(r.t10_estado) if r.t10_estado is not None else 1
            ) for r in rows
        ]
    except Exception as e:
        logger.error(f"Error en get_subvariedades: {e}")
        return []

# --- Maestro de Colores (t08_mcolores) ---

def get_colores(conn: pyodbc.Connection) -> List[ColorVariedad]:
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT t08_codigo, t08_nombreesp, t08_nombreing FROM t08_mcolores ORDER BY t08_nombreesp")
        rows = cursor.fetchall()
        return [
            ColorVariedad(
                codigo=str(r.t08_codigo).strip() if r.t08_codigo else "",
                nombre_esp=str(r.t08_nombreesp).strip() if r.t08_nombreesp else None,
                nombre_ing=str(r.t08_nombreing).strip() if r.t08_nombreing else None
            ) for r in rows
        ]
    except Exception as e:
        logger.error(f"Error en get_colores: {e}")
        return []

# --- Referencias Comerciales de Variedad (Nivel 3: t11_mcolorsseries) ---

def get_variedades(conn: pyodbc.Connection, familia_id: Optional[int] = None, solo_activas: bool = True) -> List[Variedad]:
    cursor = conn.cursor()
    try:
        conditions = []
        params = []
        if solo_activas:
            conditions.append("r.t11_estado = 1")
        if familia_id is not None:
            conditions.append("f.t09_interno = ?")
            params.append(familia_id)
        
        where_sql = ("WHERE " + " AND ".join(conditions)) if conditions else ""

        query = f"""
            SELECT 
                r.t11_interno AS id,
                f.t09_codigo, s.t10_codigo, r.t11_codigo,
                r.t11_nombre, r.t11_nomstesp, s.t10_nombre, f.t09_nombre,
                f.t09_interno AS fam_id,
                s.t10_interno AS subvar_id,
                r.t11_color,
                c.t08_nombreesp,
                r.t11_esqxcama,
                r.t11_ciclo_destronque,
                r.t11_estado
            FROM (((t11_mcolorsseries r
            INNER JOIN t10_mservar s ON r.t11_subvar = s.t10_interno)
            INNER JOIN t09_mfamvar f ON s.t10_variedad = f.t09_interno)
            LEFT JOIN t08_mcolores c ON r.t11_color = c.t08_codigo)
            {where_sql}
            ORDER BY f.t09_nombre, r.t11_nombre, s.t10_nombre
        """
        cursor.execute(query, params)
        rows = cursor.fetchall()
        variedades = []

        def resolve_nombre(r_nom, r_nom_esp, s_nom, f_nom):
            r_esp = (r_nom_esp or '').strip()
            if r_esp and r_esp not in ('0', '00', 'N/A', '-'):
                return r_esp
            rc = (r_nom or '').strip()
            if rc and rc not in ('0', '00', 'N/A', '-'):
                return rc
            sc = (s_nom or '').strip()
            if sc and sc not in ('0', '00', 'N/A', '-'):
                return sc
            return (f_nom or '').strip()

        for r in rows:
            cod = (r.t09_codigo or '').strip() + (r.t10_codigo or '').strip() + (r.t11_codigo or '').strip()
            name = resolve_nombre(r.t11_nombre, r.t11_nomstesp, r.t10_nombre, r.t09_nombre)
            color_cod = str(r.t11_color).strip() if r.t11_color else None
            color_nom = str(r.t08_nombreesp).strip() if r.t08_nombreesp else color_cod

            limite_val = None
            if r.t11_esqxcama is not None:
                try:
                    limite_val = int(r.t11_esqxcama)
                except Exception:
                    pass

            ciclo_val = None
            if r.t11_ciclo_destronque is not None:
                try:
                    ciclo_val = int(r.t11_ciclo_destronque)
                except Exception:
                    pass

            variedades.append(Variedad(
                id=int(r.id),
                codigo=cod if cod else "00",
                nombre=name,
                color=color_cod,
                color_nombre=color_nom,
                subvar_id=int(r.subvar_id) if r.subvar_id is not None else None,
                subvar_nombre=str(r.t10_nombre).strip() if r.t10_nombre else None,
                familia_id=int(r.fam_id) if r.fam_id is not None else None,
                familia_nombre=str(r.t09_nombre).strip() if r.t09_nombre else None,
                limite_esquejes=limite_val,
                dias_ciclo=ciclo_val,
                estado=int(r.t11_estado) if r.t11_estado is not None else 1
            ))
        return variedades
    except Exception as e:
        logger.error(f"Error en get_variedades: {e}")
        return []

def crear_variedad(conn: pyodbc.Connection, variedad: VariedadCreate) -> Optional[Variedad]:
    cursor = conn.cursor()
    try:
        fam_id = variedad.familia_id or 147  # Por defecto Pompon si no se especifica

        # Buscar o asociar una subvariedad en t10
        cursor.execute("SELECT TOP 1 t10_interno FROM t10_mservar WHERE t10_variedad = ? AND t10_estado = 1 ORDER BY t10_interno", (fam_id,))
        sub_row = cursor.fetchone()
        subvar_id = sub_row[0] if sub_row else 1

        # Obtener nuevo id para t11
        cursor.execute("SELECT MAX(t11_interno) FROM t11_mcolorsseries")
        max_r = cursor.fetchone()
        next_t11 = (max_r[0] or 0) + 1 if max_r and max_r[0] else 1

        cursor.execute("""
            INSERT INTO t11_mcolorsseries 
            (t11_interno, t11_codigo, t11_subvar, t11_nombre, t11_nomstesp, t11_esqxcama, t11_ciclo_destronque, t11_estado)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        """, (
            next_t11,
            variedad.codigo or "00",
            subvar_id,
            variedad.nombre.strip().upper(),
            variedad.nombre.strip().upper(),
            variedad.limite_esquejes or 3000,
            variedad.dias_ciclo or 90
        ))
        
        conn.commit()
        return Variedad(
            id=next_t11,
            codigo=variedad.codigo or "00",
            nombre=variedad.nombre.strip().upper(),
            subvar_id=subvar_id,
            familia_id=fam_id,
            limite_esquejes=variedad.limite_esquejes or 3000,
            dias_ciclo=variedad.dias_ciclo or 90,
            estado=1
        )
    except Exception as e:
        logger.error(f"Error en crear_variedad: {e}")
        conn.rollback()
        return None

def actualizar_variedad(conn: pyodbc.Connection, variedad_id: int, update: VariedadUpdate) -> Optional[Variedad]:
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT t11_interno, t11_codigo, t11_nombre, t11_estado, t11_esqxcama, t11_ciclo_destronque FROM t11_mcolorsseries WHERE t11_interno = ?", (variedad_id,))
        current = cursor.fetchone()
        if not current:
            return None
        
        nuevo_nombre = update.nombre.strip().upper() if update.nombre else current.t11_nombre
        nuevo_codigo = update.codigo.strip() if update.codigo else current.t11_codigo
        nuevo_estado = update.estado if update.estado is not None else current.t11_estado
        nuevo_limite = update.limite_esquejes if update.limite_esquejes is not None else current.t11_esqxcama
        nuevo_ciclo = update.dias_ciclo if update.dias_ciclo is not None else current.t11_ciclo_destronque

        cursor.execute("""
            UPDATE t11_mcolorsseries 
            SET t11_nombre = ?, t11_nomstesp = ?, t11_codigo = ?, t11_estado = ?, t11_esqxcama = ?, t11_ciclo_destronque = ?
            WHERE t11_interno = ?
        """, (nuevo_nombre, nuevo_nombre, nuevo_codigo, nuevo_estado, nuevo_limite, nuevo_ciclo, variedad_id))
        conn.commit()
        return Variedad(
            id=variedad_id,
            codigo=nuevo_codigo,
            nombre=nuevo_nombre,
            estado=nuevo_estado,
            limite_esquejes=int(nuevo_limite) if nuevo_limite is not None else None,
            dias_ciclo=int(nuevo_ciclo) if nuevo_ciclo is not None else None
        )
    except Exception as e:
        logger.error(f"Error en actualizar_variedad: {e}")
        conn.rollback()
        return None

# --- Operarios (t159_empleados) ---

def get_operarios(conn: pyodbc.Connection, solo_activos: bool = True) -> List[Operario]:
    cursor = conn.cursor()
    try:
        if solo_activos:
            cursor.execute("""
                SELECT t159_interno, t159_cedula, t159_nombre, t159_apellidos, t159_cargo 
                FROM t159_empleados 
                WHERE t159_estado = True 
                ORDER BY t159_nombre
            """)
        else:
            cursor.execute("""
                SELECT t159_interno, t159_cedula, t159_nombre, t159_apellidos, t159_cargo 
                FROM t159_empleados 
                ORDER BY t159_nombre
            """)
        rows = cursor.fetchall()
        operarios = []
        for r in rows:
            nombre = str(r.t159_nombre).strip() if r.t159_nombre else ""
            apellidos = str(r.t159_apellidos).strip() if r.t159_apellidos and str(r.t159_apellidos).strip() != "N/A" else ""
            full_name = f"{nombre} {apellidos}".strip() if apellidos else nombre
            operarios.append(Operario(
                id=int(r.t159_interno) if r.t159_interno else 0,
                cedula=str(r.t159_cedula).strip() if r.t159_cedula else "",
                nombre_completo=full_name,
                cargo=str(r.t159_cargo).strip() if r.t159_cargo else None
            ))
        return operarios
    except Exception as e:
        logger.error(f"Error en get_operarios: {e}")
        return []

# --- Sincronización de Siembras en Ecosistema de 5 Tablas (t49, t31, t50, t51, t102) ---

def insertar_siembras_batch(conn: pyodbc.Connection, siembras: List[SiembraSync]) -> int:
    """
    Sincroniza e inserta en lote las siembras de la app móvil en Microsoft Access.
    - Asegura que la tabla 't_siembras_app' exista (incluso si la BD se cambió por una de un servidor local).
    - Genera respaldo preventivo automático para proteger la base de datos de daños o corrupción.
    - Optimiza los contadores de secuencia (t31, t51, t102, t50) fuera del bucle para no bloquear Access.
    """
    # 1. Asegurar esquema y respaldo preventivo
    ensure_database_schema(conn)
    safe_backup_database()

    cursor = conn.cursor()
    insertadas = 0

    if not siembras:
        return 0

    # 2. Obtener contadores de secuencia iniciales UNA SOLA VEZ fuera del bucle
    # Esto elimina el escaneo repetitivo de tablas pesadas de 180MB en Access.
    try:
        cursor.execute("SELECT MAX(t31_interno) FROM t31_encnovcampo")
        max_31 = cursor.fetchone()
        current_t31 = int(max_31[0]) if max_31 and max_31[0] is not None else 0
    except Exception as ex_seq31:
        logger.warning(f"Error consultando MAX t31: {ex_seq31}")
        current_t31 = 0

    try:
        cursor.execute("SELECT MAX(t51_interno) FROM t51_detnovcampo")
        max_51 = cursor.fetchone()
        current_t51 = int(max_51[0]) if max_51 and max_51[0] is not None else 0
    except Exception as ex_seq51:
        logger.warning(f"Error consultando MAX t51: {ex_seq51}")
        current_t51 = 0

    try:
        cursor.execute("SELECT MAX(t102_interno) FROM t102_composcama")
        max_102 = cursor.fetchone()
        current_t102 = int(max_102[0]) if max_102 and max_102[0] is not None else 0
    except Exception as ex_seq102:
        logger.warning(f"Error consultando MAX t102: {ex_seq102}")
        current_t102 = 0

    try:
        cursor.execute("SELECT MAX(t50_interno) FROM t50_mcomposcama")
        max_50 = cursor.fetchone()
        current_t50 = int(max_50[0]) if max_50 and max_50[0] is not None else 0
    except Exception as ex_seq50:
        logger.warning(f"Error consultando MAX t50: {ex_seq50}")
        current_t50 = 0

    # Cache de camas y variedades para evitar consultas redundantes
    cama_cache = {}
    variedad_cache = {}

    for s in siembras:
        try:
            fecha_dt = datetime.fromtimestamp(s.fecha_siembra / 1000) if s.fecha_siembra else datetime.now()
            fecha_fin_dt = datetime.fromtimestamp(s.fecha_fin / 1000) if s.fecha_fin else None

            # Determinar ID de cama en t49_mcamas si viene por código o por ID
            cama_id = s.cama_id
            cama_cod = s.cama_codigo
            if not cama_id and s.cama_codigo and s.bloque_codigo:
                cache_key = f"{s.bloque_codigo.strip()}_{s.cama_codigo.strip()}"
                if cache_key in cama_cache:
                    cama_id, cama_cod = cama_cache[cache_key]
                else:
                    try:
                        cursor.execute("""
                            SELECT t49_interno, t49_cama 
                            FROM t49_mcamas 
                            WHERE t49_bloque = ? AND t49_cama = ?
                        """, (s.bloque_codigo.strip(), s.cama_codigo.strip()))
                        crow = cursor.fetchone()
                        if crow:
                            cama_id = int(crow[0])
                            cama_cod = str(crow[1]).strip()
                            cama_cache[cache_key] = (cama_id, cama_cod)
                    except Exception as ex_cama:
                        logger.warning(f"Error resolviendo cama por bloque/codigo: {ex_cama}")

            # Obtener tipo de cama de t49_mcamas
            tipo_cama = 2
            if cama_id:
                try:
                    cursor.execute("SELECT t49_tipocama FROM t49_mcamas WHERE t49_interno = ?", (cama_id,))
                    trow = cursor.fetchone()
                    if trow and trow[0] is not None:
                        tipo_cama = int(trow[0])
                except Exception:
                    pass

            # Obtener datos de variedad (nombre, días de ciclo, esquejes por cama)
            var_nombre = ""
            dias_ciclo = 75
            esq_x_cama = s.cantidad_esquejes or 2600
            if s.variedad_id:
                if s.variedad_id in variedad_cache:
                    var_nombre, dias_ciclo, esq_x_cama = variedad_cache[s.variedad_id]
                else:
                    try:
                        cursor.execute("""
                            SELECT t11_nombre, t11_ciclo_destronque, t11_esqxcama 
                            FROM t11_mcolorsseries 
                            WHERE t11_interno = ?
                        """, (s.variedad_id,))
                        vrow = cursor.fetchone()
                        if vrow:
                            var_nombre = str(vrow[0]).strip() if vrow[0] else ""
                            if vrow[1] is not None:
                                dias_ciclo = int(vrow[1])
                            if vrow[2] is not None:
                                esq_x_cama = int(vrow[2])
                            variedad_cache[s.variedad_id] = (var_nombre, dias_ciclo, esq_x_cama)
                    except Exception:
                        pass

            # 3. Verificar si el registro ya existe en t_siembras_app
            cursor.execute("SELECT uuid, estado FROM t_siembras_app WHERE uuid = ?", (s.uuid,))
            existing = cursor.fetchone()
            if existing:
                # Si ya existe, actualizar estado y fecha_fin en t_siembras_app
                cursor.execute("""
                    UPDATE t_siembras_app
                    SET estado = ?, fecha_fin = ?
                    WHERE uuid = ?
                """, (s.estado, fecha_fin_dt, s.uuid))
                
                # Si se finalizó el ciclo, liberar la cama en t49_mcamas y limpiar t50_mcomposcama
                if s.estado == "FINALIZADA" and cama_id:
                    try:
                        cursor.execute("""
                            UPDATE t49_mcamas 
                            SET t49_referencia = NULL, t49_estactual = 7, t49_fecestado = ?, t49_actactual = 7, t49_fecactactual = ?
                            WHERE t49_interno = ?
                        """, (fecha_fin_dt or datetime.now(), fecha_fin_dt or datetime.now(), cama_id))
                    except Exception as ex_free:
                        logger.warning(f"No se pudo liberar cama {cama_id} en t49: {ex_free}")
                    
                    try:
                        cursor.execute("DELETE FROM t50_mcomposcama WHERE t50_cama = ?", (cama_id,))
                    except Exception as ex_del_t50:
                        logger.warning(f"No se pudo limpiar composición t50 para cama {cama_id}: {ex_del_t50}")

                insertadas += 1
                continue

            # ==============================================================
            # 1. TABLA AUDITORÍA / SINCRONIZACIÓN MÓVIL: t_siembras_app
            # ==============================================================
            cursor.execute("""
                INSERT INTO t_siembras_app 
                (uuid, fecha_siembra, fecha_fin, bloque_codigo, cama_id, cama_codigo, variedad_id, operario_id, 
                 cantidad_esquejes, lineas, lote, proveedor, conteo, observaciones, estado)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                s.uuid,
                fecha_dt,
                fecha_fin_dt,
                s.bloque_codigo,
                cama_id,
                cama_cod,
                s.variedad_id,
                s.operario_id,
                s.cantidad_esquejes,
                s.lineas,
                s.lote,
                s.proveedor,
                s.conteo,
                s.observaciones,
                s.estado
            ))

            # Si es siembra ACTIVA y tenemos cama y variedad, registrar en las tablas empresariales
            if s.estado == "ACTIVA" and cama_id and s.variedad_id:
                # Limpiar siembras previas de esta cama que hayan cumplido ciclo o estén finalizadas
                try:
                    cursor.execute("DELETE FROM t50_mcomposcama WHERE t50_cama = ?", (cama_id,))
                except Exception as ex_t50_prev:
                    logger.warning(f"Aviso limpiando composición previa t50 para cama {cama_id}: {ex_t50_prev}")

                try:
                    fecha_limite = fecha_dt - timedelta(days=dias_ciclo)
                    cursor.execute("""
                        DELETE FROM t_siembras_app 
                        WHERE cama_id = ? AND uuid <> ? AND (estado = 'FINALIZADA' OR fecha_siembra <= ?)
                    """, (cama_id, s.uuid, fecha_limite))
                except Exception as ex_app_prev:
                    logger.warning(f"Aviso limpiando siembras de ciclo cumplido en t_siembras_app para cama {cama_id}: {ex_app_prev}")

                # Incrementar contadores en memoria (ultra rápido)
                current_t31 += 1
                current_t51 += 1
                current_t102 += 1
                current_t50 += 1

                # 2. TABLA t31: t31_encnovcampo (Encabezado Novedades de Campo)
                try:
                    cursor.execute("""
                        INSERT INTO t31_encnovcampo (t31_interno, t31_fecha, t31_actividad)
                        VALUES (?, ?, 1)
                    """, (current_t31, fecha_dt))
                except Exception as ex_t31:
                    logger.warning(f"Advertencia insertando en t31: {ex_t31}")

                # 3. TABLA t51: t51_detnovcampo (Detalle Novedad de Campo)
                try:
                    cursor.execute("""
                        INSERT INTO t51_detnovcampo 
                        (t51_interno, t51_encnovedad, t51_cama, t51_referencia, t51_lineas, t51_pltasxlinea, t51_observaciones, t51_tipocama)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        current_t51,
                        current_t31,
                        cama_id,
                        s.variedad_id,
                        float(s.lineas) if s.lineas else 1.0,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        s.observaciones,
                        tipo_cama
                    ))
                except Exception as ex_t51:
                    logger.warning(f"Advertencia insertando en t51: {ex_t51}")

                # 4. TABLA t102: t102_composcama (Historial / Composición Integral)
                try:
                    tallos_esperados = int((s.cantidad_esquejes or 0) * 0.87)
                    cursor.execute("""
                        INSERT INTO t102_composcama 
                        (t102_interno, t102_int_t51, t102_referencia, t102_lineas, t102_pltasxlin, t102_obseraciones, 
                         t102_fechasiembra, t102_densxm2, t102_esqxcama, t102_iniciocorte, t102_tall_esperados, 
                         t102_plantas_alt, t102_cons_stick, t102_lote)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                    """, (
                        current_t102,
                        current_t51,
                        s.variedad_id,
                        float(s.lineas) if s.lineas else 1.0,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        s.observaciones,
                        fecha_dt,
                        100.0,
                        s.cantidad_esquejes or esq_x_cama,
                        dias_ciclo,
                        tallos_esperados,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        s.lote
                    ))
                except Exception as ex_t102:
                    logger.warning(f"Advertencia insertando en t102: {ex_t102}")

                # 5. TABLA t50: t50_mcomposcama (Composición Activa de Cama)
                try:
                    cursor.execute("""
                        INSERT INTO t50_mcomposcama 
                        (t50_interno, t50_cama, t50_referencia, t50_lineas, t50_pltasxlin, t50_fechasiembra, t50_observac, t50_plantas_alt, t50_dias_ic, t50_lote)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                    """, (
                        current_t50,
                        cama_id,
                        s.variedad_id,
                        float(s.lineas) if s.lineas else 1.0,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        fecha_dt,
                        s.observaciones,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        s.lote
                    ))
                except Exception as ex_t50:
                    logger.warning(f"Advertencia insertando en t50: {ex_t50}")

                # 6. TABLA t49: t49_mcamas (Maestro y Estado Actual de la Cama)
                try:
                    obs_resumen = f":{var_nombre};{s.cantidad_esquejes};{s.lineas or 14};{dias_ciclo}"
                    cursor.execute("""
                        UPDATE t49_mcamas 
                        SET t49_referencia = ?, 
                            t49_estactual = 1, 
                            t49_fecestado = ?, 
                            t49_actactual = 1, 
                            t49_fecactactual = ?, 
                            t49_lineas = ?, 
                            t49_pltasxlin = ?, 
                            t49_obaserv = ?
                        WHERE t49_interno = ?
                    """, (
                        s.variedad_id,
                        fecha_dt,
                        fecha_dt,
                        float(s.lineas) if s.lineas else 1.0,
                        float(s.cantidad_esquejes) if s.cantidad_esquejes else 0.0,
                        obs_resumen,
                        cama_id
                    ))
                except Exception as ex_t49:
                    logger.warning(f"Advertencia actualizando t49: {ex_t49}")

            insertadas += 1
        except Exception as e:
            logger.error(f"Error procesando siembra {s.uuid}: {e}")
            # Continuar con las demás siembras del lote

    try:
        conn.commit()
    except Exception as e_commit:
        logger.error(f"Error confirmando transacción de siembras: {e_commit}")
        conn.rollback()
        raise e_commit

    return insertadas

def eliminar_siembras_por_uuid(conn: pyodbc.Connection, uuids: List[str]) -> int:
    """
    Elimina registros de siembra de t_siembras_app según la lista de UUIDs eliminados en la app móvil.
    También limpia la composición activa en t50_mcomposcama si corresponde.
    """
    if not uuids:
        return 0
    cursor = conn.cursor()
    eliminadas = 0
    for u in uuids:
        try:
            cursor.execute("SELECT cama_id FROM t_siembras_app WHERE uuid = ?", (u,))
            row = cursor.fetchone()
            c_id = row[0] if row else None

            cursor.execute("DELETE FROM t_siembras_app WHERE uuid = ?", (u,))
            eliminadas += cursor.rowcount

            if c_id:
                try:
                    cursor.execute("DELETE FROM t50_mcomposcama WHERE t50_cama = ?", (c_id,))
                except Exception:
                    pass
        except Exception as e:
            logger.warning(f"Error eliminando siembra uuid {u}: {e}")
    try:
        conn.commit()
    except Exception:
        pass
    logger.info(f"✓ {eliminadas} siembras eliminadas de Access por sincronización móvil.")
    return eliminadas

# --- Tabla 187: Catálogo de Lirios (Proveedor, Contenedor y Lote) ---

def get_lirios_tabla187(conn: Optional[pyodbc.Connection] = None) -> LiriosCatalogo187:
    """
    Obtiene los registros de la Tabla 187 (t187_salidaslirioscomp) con su proveedor (t185 / t23)
    y contenedor (t185), extrayendo listas únicas para selectores desplegables en la app móvil.
    """
    registros: List[LirioRegistro187] = []
    
    if conn:
        try:
            cursor = conn.cursor()
            query = """
                SELECT DISTINCT 
                    t23.t23_nombre AS proveedor,
                    CSTR(t185.t185_num_contenedor) AS contenedor,
                    t187.t187_lote AS lote,
                    t11.t11_nomsting AS variedad,
                    t11.t11_interno AS variedad_id
                FROM (
                    (
                        (t187_salidaslirioscomp t187
                        INNER JOIN t185_entradaliriosprinc t185 ON t187.t187_num_entrada = t185.t185_num_entrada)
                        LEFT JOIN t23_msucterceros t23 ON t185.t185_proveedor = t23.t23_interno
                    )
                    LEFT JOIN t102_composcama t102 ON t187.t187_variedad = t102.t102_interno
                )
                LEFT JOIN t11_mcolorsseries t11 ON t102.t102_referencia = t11.t11_interno
                WHERE t187.t187_lote IS NOT NULL AND t23.t23_nombre IS NOT NULL
                ORDER BY t23.t23_nombre, CSTR(t185.t185_num_contenedor), t187.t187_lote
            """
            cursor.execute(query)
            rows = cursor.fetchall()
            for r in rows:
                registros.append(LirioRegistro187(
                    proveedor=str(r.proveedor).strip() if r.proveedor else "",
                    contenedor=str(r.contenedor).strip() if r.contenedor else "",
                    lote=str(r.lote).strip() if r.lote else "",
                    variedad=str(r.variedad).strip() if r.variedad else None,
                    variedad_id=int(r.variedad_id) if r.variedad_id is not None else None
                ))
        except Exception as e:
            logger.warning(f"Error consultando t187 en Access, recurriendo a cache JSON: {e}")

    # Si no se obtuvieron filas de Access o no hay conexión, cargar desde el JSON exportado
    if not registros:
        json_path = Path(__file__).parent / "lirios_tabla187.json"
        if json_path.exists():
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    raw_items = json.load(f)
                    for item in raw_items:
                        registros.append(LirioRegistro187(**item))
            except Exception as e_json:
                logger.error(f"Error cargando lirios_tabla187.json: {e_json}")

    # Extraer conjuntos únicos ordenados
    proveedores = sorted(list(set(r.proveedor for r in registros if r.proveedor)))
    contenedores = sorted(
        list(set(r.contenedor for r in registros if r.contenedor)),
        key=lambda x: int(x) if x.isdigit() else 999
    )
    lotes = sorted(list(set(r.lote for r in registros if r.lote)))

    return LiriosCatalogo187(
        proveedores=proveedores,
        contenedores=contenedores,
        lotes=lotes,
        registros=registros
    )




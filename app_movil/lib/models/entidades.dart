// ============================================================================
// 🌸 ARCHIVO: entidades.dart (EL DICCIONARIO DE LA FINCA EN EL CELULAR)
// ============================================================================
// 📖 ¿QUÉ ES ESTE ARCHIVO Y PARA QUÉ SIRVE? (Explicado para que cualquiera lo entienda)
//
// Imagínate que este archivo es como el DICCIONARIO o la LIBRETA DE MODELOS de la finca Buenavista.
// Aquí le enseñamos al celular qué significa cada cosa que existe en el mundo real del campo:
//
// 1. 🌱 ¿Qué es un Bloque? -> Es el invernadero o pedazo grande de tierra (ej: Bloque 003).
// 2. 🛏️ ¿Qué es una Cama? -> Es la franja o hilera larga de tierra donde se meten las plantas (ej: Cama 001A).
// 3. 🌺 ¿Qué es una Variedad? -> Es el nombre y tipo de la flor (ej: Abriana, Alma, Anastacia).
// 4. 👷 ¿Qué es un Operario? -> Es la persona de campo que trabaja sembrando (con su nombre y su cédula).
// 5. 📋 ¿Qué es una Siembra? -> Es la hoja de trabajo oficial donde anotamos quién sembró, qué flor metió,
//                             en qué cama, cuántas líneas hizo y cuántos tallos quedaron sembrados.
// 6. 🧺 ¿Qué es una Canasta? -> En los Lirios, varias personas siembran juntas en la misma cama.
//                              Por eso a cada trabajador se le cuentan las canastas de bulbos que recibe y siembra.
// 7. 🏆 ¿Qué es un Rendimiento? -> Es la cuenta de quién trabajó más rápido para darle su medalla (Oro, Plata, Bronce).
//
// Sin este archivo, el teléfono no sabría qué es una flor, ni qué es una cama, ni quién está trabajando.
// ============================================================================

/// 🌱 CLASE BLOQUE
/// Representa un lote grande o invernadero dentro de la finca.
/// Ejemplo: El Bloque 003 del Sector 1.
class Bloque {
  /// El número o código oficial del bloque (ejemplo: "003")
  final String codigo;

  /// El nombre con el que todos en la finca conocen el bloque (ejemplo: "Bloque 3")
  final String nombre;

  /// El sector o parte de la finca donde queda el bloque (ejemplo: Sector 1)
  final int? sector;

  Bloque({required this.codigo, required this.nombre, this.sector});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bloque && runtimeType == other.runtimeType && codigo == other.codigo;

  @override
  int get hashCode => codigo.hashCode;

  /// Convierte los datos del bloque en una lista de palabras para guardarlo en la memoria del teléfono
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'sector': sector,
    };
  }

  /// Lee los datos guardados en la memoria del teléfono y vuelve a crear el Bloque
  factory Bloque.fromMap(Map<String, dynamic> map) {
    return Bloque(
      codigo: map['codigo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      sector: map['sector'],
    );
  }
}

/// 🌺 CLASE VARIEDAD
/// Representa el tipo o especie de flor que se va a sembrar en la cama.
/// Ejemplo: "ABRIANA CF", "ALMA CF", "ANASTACIA", "LIRIO BRINDISI".
class Variedad {
  /// Número único en la base de datos para identificar esta flor
  final int id;

  /// Código interno de la empresa (ej: "051011103")
  final String codigo;

  /// Nombre comercial de la flor (ej: "ABRIANA CF")
  final String nombre;

  /// 1 si está activa para sembrar hoy, 0 si ya no se siembra en la finca
  final int estado;

  /// Código de la familia a la que pertenece (ej: 147 para Pompón, 193 para Cremón)
  final int? familiaId;

  /// Nombre de la familia (ej: "POMPÓN", "CREMÓN", "LIRIOS")
  final String? familiaNombre;

  /// Código del color de los pétalos
  final String? color;

  /// Nombre del color en español (ej: "BLANCO", "AMARILLO", "ROSADO")
  final String? colorNombre;

  /// Subvariedad o tipo especial si aplica
  final String? subvarNombre;

  /// Límite máximo de esquejes o tallos que caben en una cama de esta flor (ej: 3.645 o 4.050)
  final int? limiteEsquejes;

  /// Cuántos días tarda la flor desde que se siembra hasta que está lista para cortar (ej: 70 o 98 días)
  final int? diasCiclo;

  /// Cuántos tallos o esquejes se siembran en una sola línea de la cama (ej: 22 o 24 o 28)
  final int? densidadLinea;

  /// Si es una variedad nueva creada en el celular por la supervisora que aún no está en la oficina
  final bool esTemporal;

  Variedad({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.estado = 1,
    this.familiaId,
    this.familiaNombre,
    this.color,
    this.colorNombre,
    this.subvarNombre,
    this.limiteEsquejes,
    this.diasCiclo,
    this.densidadLinea,
    this.esTemporal = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Variedad && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'estado': estado,
      'familia_id': familiaId,
      'familia_nombre': familiaNombre,
      'color': color,
      'color_nombre': colorNombre,
      'subvar_nombre': subvarNombre,
      'limite_esquejes': limiteEsquejes,
      'dias_ciclo': diasCiclo,
      'densidad_linea': densidadLinea,
      'es_temporal': esTemporal ? 1 : 0,
    };
  }

  factory Variedad.fromMap(Map<String, dynamic> map) {
    final int? rawId = map['id'] != null ? int.tryParse(map['id'].toString()) : null;
    final bool isTemp = map['es_temporal'] == 1 ||
        map['es_temporal'] == true ||
        (rawId != null && rawId < 0);
    return Variedad(
      id: rawId ?? 0,
      codigo: map['codigo']?.toString() ?? '00',
      nombre: map['nombre']?.toString() ?? '',
      estado: map['estado'] ?? 1,
      familiaId: map['familia_id'],
      familiaNombre: map['familia_nombre']?.toString(),
      color: map['color']?.toString(),
      colorNombre: map['color_nombre']?.toString(),
      subvarNombre: map['subvar_nombre']?.toString(),
      limiteEsquejes: map['limite_esquejes'] != null ? int.tryParse(map['limite_esquejes'].toString()) : null,
      diasCiclo: map['dias_ciclo'] != null ? int.tryParse(map['dias_ciclo'].toString()) : null,
      densidadLinea: map['densidad_linea'] != null ? int.tryParse(map['densidad_linea'].toString()) : null,
      esTemporal: isTemp,
    );
  }

  Variedad copyWith({
    int? id,
    String? codigo,
    String? nombre,
    int? estado,
    int? familiaId,
    String? familiaNombre,
    String? color,
    String? colorNombre,
    String? subvarNombre,
    int? limiteEsquejes,
    int? diasCiclo,
    int? densidadLinea,
    bool? esTemporal,
  }) {
    return Variedad(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      familiaId: familiaId ?? this.familiaId,
      familiaNombre: familiaNombre ?? this.familiaNombre,
      color: color ?? this.color,
      colorNombre: colorNombre ?? this.colorNombre,
      subvarNombre: subvarNombre ?? this.subvarNombre,
      limiteEsquejes: limiteEsquejes ?? this.limiteEsquejes,
      diasCiclo: diasCiclo ?? this.diasCiclo,
      densidadLinea: densidadLinea ?? this.densidadLinea,
      esTemporal: esTemporal ?? this.esTemporal,
    );
  }
}

/// 🛏️ CLASE CAMA
/// Representa una cama de siembra individual dentro de un bloque.
/// Ejemplo: Cama "001A" dentro del Bloque "003".
class Cama {
  /// Número de registro interno de la cama
  final int id;

  /// Nombre o placa de la cama en el invernadero (ej: "001A")
  final String cama;

  /// Código del bloque donde está ubicada esta cama (ej: "003")
  final String bloque;

  /// Número de la nave o sección techada del invernadero
  final String nave;

  /// Referencia técnica si la cama tiene una siembra previa registrada
  final int? referenciaActualId;

  Cama({
    required this.id,
    required this.cama,
    required this.bloque,
    required this.nave,
    this.referenciaActualId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cama && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cama': cama,
      'bloque': bloque,
      'nave': nave,
      'referencia_actual_id': referenciaActualId,
    };
  }

  factory Cama.fromMap(Map<String, dynamic> map) {
    return Cama(
      id: map['id'],
      cama: (map['cama'] ?? map['codigo'])?.toString() ?? '',
      bloque: (map['bloque'] ?? map['bloque_codigo'])?.toString() ?? '',
      nave: map['nave']?.toString() ?? '0',
      referenciaActualId: map['referencia_actual_id'],
    );
  }
}

/// 👷 CLASE OPERARIO
/// Representa a la persona trabajadora de campo que realiza la labor de siembra.
/// Cada operario tiene su nombre y cédula para saber exactamente quién sembró cada cama.
class Operario {
  /// Número de registro en el sistema
  final int id;

  /// Número de cédula de ciudadanía del trabajador (ej: "12566001")
  final String cedula;

  /// Nombre y apellidos completos del sembrador (ej: "ALBA LUCIA CASTAÑEDA GAVIRIA")
  final String nombreCompleto;

  Operario({required this.id, required this.cedula, required this.nombreCompleto});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Operario && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cedula': cedula,
      'nombre_completo': nombreCompleto,
    };
  }

  factory Operario.fromMap(Map<String, dynamic> map) {
    return Operario(
      id: map['id'],
      cedula: map['cedula']?.toString() ?? '',
      nombreCompleto: (map['nombre_completo'] ?? map['nombre'])?.toString() ?? '',
    );
  }
}

/// Configuración Agronómica Independiente fijada por el Administrador
class ConfigAgronomica {
  final String cultivo; // 'GENERAL', 'POMPON', 'LIRIOS', etc.
  final int limiteEsquejes; // Límite máximo de esquejes o plantas por cama
  final int diasCiclo;      // Duración estimada del ciclo en días
  final int densidadLinea;  // Densidad por línea (factor multiplicador para # líneas)
  final String? fechaActualizacion;

  ConfigAgronomica({
    required this.cultivo,
    required this.limiteEsquejes,
    required this.diasCiclo,
    this.densidadLinea = 20,
    this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'cultivo': cultivo.toUpperCase(),
      'limite_esquejes': limiteEsquejes,
      'dias_ciclo': diasCiclo,
      'densidad_linea': densidadLinea,
      'fecha_actualizacion': fechaActualizacion,
    };
  }

  factory ConfigAgronomica.fromMap(Map<String, dynamic> map) {
    return ConfigAgronomica(
      cultivo: (map['cultivo']?.toString() ?? 'GENERAL').toUpperCase(),
      limiteEsquejes: int.tryParse(map['limite_esquejes'].toString()) ?? 3600,
      diasCiclo: int.tryParse(map['dias_ciclo'].toString()) ?? 70,
      densidadLinea: int.tryParse(map['densidad_linea']?.toString() ?? '') ?? 20,
      fechaActualizacion: map['fecha_actualizacion']?.toString(),
    );
  }
}

/// Registro del Catálogo de la Tabla 187 (Lirios: Proveedor, Contenedor, Lote, Variedad)
class LirioItem187 {
  final String proveedor;
  final String contenedor;
  final String lote;
  final String? variedad;
  final int? variedadId;

  LirioItem187({
    required this.proveedor,
    required this.contenedor,
    required this.lote,
    this.variedad,
    this.variedadId,
  });

  Map<String, dynamic> toMap() {
    return {
      'proveedor': proveedor,
      'contenedor': contenedor,
      'lote': lote,
      'variedad': variedad,
      'variedad_id': variedadId,
    };
  }

  factory LirioItem187.fromMap(Map<String, dynamic> map) {
    return LirioItem187(
      proveedor: map['proveedor']?.toString() ?? '',
      contenedor: map['contenedor']?.toString() ?? '',
      lote: map['lote']?.toString() ?? '',
      variedad: map['variedad']?.toString(),
      variedadId: map['variedad_id'] is int
          ? map['variedad_id']
          : int.tryParse(map['variedad_id']?.toString() ?? ''),
    );
  }
}

/// 📋 CLASE SIEMBRA (LA PLANILLA DE TRABAJO PRINCIPAL)
/// Es la planilla oficial donde queda guardado cada trabajo hecho en la finca:
/// Quién sembró, qué flor se puso, en qué cama, cuántos tallos y qué día.
class Siembra {
  /// Número de orden en la memoria del celular
  final int? idLocal;

  /// Código único universal para que nunca se confunda con otra siembra
  final String? uuid;

  /// Día en que se hizo la siembra (ej: "08/10/2026")
  final String fecha;

  /// Invernadero o lote donde se sembró (ej: "003")
  final String? bloqueCodigo;

  /// Identificador de la flor sembrada
  final int variedadId;

  /// Identificador de la cama de tierra
  final int camaId;

  /// Identificador del trabajador que hizo la labor
  final int operarioId;

  /// Total de esquejes, tallos o bulbos sembrados en la cama (ej: 1.353 unidades)
  final int cantidad;
  
  /// Estado de la siembra:
  /// - 'ACTIVA': La flor está sembrada y creciendo en la tierra.
  /// - 'FINALIZADA': La flor ya se cosechó y la cama quedó limpia para volver a sembrar.
  final String estado;

  /// Fecha en que se cortó la flor o se destroncó la cama
  final String? fechaFin;

  /// Cuántas líneas de largo se sembraron en la cama (ej: 68 o 123 líneas)
  final int? lineas;

  /// Anotaciones especiales:
  /// Si sembró el Lado A, Lado B, Cama Completa, o si terminó su lado y pasó al otro lado
  final String? observaciones;

  /// Número de corte agronómico
  final String? corte;

  /// Número de lote de compra del bulbo o esqueje
  final String? lote;

  /// Nombre de la empresa que vendió el bulbo (ej: Steenvoorden, Onings)
  final String? proveedor;

  /// Número de contenedor de importación en el que llegaron los bulbos
  final String? cont;

  /// 0 = guardado solo en el celular (pendiente por enviar)
  /// 1 = ya enviado con éxito a la oficina central
  final int sincronizado;

  Siembra({
    this.idLocal,
    this.uuid,
    required this.fecha,
    this.bloqueCodigo,
    required this.variedadId,
    required this.camaId,
    required this.operarioId,
    required this.cantidad,
    this.estado = 'ACTIVA',
    this.fechaFin,
    this.lineas,
    this.observaciones,
    this.corte,
    this.lote,
    this.proveedor,
    this.cont,
    required this.sincronizado,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'uuid': uuid,
      'fecha': fecha,
      'bloque_codigo': bloqueCodigo,
      'variedad_id': variedadId,
      'cama_id': camaId,
      'operario_id': operarioId,
      'cantidad': cantidad,
      'estado': estado,
      'fecha_fin': fechaFin,
      'lineas': lineas,
      'observaciones': observaciones,
      'corte': corte,
      'lote': lote,
      'proveedor': proveedor,
      'cont': cont,
      'sincronizado': sincronizado,
    };
    if (idLocal != null) {
      map['id_local'] = idLocal;
    }
    return map;
  }

  factory Siembra.fromMap(Map<String, dynamic> map) {
    return Siembra(
      idLocal: map['id_local'],
      uuid: map['uuid']?.toString(),
      fecha: map['fecha'],
      bloqueCodigo: map['bloque_codigo']?.toString(),
      variedadId: map['variedad_id'],
      camaId: map['cama_id'],
      operarioId: map['operario_id'],
      cantidad: map['cantidad'],
      estado: map['estado']?.toString() ?? 'ACTIVA',
      fechaFin: map['fecha_fin']?.toString(),
      lineas: map['lineas'],
      observaciones: map['observaciones'],
      corte: map['corte'],
      lote: map['lote'],
      proveedor: map['proveedor'],
      cont: map['cont'],
      sincronizado: map['sincronizado'],
    );
  }

  Siembra copyWith({
    int? idLocal,
    String? uuid,
    String? fecha,
    String? bloqueCodigo,
    int? variedadId,
    int? camaId,
    int? operarioId,
    int? cantidad,
    String? estado,
    String? fechaFin,
    int? lineas,
    String? observaciones,
    String? corte,
    String? lote,
    String? proveedor,
    String? cont,
    int? sincronizado,
  }) {
    return Siembra(
      idLocal: idLocal ?? this.idLocal,
      uuid: uuid ?? this.uuid,
      fecha: fecha ?? this.fecha,
      bloqueCodigo: bloqueCodigo ?? this.bloqueCodigo,
      variedadId: variedadId ?? this.variedadId,
      camaId: camaId ?? this.camaId,
      operarioId: operarioId ?? this.operarioId,
      cantidad: cantidad ?? this.cantidad,
      estado: estado ?? this.estado,
      fechaFin: fechaFin ?? this.fechaFin,
      lineas: lineas ?? this.lineas,
      observaciones: observaciones ?? this.observaciones,
      corte: corte ?? this.corte,
      lote: lote ?? this.lote,
      proveedor: proveedor ?? this.proveedor,
      cont: cont ?? this.cont,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }
}

/// 🏆 CLASE RENDIMIENTO OPERARIO (EL PODIO DE HONOR Y MEDALLAS)
/// Es la calculadora del campeonato de siembra.
/// Cuenta cuántos tallos sembró cada trabajador en el día o en la semana,
/// calcula su promedio por cama y los ordena del #1 al último para entregar
/// las medallas de honor:
/// - 🥇 Medalla de Oro al sembrador más rápido
/// - 🥈 Medalla de Plata al segundo puesto
/// - 🥉 Medalla de Bronce al tercer puesto
class RendimientoOperario {
  /// Datos personales del trabajador (nombre y cédula)
  final Operario operario;

  /// Gran total de tallos o esquejes que sembró
  final int totalTallos;

  /// Cuántas camas completó o participó
  final int totalCamas;

  /// Cuántas líneas de largo sembró en total
  final int totalLineas;

  /// Cuántos días estuvo trabajando en el campo
  final int diasTrabajados;

  /// Promedio de tallos que siembra en cada cama
  final double promedioTallosPorCama;

  /// Promedio de tallos que siembra cada día
  final double promedioTallosPorDia;

  /// Qué porcentaje de todo el trabajo de la finca hizo este trabajador (ej: 18.5%)
  final double porcentajeTotal;

  /// Puesto en la tabla de clasificación (1 = Primer lugar, 2 = Segundo lugar...)
  final int posicion;

  RendimientoOperario({
    required this.operario,
    required this.totalTallos,
    required this.totalCamas,
    this.totalLineas = 0,
    this.diasTrabajados = 1,
    required this.promedioTallosPorCama,
    required this.promedioTallosPorDia,
    required this.porcentajeTotal,
    this.posicion = 1,
  });

  /// 🧮 FUNCIÓN MATEMÁTICA: CALCULAR EL PODIO
  /// Toma todas las siembras de la semana y hace la suma exacta para cada persona.
  /// REGLA DE ORO DE LA FINCA:
  /// No se cuentan las siembras de Plantas Madre, Bancos o Núcleos porque son
  /// trabajos comunitarios que no miden velocidad de operario individual.
  static List<RendimientoOperario> calcular({
    required List<Siembra> siembras,
    required List<Operario> operarios,
    List<Variedad>? variedades,
  }) {
    if (siembras.isEmpty) return [];

    // Excluir siembras sin sembrador (id <= 0) o de Plantas Madre, Bancos y Núcleos
    final siembrasValidas = siembras.where((s) {
      if (s.operarioId <= 0) return false;
      final obs = (s.observaciones ?? '').toUpperCase();
      final corte = (s.corte ?? '').toUpperCase();
      if (obs.contains('MADRE') || obs.contains('BANCO') || obs.contains('NÚCLEO') || obs.contains('NUCLEO') ||
          corte.contains('MADRE') || corte.contains('BANCO') || corte.contains('NÚCLEO') || corte.contains('NUCLEO')) {
        return false;
      }
      if (variedades != null && variedades.isNotEmpty) {
        final v = variedades.firstWhere((varItem) => varItem.id == s.variedadId, orElse: () => Variedad(id: 0, codigo: '', nombre: ''));
        final fam = (v.familiaNombre ?? '').toUpperCase();
        final nom = v.nombre.toUpperCase();
        if (fam.contains('MADRE') || fam.contains('BANCO') || fam.contains('NÚCLEO') || fam.contains('NUCLEO') ||
            nom.contains('MADRE') || nom.contains('BANCO') || nom.contains('NÚCLEO') || nom.contains('NUCLEO')) {
          return false;
        }
      }
      return true;
    }).toList();

    if (siembrasValidas.isEmpty) return [];

    final totalTallosGlobal = siembrasValidas.fold<int>(0, (sum, s) => sum + s.cantidad);

    // Agrupar siembras por operarioId
    final Map<int, List<Siembra>> porOperario = {};
    for (var s in siembrasValidas) {
      porOperario.putIfAbsent(s.operarioId, () => []).add(s);
    }

    final List<RendimientoOperario> rendimientos = [];

    porOperario.forEach((operarioId, lista) {
      final op = operarios.firstWhere(
        (o) => o.id == operarioId,
        orElse: () => Operario(
          id: operarioId,
          cedula: 'S/C',
          nombreCompleto: 'Operario #$operarioId',
        ),
      );

      final tallos = lista.fold<int>(0, (sum, s) => sum + s.cantidad);
      final camas = lista.length;
      final lineas = lista.fold<int>(0, (sum, s) => sum + (s.lineas ?? 0));
      final dias = lista.map((s) => s.fecha).toSet().length;

      final promCama = camas > 0 ? (tallos / camas) : 0.0;
      final promDia = dias > 0 ? (tallos / dias) : 0.0;
      final pct = totalTallosGlobal > 0 ? (tallos / totalTallosGlobal) * 100.0 : 0.0;

      rendimientos.add(
        RendimientoOperario(
          operario: op,
          totalTallos: tallos,
          totalCamas: camas,
          totalLineas: lineas,
          diasTrabajados: dias > 0 ? dias : 1,
          promedioTallosPorCama: promCama,
          promedioTallosPorDia: promDia,
          porcentajeTotal: pct,
        ),
      );
    });

    // Ordenar de mayor a menor rendimiento por total de tallos
    rendimientos.sort((a, b) => b.totalTallos.compareTo(a.totalTallos));

    // Asignar posición en el ranking (1, 2, 3...)
    return List.generate(rendimientos.length, (index) {
      final r = rendimientos[index];
      return RendimientoOperario(
        operario: r.operario,
        totalTallos: r.totalTallos,
        totalCamas: r.totalCamas,
        totalLineas: r.totalLineas,
        diasTrabajados: r.diasTrabajados,
        promedioTallosPorCama: r.promedioTallosPorCama,
        promedioTallosPorDia: r.promedioTallosPorDia,
        porcentajeTotal: r.porcentajeTotal,
        posicion: index + 1,
      );
    });
  }
}

/// 🧺 CLASE CANASTA LIRIO
/// En el cultivo de Lirios, varias personas siembran juntas en la misma cama.
/// Para medir cuánto sembró cada persona, el supervisor le entrega CANASTAS con bulbos:
/// - En Lirio LA: canastas de 400, 425 o 450 bulbos.
/// - En Lirio LO/OT (Orientales): canastas de 200, 225 o 250 bulbos.
/// Cada vez que un operario recibe una canasta, se anota en esta clase.
class CanastaLirio {
  /// Número de orden en el celular
  final int? id;

  /// Código único universal de la canasta
  final String uuid;

  /// Día en que se entregó la canasta
  final String fecha;

  /// Tipo de Lirio ('LA', 'LO' u 'OT')
  final String subgrupo;

  /// Identificador del operario que recibió la canasta
  final int operarioId;

  /// Nombre del operario que recibió la canasta
  final String operarioNombre;

  /// Cuántos bulbos venían dentro de la canasta (ej: 400, 425, 450)
  final int cantidadBulbos;

  /// Hora exacta en que se entregó (ej: "10:15 AM")
  final String hora;

  /// 0 = guardado solo en el celular, 1 = enviado a la oficina
  final int sincronizado;

  /// Si sobraron bulbos o hubo alguna novedad
  final String? observaciones;

  CanastaLirio({
    this.id,
    required this.uuid,
    required this.fecha,
    required this.subgrupo,
    required this.operarioId,
    required this.operarioNombre,
    required this.cantidadBulbos,
    required this.hora,
    this.sincronizado = 0,
    this.observaciones,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'fecha': fecha,
      'subgrupo': subgrupo,
      'operario_id': operarioId,
      'operario_nombre': operarioNombre,
      'cantidad_bulbos': cantidadBulbos,
      'hora': hora,
      'sincronizado': sincronizado,
      if (observaciones != null) 'observaciones': observaciones,
    };
  }

  factory CanastaLirio.fromMap(Map<String, dynamic> map) {
    return CanastaLirio(
      id: map['id'],
      uuid: map['uuid']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
      subgrupo: map['subgrupo']?.toString() ?? 'LA',
      operarioId: map['operario_id'] is int ? map['operario_id'] : int.tryParse(map['operario_id']?.toString() ?? '0') ?? 0,
      operarioNombre: map['operario_nombre']?.toString() ?? '',
      cantidadBulbos: map['cantidad_bulbos'] is int ? map['cantidad_bulbos'] : int.tryParse(map['cantidad_bulbos']?.toString() ?? '0') ?? 0,
      hora: map['hora']?.toString() ?? '',
      sincronizado: map['sincronizado'] is int ? map['sincronizado'] : int.tryParse(map['sincronizado']?.toString() ?? '0') ?? 0,
      observaciones: map['observaciones']?.toString(),
    );
  }
}

class Bloque {
  final String codigo;
  final String nombre;
  final int? sector;

  Bloque({required this.codigo, required this.nombre, this.sector});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bloque && runtimeType == other.runtimeType && codigo == other.codigo;

  @override
  int get hashCode => codigo.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'sector': sector,
    };
  }

  factory Bloque.fromMap(Map<String, dynamic> map) {
    return Bloque(
      codigo: map['codigo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      sector: map['sector'],
    );
  }
}

class Variedad {
  final int id;
  final String codigo;
  final String nombre;
  final int estado;
  final int? familiaId;
  final String? familiaNombre;
  final String? color;
  final String? colorNombre;
  final String? subvarNombre;
  final int? limiteEsquejes;
  final int? diasCiclo;
  final int? densidadLinea; // Densidad: factor de esquejes/plantas por línea

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
    };
  }

  factory Variedad.fromMap(Map<String, dynamic> map) {
    return Variedad(
      id: map['id'],
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
    );
  }
}

class Cama {
  final int id;
  final String cama;
  final String bloque;
  final String nave;
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

class Operario {
  final int id;
  final String cedula;
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
      limiteEsquejes: int.tryParse(map['limite_esquejes'].toString()) ?? 2600,
      diasCiclo: int.tryParse(map['dias_ciclo'].toString()) ?? 75,
      densidadLinea: int.tryParse(map['densidad_linea']?.toString() ?? '') ?? 20,
      fechaActualizacion: map['fecha_actualizacion']?.toString(),
    );
  }
}

class Siembra {
  final int? idLocal; // Autoincremental local
  final String? uuid; // Identificador global de ciclo
  final String fecha;
  final String? bloqueCodigo;
  final int variedadId;
  final int camaId;
  final int operarioId;
  final int cantidad; // Tallos / esquejes sembrados
  
  // Control de Ciclo Agronómico y Disponibilidad de Cama
  final String estado; // 'ACTIVA' o 'FINALIZADA'
  final String? fechaFin; // Fecha de finalización / destronque

  // Campos operacionales
  final int? lineas;
  final String? observaciones;
  final String? corte;
  final String? lote;
  final String? proveedor;
  final String? cont;

  final int sincronizado; // 0 = false, 1 = true

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

/// Representa las métricas de rendimiento y productividad calculadas para un sembrador / operario
class RendimientoOperario {
  final Operario operario;
  final int totalTallos;
  final int totalCamas;
  final int totalLineas;
  final int diasTrabajados;
  final double promedioTallosPorCama;
  final double promedioTallosPorDia;
  final double porcentajeTotal;
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

  /// Calcula el rendimiento individual de cada sembrador a partir de las siembras y operarios dados
  static List<RendimientoOperario> calcular({
    required List<Siembra> siembras,
    required List<Operario> operarios,
  }) {
    if (siembras.isEmpty) return [];

    final totalTallosGlobal = siembras.fold<int>(0, (sum, s) => sum + s.cantidad);

    // Agrupar siembras por operarioId
    final Map<int, List<Siembra>> porOperario = {};
    for (var s in siembras) {
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

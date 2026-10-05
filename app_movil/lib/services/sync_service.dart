import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

class SyncService {
  // URLs de conexión por defecto
  static const String defaultUrl = 'http://10.0.2.2:8000/api';
  static const String fallbackLanUrl = 'http://192.168.1.39:8000/api';
  static String? _cachedBaseUrl;

  String? ultimoError;
  String? ultimaUrlProbada;

  final String apiKey = 'sk-siembras-2026-devkey';
  final dbRepo = DbRepository();
  final _uuid = const Uuid();

  /// Obtiene la URL base configurada o por defecto
  Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }
    final saved = await dbRepo.obtenerAjuste('server_url');
    if (saved != null && saved.trim().isNotEmpty) {
      _cachedBaseUrl = saved.trim();
      return _cachedBaseUrl!;
    }
    _cachedBaseUrl = fallbackLanUrl; // Preferir la IP de LAN para tablets físicas
    return _cachedBaseUrl!;
  }

  /// Resuelve automáticamente la mejor URL activa verificando respuesta rápida
  Future<String> resolverUrlActiva() async {
    // 1. Probar la URL guardada previamente si existe
    final saved = await dbRepo.obtenerAjuste('server_url');
    if (saved != null && saved.trim().isNotEmpty) {
      final res = await probarConexion(saved.trim());
      if (res['exito'] == true) {
        _cachedBaseUrl = saved.trim();
        ultimaUrlProbada = _cachedBaseUrl;
        return _cachedBaseUrl!;
      }
    }

    // 2. Probar LAN Wi-Fi (usada por tablets físicas en campo)
    final resLan = await probarConexion(fallbackLanUrl);
    if (resLan['exito'] == true) {
      _cachedBaseUrl = fallbackLanUrl;
      ultimaUrlProbada = fallbackLanUrl;
      await dbRepo.guardarAjuste('server_url', fallbackLanUrl);
      return fallbackLanUrl;
    }

    // 3. Probar Emulador Android (10.0.2.2)
    final resEmu = await probarConexion(defaultUrl);
    if (resEmu['exito'] == true) {
      _cachedBaseUrl = defaultUrl;
      ultimaUrlProbada = defaultUrl;
      await dbRepo.guardarAjuste('server_url', defaultUrl);
      return defaultUrl;
    }

    // Si ninguna respondió, devolver la configurada o fallback
    final fallback = (saved != null && saved.trim().isNotEmpty) ? saved.trim() : fallbackLanUrl;
    ultimaUrlProbada = fallback;
    return fallback;
  }

  /// Normaliza cualquier URL dada para garantizar que termine en /api y no tenga barras sobrantes
  static String normalizarUrl(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) {
      url = '$url/api';
    }
    return url;
  }

  /// Guarda una nueva URL base para el servidor backend
  Future<void> setBaseUrl(String newUrl) async {
    _cachedBaseUrl = normalizarUrl(newUrl);
    ultimaUrlProbada = _cachedBaseUrl;
    await dbRepo.guardarAjuste('server_url', _cachedBaseUrl!);
  }

  /// Prueba la conectividad con el backend
  Future<Map<String, dynamic>> probarConexion([String? customUrl]) async {
    final rawTarget = customUrl?.trim() ?? await getBaseUrl();
    final targetUrl = normalizarUrl(rawTarget);
    final stopwatch = Stopwatch()..start();
    try {
      final clean = targetUrl.endsWith('/') ? targetUrl.substring(0, targetUrl.length - 1) : targetUrl;
      final uri = Uri.parse('$clean/health');
      final resp = await http.get(
        uri,
        headers: {'X-API-Key': apiKey},
      ).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      if (resp.statusCode == 200) {
        return {
          'exito': true,
          'ms': stopwatch.elapsedMilliseconds,
          'mensaje': 'Conexión exitosa (${stopwatch.elapsedMilliseconds} ms)',
          'url': targetUrl,
        };
      } else {
        return {
          'exito': false,
          'ms': stopwatch.elapsedMilliseconds,
          'mensaje': 'Error del servidor: HTTP ${resp.statusCode}',
          'url': targetUrl,
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'exito': false,
        'ms': stopwatch.elapsedMilliseconds,
        'mensaje': 'No se pudo conectar: $e',
        'url': targetUrl,
      };
    }
  }

  /// Descarga todos los catálogos empresariales y los guarda localmente en SQLite
  Future<bool> descargarCatalogos() async {
    final url = await resolverUrlActiva();
    ultimaUrlProbada = url;
    try {
      final ok = await _ejecutarDescargaCatalogos(url);
      if (ok) {
        ultimoError = null;
        return true;
      }
    } catch (e, st) {
      print('[SyncService] Error al descargar catálogos desde $url: $e\n$st');
      // Si la URL inicial falló y no era la LAN, intentar con la LAN como respaldo
      if (url != fallbackLanUrl) {
        try {
          final ok = await _ejecutarDescargaCatalogos(fallbackLanUrl);
          if (ok) {
            await setBaseUrl(fallbackLanUrl);
            ultimaUrlProbada = fallbackLanUrl;
            ultimoError = null;
            return true;
          }
        } catch (_) {}
      }
      ultimoError = e.toString();
    }
    return false;
  }

  Future<bool> _ejecutarDescargaCatalogos(String activeUrl) async {
    final cleanUrl = activeUrl.endsWith('/') ? activeUrl.substring(0, activeUrl.length - 1) : activeUrl;
    final response = await http.get(
      Uri.parse('$cleanUrl/catalogos/'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Bloques (t17)
      if (data['bloques'] != null) {
        final List<Bloque> bloques = (data['bloques'] as List)
            .map((b) => Bloque.fromMap(b))
            .toList();
        await dbRepo.reemplazarBloques(bloques);
      }

      // Variedades (t11 con limite_esquejes y dias_ciclo)
      if (data['variedades'] != null) {
        final List<Variedad> variedades = (data['variedades'] as List)
            .map((v) => Variedad.fromMap(v))
            .toList();
        await dbRepo.reemplazarVariedades(variedades);
      }

      // Camas (t49)
      if (data['camas'] != null) {
        final List<Cama> camas = (data['camas'] as List)
            .map((c) => Cama.fromMap(c))
            .toList();
        await dbRepo.reemplazarCamas(camas);
      }

      // Operarios (t159)
      if (data['operarios'] != null) {
        final List<Operario> operarios = (data['operarios'] as List)
            .map((o) => Operario.fromMap(o))
            .toList();
        await dbRepo.reemplazarOperarios(operarios);
      }

      // Catálogo Lirios Tabla 187 (Proveedor, Contenedor, Lote, Variedad)
      if (data['lirios_187'] != null) {
        final rawLirios = data['lirios_187'];
        final List listLirios = rawLirios is List
            ? rawLirios
            : (rawLirios is Map && rawLirios['registros'] is List
                ? rawLirios['registros'] as List
                : []);
        final List<LirioItem187> lirios187 = listLirios
            .map((l) => LirioItem187.fromMap(l))
            .toList();
        await dbRepo.reemplazarLirios187(lirios187);
      }

      // Configuraciones Agronómicas oficiales de la base de datos empresarial
      if (data['configuraciones_agronomicas'] != null) {
        final List<ConfigAgronomica> configs = (data['configuraciones_agronomicas'] as List)
            .map((c) => ConfigAgronomica.fromMap(c))
            .toList();
        for (var c in configs) {
          await dbRepo.guardarConfigAgronomica(c);
        }
      }

      return true;
    } else {
      print('Error descargando catálogos: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  /// Sube las siembras y actualizaciones de ciclos offline al backend
  Future<bool> sincronizarPendientes() async {
    try {
      // Reconciliar previamente cualquier variedad temporal que ya coincida con Access
      await dbRepo.reconciliarVariedadesTemporales();

      final pendientes = await dbRepo.obtenerSiembrasPendientesSync();
      final eliminaciones = await dbRepo.obtenerUuidsEliminacionesPendientes();

      if (pendientes.isEmpty && eliminaciones.isEmpty) {
        return true; // Nada pendiente por subir ni eliminar
      }

      final List<Map<String, dynamic>> pushList = [];

      for (var s in pendientes) {
        DateTime parsedDate = DateTime.now();
        if (s.fecha.contains('/')) {
          final parts = s.fecha.split('/');
          if (parts.length == 3) {
            final d = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final y = int.tryParse(parts[2]);
            if (d != null && m != null && y != null) {
              parsedDate = DateTime(y, m, d);
            }
          }
        } else {
          final iso = DateTime.tryParse(s.fecha);
          if (iso != null) parsedDate = iso;
        }

        int? fechaFinMillis;
        if (s.fechaFin != null && s.fechaFin!.isNotEmpty) {
          if (s.fechaFin!.contains('/')) {
            final parts = s.fechaFin!.split('/');
            if (parts.length == 3) {
              final d = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (d != null && m != null && y != null) {
                fechaFinMillis = DateTime(y, m, d).millisecondsSinceEpoch;
              }
            }
          } else {
            final isoFin = DateTime.tryParse(s.fechaFin!);
            if (isoFin != null) fechaFinMillis = isoFin.millisecondsSinceEpoch;
          }
        }

        final syncUuid = s.uuid ?? (s.idLocal != null ? 'siembra-local-${s.idLocal}' : _uuid.v4());

        // Asegurar que la fecha se envíe como fecha pura (DD/MM/YYYY) y con timestamp al mediodía UTC
        // para evitar desfases de huso horario (ej: UTC vs UTC-5)
        final int fechaSiembraMiddayMillis = DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day, 12, 0, 0).millisecondsSinceEpoch;

        final varItem = await dbRepo.obtenerVariedadPorId(s.variedadId);

        pushList.add({
          'uuid': syncUuid,
          'bloque_codigo': s.bloqueCodigo,
          'cama_id': s.camaId,
          'variedad_id': s.variedadId,
          'variedad_nombre': varItem?.nombre,
          'operario_id': s.operarioId,
          'fecha_siembra': fechaSiembraMiddayMillis,
          'fecha_str': s.fecha,
          'fecha_fin': fechaFinMillis,
          'fecha_fin_str': s.fechaFin,
          'cantidad_esquejes': s.cantidad,
          'lineas': s.lineas ?? 14,
          'lote': s.lote,
          'proveedor': s.proveedor,
          'conteo': s.cont,
          'observaciones': s.observaciones,
          'estado': s.estado,
          'version': 1
        });
      }

      final payload = {
        'device_id': 'MOVIL_EMULADOR_01',
        'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
        'push': pushList,
        'deletes': eliminaciones,
      };

      var url = await resolverUrlActiva();
      ultimaUrlProbada = url;
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

      http.Response response;
      try {
        response = await http.post(
          Uri.parse('$cleanUrl/sync/siembras'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 45));
      } catch (netErr) {
        if (url != fallbackLanUrl) {
          final cleanLan = fallbackLanUrl.endsWith('/') ? fallbackLanUrl.substring(0, fallbackLanUrl.length - 1) : fallbackLanUrl;
          response = await http.post(
            Uri.parse('$cleanLan/sync/siembras'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 45));
          await setBaseUrl(fallbackLanUrl);
          ultimaUrlProbada = fallbackLanUrl;
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        for (var s in pendientes) {
          if (s.idLocal != null) {
            await dbRepo.marcarSiembraComoSincronizada(s.idLocal!);
          }
        }
        if (eliminaciones.isNotEmpty) {
          await dbRepo.limpiarEliminacionesPendientes(eliminaciones);
        }

        // Integración de pull bidireccional (siembras activas desde el servidor)
        try {
          final respData = jsonDecode(response.body);
          if (respData['pull'] != null && respData['pull'] is List) {
            await dbRepo.integrarSiembrasDesdeServidor(respData['pull'] as List);
          }
        } catch (_) {}

        ultimoError = null;
        return true;
      } else {
        ultimoError = 'Error del servidor: HTTP ${response.statusCode}';
        return false;
      }
    } catch (e) {
      ultimoError = e.toString();
      return false;
    }
  }

  /// Crea una variedad en el backend con credenciales de Administrador
  Future<Variedad?> crearVariedadRemota(
    String nombre, 
    String codigo, 
    String adminPin, {
    int? limiteEsquejes,
    int? diasCiclo,
    int? densidadLinea,
    int? familiaId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'nombre': nombre,
        'codigo': codigo,
        'limite_esquejes': limiteEsquejes ?? 3000,
        'dias_ciclo': diasCiclo ?? 90,
      };
      if (densidadLinea != null) body['densidad_linea'] = densidadLinea;
      if (familiaId != null) body['familia_id'] = familiaId;

      var url = await getBaseUrl();
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

      final response = await http.post(
        Uri.parse('$cleanUrl/catalogos/variedades'),
        headers: {
          'Content-Type': 'application/json',
          'X-Admin-Token': adminPin,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nueva = Variedad.fromMap(data);
        await dbRepo.guardarVariedadLocal(nueva);
        return nueva;
      }
    } catch (e) {
      print('Error al crear variedad remota: $e');
    }
    return null;
  }

  /// Actualiza una variedad en el backend con credenciales de Administrador
  Future<bool> actualizarVariedadRemota(
    int id,
    String nombre,
    String codigo,
    int estado,
    String adminPin, {
    int? limiteEsquejes,
    int? diasCiclo,
    int? densidadLinea,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'nombre': nombre,
        'codigo': codigo,
        'estado': estado,
      };
      if (limiteEsquejes != null) body['limite_esquejes'] = limiteEsquejes;
      if (diasCiclo != null) body['dias_ciclo'] = diasCiclo;
      if (densidadLinea != null) body['densidad_linea'] = densidadLinea;

      var url = await getBaseUrl();
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

      final response = await http.put(
        Uri.parse('$cleanUrl/catalogos/variedades/$id'),
        headers: {
          'Content-Type': 'application/json',
          'X-Admin-Token': adminPin,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final actualizada = Variedad.fromMap(data);
        await dbRepo.guardarVariedadLocal(actualizada);
        return true;
      }
    } catch (e) {
      print('Error al actualizar variedad remota: $e');
    }
    return false;
  }
}

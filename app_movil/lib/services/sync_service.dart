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
    _cachedBaseUrl = defaultUrl;
    return _cachedBaseUrl!;
  }

  /// Guarda una nueva URL base para el servidor backend
  Future<void> setBaseUrl(String newUrl) async {
    _cachedBaseUrl = newUrl.trim();
    await dbRepo.guardarAjuste('server_url', _cachedBaseUrl!);
  }

  /// Prueba la conectividad con el backend
  Future<Map<String, dynamic>> probarConexion([String? customUrl]) async {
    final targetUrl = customUrl?.trim() ?? await getBaseUrl();
    final stopwatch = Stopwatch()..start();
    try {
      final clean = targetUrl.endsWith('/') ? targetUrl.substring(0, targetUrl.length - 1) : targetUrl;
      final uri = Uri.parse('$clean/health');
      final resp = await http.get(
        uri,
        headers: {'X-API-Key': apiKey},
      ).timeout(const Duration(seconds: 4));
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
    var url = await getBaseUrl();
    try {
      return await _ejecutarDescargaCatalogos(url);
    } catch (e) {
      // Si falló con la URL por defecto (10.0.2.2), intentar con la IP de red local
      if (url == defaultUrl) {
        try {
          final ok = await _ejecutarDescargaCatalogos(fallbackLanUrl);
          if (ok) {
            await setBaseUrl(fallbackLanUrl);
            return true;
          }
        } catch (_) {}
      }
      print('Exception en descargarCatalogos: $e');
      return false;
    }
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

      return true;
    } else {
      print('Error descargando catálogos: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  /// Sube las siembras y actualizaciones de ciclos offline al backend
  Future<bool> sincronizarPendientes() async {
    try {
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

        pushList.add({
          'uuid': syncUuid,
          'bloque_codigo': s.bloqueCodigo,
          'cama_id': s.camaId,
          'variedad_id': s.variedadId,
          'operario_id': s.operarioId,
          'fecha_siembra': parsedDate.millisecondsSinceEpoch,
          'fecha_fin': fechaFinMillis,
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

      var url = await getBaseUrl();
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

      final response = await http.post(
        Uri.parse('$cleanUrl/sync/siembras'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        for (var s in pendientes) {
          if (s.idLocal != null) {
            await dbRepo.marcarSiembraComoSincronizada(s.idLocal!);
          }
        }
        if (eliminaciones.isNotEmpty) {
          await dbRepo.limpiarEliminacionesPendientes(eliminaciones);
        }
        return true;
      } else {
        print('Error en sync: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception en sync: $e');
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

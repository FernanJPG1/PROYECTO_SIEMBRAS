import 'package:flutter/material.dart';

/// Utilidad agronómica oficial para el cálculo y selección de semanas
/// según el Calendario Floral y Comercial de Estados Unidos (US Calendar).
///
/// Características del Calendario de EE. UU. (idéntico a Microsoft Access / Excel WEEKNUM):
/// 1. La semana inicia el Domingo (Sunday) y finaliza el Sábado (Saturday).
/// 2. La Semana #1 es la semana que contiene el 1 de enero.
/// 3. Se sincroniza 100% con los registros históricos de la base de datos empresarial (t164_semana).
class CalendarioUtil {
  /// Calcula el número de semana de EE. UU. (1 a 53) para una fecha dada.
  static int obtenerSemanaUS(DateTime fecha) {
    final jan1 = DateTime(fecha.year, 1, 1);
    // En Dart: 1 = Lunes, ..., 7 = Domingo.
    // En EE. UU., Domingo es el día 0:
    final int jan1Dow = jan1.weekday % 7;
    final int doy = fecha.difference(jan1).inDays + 1;
    final int semana = ((doy + jan1Dow - 1) ~/ 7) + 1;
    return semana;
  }

  /// Retorna la etiqueta formateada: Ej: 'Semana #40' o 'Semana #40 - 2026'
  static String obtenerEtiquetaSemana(DateTime fecha, {bool incluirAnio = false}) {
    final sem = obtenerSemanaUS(fecha);
    return incluirAnio ? 'Semana #$sem - ${fecha.year}' : 'Semana #$sem';
  }

  /// Retorna un texto compacto: Ej: 'Sem. 40'
  static String obtenerEtiquetaCorta(DateTime fecha) {
    final sem = obtenerSemanaUS(fecha);
    return 'Sem. $sem';
  }

  /// Formatea un DateTime a sólo fecha en formato estándar 'dd/MM/yyyy' (sin hora)
  static String formatearFechaSolo(DateTime fecha) {
    return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
  }

  /// Parsea una cadena de fecha en formatos comunes (dd/MM/yyyy o yyyy-MM-dd)
  static DateTime? parsearFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) return null;
    final f = fechaStr.trim();
    try {
      if (f.contains('/')) {
        final partes = f.split('/');
        if (partes.length == 3) {
          final dia = int.parse(partes[0]);
          final mes = int.parse(partes[1]);
          final anio = int.parse(partes[2]);
          return DateTime(anio, mes, dia);
        }
      }
      return DateTime.tryParse(f);
    } catch (_) {
      return null;
    }
  }

  /// Retorna el rango de fechas (Domingo a Sábado) correspondiente a una semana de EE. UU.
  static DateTimeRange obtenerRangoFechasSemanaUS(int anio, int semana) {
    final jan1 = DateTime(anio, 1, 1);
    final jan1Dow = jan1.weekday % 7; // 0=Domingo
    // Primer domingo de la semana 1
    final primerDomingo = jan1.subtract(Duration(days: jan1Dow));
    final inicioSemana = primerDomingo.add(Duration(days: (semana - 1) * 7));
    final finSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(start: inicioSemana, end: finSemana);
  }

  /// Retorna la lista de todas las semanas del año con su rango legible (Domingo a Sábado)
  /// para alimentar selectores automáticos de semana.
  static List<Map<String, dynamic>> obtenerListaSemanasDelAnio(int anio) {
    final List<Map<String, dynamic>> lista = [];
    final maxSemanas = (obtenerSemanaUS(DateTime(anio, 12, 31)) >= 53) ? 53 : 52;

    for (int s = 1; s <= maxSemanas; s++) {
      final rango = obtenerRangoFechasSemanaUS(anio, s);
      final ini = "${rango.start.day.toString().padLeft(2, '0')}/${rango.start.month.toString().padLeft(2, '0')}";
      final fin = "${rango.end.day.toString().padLeft(2, '0')}/${rango.end.month.toString().padLeft(2, '0')}";
      lista.add({
        'semana': s,
        'anio': anio,
        'etiqueta': 'Semana #$s',
        'etiquetaCompleta': 'Semana #$s ($ini - $fin)',
        'rango': rango,
      });
    }
    return lista;
  }

  /// Calcula fecha y semana de cosecha proyectada según días de ciclo agronómico
  static Map<String, dynamic> calcularCosecha(DateTime fechaSiembra, int diasCiclo) {
    final fCosecha = fechaSiembra.add(Duration(days: diasCiclo));
    final semSiembra = obtenerSemanaUS(fechaSiembra);
    final semCosecha = obtenerSemanaUS(fCosecha);
    final fCosechaStr = "${fCosecha.day.toString().padLeft(2, '0')}/${fCosecha.month.toString().padLeft(2, '0')}/${fCosecha.year}";
    
    return {
      'fechaCosecha': fCosecha,
      'fechaCosechaStr': fCosechaStr,
      'semanaSiembra': semSiembra,
      'semanaCosecha': semCosecha,
      'anioCosecha': fCosecha.year,
      'etiquetaSiembra': 'Sem. $semSiembra (${fechaSiembra.year})',
      'etiquetaCosecha': 'Sem. $semCosecha (${fCosecha.year})',
    };
  }

  /// Límite oficial de días permitidos para modificar o eliminar un registro desde la aplicación móvil.
  /// Pasado este lapso (más de 2 días), los registros quedan blindados contra alteraciones locales
  /// y solo pueden ser modificados desde la base de datos empresarial central.
  static const int diasLimiteModificacionApp = 2;

  /// Retorna la cantidad de días calendario transcurridos desde la fecha de siembra hasta el día de hoy.
  /// Si la fecha es de hoy o futura, retorna 0 o negativo.
  static int diasDesdeFecha(String? fechaStr) {
    final f = parsearFecha(fechaStr);
    if (f == null) return 0;
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final soloFecha = DateTime(f.year, f.month, f.day);
    return soloHoy.difference(soloFecha).inDays;
  }

  /// Indica si el registro se encuentra dentro del plazo permitido (<= 2 días)
  /// para ser modificado o eliminado desde la aplicación móvil.
  static bool puedeModificarSiembraPorFecha(String? fechaStr) {
    final diffDias = diasDesdeFecha(fechaStr);
    return diffDias <= diasLimiteModificacionApp;
  }
}

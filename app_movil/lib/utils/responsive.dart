import 'package:flutter/material.dart';

/// Utilidades y breakpoints para diseño 100% responsivo adaptable a:
/// - Dispositivos Android en vertical (pantalla compacta: < 650px)
/// - Dispositivos Android en horizontal (landscape: altura reducida)
/// - Dispositivos Android de pantalla amplia o intermedia (>= 650px)
class Responsive {
  /// Retorna verdadero si el ancho de pantalla corresponde a un celular o pantalla compacta
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 650;

  /// Retorna verdadero si el ancho de pantalla corresponde a un dispositivo Android con pantalla intermedia
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 650 && w < 1100;
  }

  /// Retorna verdadero si es dispositivo Android con pantalla amplia o monitor
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  /// Retorna verdadero si la pantalla está en orientación horizontal (Landscape)
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Retorna el ancho total de pantalla
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Retorna el alto total de pantalla
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Selecciona un valor adaptado al tipo de pantalla actual
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100 && desktop != null) return desktop;
    if (w >= 650 && tablet != null) return tablet;
    return mobile;
  }

  /// Ancho máximo seguro para modales y diálogos centrado
  static double dialogMaxWidth(BuildContext context, {double defaultMax = 650}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < defaultMax + 32) {
      return w * 0.94;
    }
    return defaultMax;
  }

  /// Altura máxima segura para modales y diálogos
  static double dialogMaxHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height * 0.88;
  }

  /// Margen / padding exterior estándar recomendado
  static EdgeInsets pagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 40, vertical: 20);
  }

  /// Cálculo automático de columnas para grids basado en un ancho mínimo deseado por celda
  static int calculateGridColumns(
    BuildContext context, {
    double minItemWidth = 160.0,
    int maxColumns = 6,
    int minColumns = 1,
  }) {
    final totalWidth = MediaQuery.sizeOf(context).width;
    int cols = (totalWidth / minItemWidth).floor();
    if (cols < minColumns) cols = minColumns;
    if (cols > maxColumns) cols = maxColumns;
    return cols;
  }
}

/// Contenedor centrado que restringe el ancho en tablets y pantallas grandes
/// para evitar que los formularios se estiren excesivamente horizontalmente.
class ResponsiveContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

/// Widget constructor condicional que renderiza una vista móvil o tablet según el breakpoint
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100 && desktop != null) {
      return desktop!(context);
    }
    if (w >= 650 && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}

import 'package:flutter/material.dart';

/// Marca de agua / firma sutil del proyecto (caballo)
/// Diseñado para flotar en la esquina izquierda de forma muy leve y sin bloquear interacciones.
class FirmaWatermark extends StatelessWidget {
  final double width;
  final double opacity;
  final double left;
  final double bottom;

  const FirmaWatermark({
    super.key,
    this.width = 58.0,
    this.opacity = 0.30,
    this.left = 14.0,
    this.bottom = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: left,
      bottom: bottom + bottomInset,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/images/firma_caballo.png',
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error al cargar firma_caballo.png: $error');
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

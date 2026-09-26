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
    this.width = 50.0,
    this.opacity = 0.22,
    this.left = 10.0,
    this.bottom = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/images/firma_caballo.png',
            width: width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:app_movil/services/reporte_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() generadorPdf;
  final String nombreArchivo;

  const PdfViewerScreen({
    super.key,
    required this.titulo,
    required this.generadorPdf,
    required this.nombreArchivo,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final bytes = await widget.generadorPdf();
      final ruta = await ReporteService.guardarPdfEnDescargas(
        bytes: bytes,
        nombreArchivo: widget.nombreArchivo,
      );
      if (!mounted) return;
      if (ruta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Archivo guardado con éxito en Descargas:\n${widget.nombreArchivo}'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titulo.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download, color: Colors.white, size: 24),
            tooltip: 'Guardar en Descargas',
            onPressed: _guardando ? null : _guardar,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => widget.generadorPdf(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,  // Permite tanto impresión física / spooler como guardar PDF
        allowSharing: true,   // Exportar y compartir digital (WhatsApp, Drive, etc.)
        pdfFileName: widget.nombreArchivo,
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF7CB342)),
              SizedBox(height: 14),
              Text(
                'Generando documento PDF...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF33691E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

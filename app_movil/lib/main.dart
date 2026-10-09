// ============================================================================
// ARCHIVO: main.dart
// ¿QUÉ ES ESTE ARCHIVO EXPLICADO DE FORMA SENCILLA?
// Imagínate que este archivo es LA PUERTA PRINCIPAL Y EL INTERRUPTOR GENERAL de la app.
//
// Es lo primerito que se ejecuta cuando tocas con el dedo el ícono de la aplicación
// en la pantalla del celular:
// 1. Enciende los motores de Flutter (el sistema visual).
// 2. Permite girar la pantalla de pie (vertical) o acostada (horizontal) para que
//    el trabajador la use como más le acomode en el campo.
// 3. Abre la caja fuerte de datos (`LocalDatabase`).
// 4. Activa el "Cinturón de Seguridad": si entra una llamada, el celular se apaga
//    o se descarga la batería, guarda todo inmediatamente sin perder nada.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:app_movil/database/local_db.dart';
import 'package:app_movil/screens/dashboard_screen.dart';
import 'package:app_movil/services/persistent_backup_service.dart';
import 'package:app_movil/widgets/firma_watermark.dart';
import 'package:flutter/services.dart';

/// PUNTO DE ARRANQUE: Al tocar el ícono en el teléfono, empieza aquí.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Permite usar el celular de pie o acostado de lado (horizontal para ver tablas anchas)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Abre la caja fuerte y verifica que no falte ningún dato de ayer
  final db = await LocalDatabase.instance.database;
  await PersistentBackupService.instance.verificarYRecuperar(db);

  // Muestra la primera pantalla en los ojos del usuario
  runApp(const SiembrasApp());
}

class SiembrasApp extends StatefulWidget {
  const SiembrasApp({super.key});

  @override
  State<SiembrasApp> createState() => _SiembrasAppState();
}

class _SiembrasAppState extends State<SiembrasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el dispositivo Android entra en pausa, bajo consumo, apagado o suspensión, forzar persistencia inmediata
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      LocalDatabase.instance.checkpoint();
      PersistentBackupService.instance.resguardarSiembras();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siembras Offline',
      theme: ThemeData(
        primaryColor: const Color(0xFF7CB342),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7CB342)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const FirmaWatermark(
              width: 50.0,
              opacity: 0.22,
              left: 10.0,
              bottom: 10.0,
            ),
          ],
        );
      },
    );
  }
}

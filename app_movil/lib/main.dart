import 'package:flutter/material.dart';
import 'package:app_movil/database/local_db.dart';
import 'package:app_movil/screens/dashboard_screen.dart';
import 'package:app_movil/services/persistent_backup_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Permitir orientación dinámica libre (Vertical y Horizontal)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Inicializa la base de datos física y verifica la integridad del respaldo permanente
  final db = await LocalDatabase.instance.database;
  await PersistentBackupService.instance.verificarYRecuperar(db);

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
    // Si la tablet entra en pausa, bajo consumo, apagado o suspensión, forzar persistencia inmediata
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
    );
  }
}

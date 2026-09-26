import 'package:flutter/material.dart';
import 'package:app_movil/database/local_db.dart';
import 'package:app_movil/screens/dashboard_screen.dart';
import 'package:app_movil/widgets/firma_watermark.dart';
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
  
  await LocalDatabase.instance.database;
  runApp(const SiembrasApp());
}

class SiembrasApp extends StatelessWidget {
  const SiembrasApp({super.key});

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
            const FirmaWatermark(),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:app_movil/screens/subgrupo_lirios_screen.dart';
import 'package:app_movil/screens/form_siembra_pompon_screen.dart';

class CultivoOption {
  final String nombre;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final Widget destino;

  const CultivoOption({
    required this.nombre,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.destino,
  });
}

class MenuCultivosScreen extends StatelessWidget {
  const MenuCultivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<CultivoOption> cultivos = [
      const CultivoOption(
        nombre: 'Lirios',
        subtitulo: 'LA, LO, OT (Bulbos)',
        icono: Icons.local_florist,
        color: Color(0xFF2E7D32),
        destino: SubgrupoLiriosScreen(),
      ),
      const CultivoOption(
        nombre: 'Cremon',
        subtitulo: 'Disbud / Fuji (Uniflor)',
        icono: Icons.filter_vintage,
        color: Color(0xFF689F38),
        destino: FormSiembraPomponScreen(cultivo: 'Cremon'),
      ),
      const CultivoOption(
        nombre: 'Pompon',
        subtitulo: 'Crisantemo Estándar',
        icono: Icons.eco,
        color: Color(0xFF558B2F),
        destino: FormSiembraPomponScreen(cultivo: 'Pompon'),
      ),
      const CultivoOption(
        nombre: 'Girasol',
        subtitulo: 'Sunflower en Cama',
        icono: Icons.wb_sunny,
        color: Color(0xFFF57F17),
        destino: FormSiembraPomponScreen(cultivo: 'Girasol'),
      ),
      const CultivoOption(
        nombre: 'Matsumoto',
        subtitulo: 'Aster Matsumoto',
        icono: Icons.spa,
        color: Color(0xFF7CB342),
        destino: FormSiembraPomponScreen(cultivo: 'Matsumoto'),
      ),
      const CultivoOption(
        nombre: 'Gerbera',
        subtitulo: 'Siembra en cama',
        icono: Icons.yard,
        color: Color(0xFF9CCC65),
        destino: FormSiembraPomponScreen(cultivo: 'Gerbera'),
      ),
      const CultivoOption(
        nombre: 'Alstroemeria',
        subtitulo: 'Lirio de los Incas / Florinca',
        icono: Icons.park,
        color: Color(0xFFAD1457),
        destino: FormSiembraPomponScreen(cultivo: 'Alstroemeria'),
      ),
      const CultivoOption(
        nombre: 'Planta Madre',
        subtitulo: 'Multiplicación / Esquejes',
        icono: Icons.forest,
        color: Color(0xFF33691E),
        destino: FormSiembraPomponScreen(cultivo: 'Planta Madre'),
      ),
      const CultivoOption(
        nombre: 'Bancos',
        subtitulo: 'Enraizamiento / Propagación',
        icono: Icons.table_restaurant,
        color: Color(0xFF00897B),
        destino: FormSiembraPomponScreen(cultivo: 'Bancos'),
      ),
      const CultivoOption(
        nombre: 'Núcleos',
        subtitulo: 'Plantas Núcleo / Élite',
        icono: Icons.hub,
        color: Color(0xFF0097A7),
        destino: FormSiembraPomponScreen(cultivo: 'Núcleos'),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.grass, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'SELECCIÓN DE CULTIVO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 26),
              tooltip: 'Volver al Inicio',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione el tipo de cultivo o área a sembrar:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF33691E),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTabletWide = constraints.maxWidth > 850;
                    final crossAxisCount = isTabletWide
                        ? 5
                        : (constraints.maxWidth > 550 ? 3 : 2);
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isTabletWide ? 1.75 : 2.15,
                      ),
                      itemCount: cultivos.length,
                      itemBuilder: (context, index) {
                        final c = cultivos[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => c.destino),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            splashColor: c.color.withValues(alpha: 0.2),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: c.color.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -10,
                                    bottom: -10,
                                    child: Icon(
                                      c.icono,
                                      size: 80,
                                      color: c.color.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: c.color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                c.icono,
                                                color: c.color,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                c.nombre,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF263238),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.subtitulo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

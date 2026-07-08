import 'package:flutter/material.dart';
import 'package:app_movil/screens/form_siembra_lirios_screen.dart';

class LirioSubgrupoOption {
  final String codigo;
  final String nombre;
  final String descripcion;
  final Color color;
  final IconData icono;

  const LirioSubgrupoOption({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.color,
    required this.icono,
  });
}

class SubgrupoLiriosScreen extends StatelessWidget {
  const SubgrupoLiriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<LirioSubgrupoOption> subgrupos = [
      const LirioSubgrupoOption(
        codigo: 'LA',
        nombre: 'Lirio LA',
        descripcion: 'Longiflorum x Asiático (LA)',
        color: Color(0xFF33691E),
        icono: Icons.spa,
      ),
      const LirioSubgrupoOption(
        codigo: 'LO',
        nombre: 'Lirio LO',
        descripcion: 'Longiflorum x Oriental (LO)',
        color: Color(0xFF558B2F),
        icono: Icons.local_florist,
      ),
      const LirioSubgrupoOption(
        codigo: 'OT',
        nombre: 'Lirio OT',
        descripcion: 'Oriental x Trumpet (OT)',
        color: Color(0xFF689F38),
        icono: Icons.filter_vintage,
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
            Icon(Icons.local_florist, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'GRUPOS DE LIRIOS',
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
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione el grupo específico de Lirio a sembrar:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF33691E),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isHorizontal = constraints.maxWidth >= 600;

                    if (isHorizontal) {
                      return Row(
                        children: subgrupos.map((sg) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildCard(context, sg),
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      // Modo Vertical (Portrait)
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: subgrupos.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          return SizedBox(
                            height: 130,
                            child: _buildCard(context, subgrupos[i], isCompact: true),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, LirioSubgrupoOption sg, {bool isCompact = false}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormSiembraLiriosScreen(
                subtipo: sg.nombre,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        splashColor: sg.color.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sg.color.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  sg.icono,
                  size: isCompact ? 80 : 110,
                  color: sg.color.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: isCompact
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: sg.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(sg.icono, color: sg.color, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  sg.nombre,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sg.descripcion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 18, color: sg.color),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: sg.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(sg.icono, color: sg.color, size: 32),
                          ),
                          const Spacer(),
                          Text(
                            sg.nombre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sg.descripcion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                'Ingresar Siembra',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: sg.color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: sg.color,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

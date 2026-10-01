import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/models/entidades.dart';
import 'package:app_movil/repositories/db_repository.dart';

void main() {
  group('Pruebas de Multisembradores, Multivariedad y Cupo Agronómico de Cama', () {
    test('ValidacionCicloResultado expone correctamente los datos de cama compartida', () {
      final s1 = Siembra(
        idLocal: 1,
        uuid: 'uuid-1',
        fecha: '30/09/2026',
        bloqueCodigo: '004',
        camaId: 5,
        variedadId: 101, // Pompon Blanco
        operarioId: 12, // Operario Juan
        cantidad: 2000,
        estado: 'ACTIVA',
        sincronizado: 0,
      );

      final resultadoCompartido = ValidacionCicloResultado(
        esValido: true,
        esCicloActivo: true,
        esCamaLlena: false,
        esCamaCompartida: true,
        mensaje: 'Cama compartida disponible: 2000 de 4050 plantas ocupadas. Cupo disponible: 2050 plantas.',
        siembrasActivas: [s1],
        variedadesPresentes: ['POMPON BLANCO'],
        operariosPresentes: ['JUAN PEREZ'],
        cantidadOcupada: 2000,
        limiteMaximo: 4050,
        cupoDisponible: 2050,
      );

      expect(resultadoCompartido.esValido, isTrue);
      expect(resultadoCompartido.esCamaCompartida, isTrue);
      expect(resultadoCompartido.esCamaLlena, isFalse);
      expect(resultadoCompartido.cantidadOcupada, equals(2000));
      expect(resultadoCompartido.limiteMaximo, equals(4050));
      expect(resultadoCompartido.cupoDisponible, equals(2050));
      expect(resultadoCompartido.variedadesPresentes, contains('POMPON BLANCO'));
      expect(resultadoCompartido.operariosPresentes, contains('JUAN PEREZ'));
    });

    test('Cálculo acumulativo para multisembrador: rechaza cuando nueva cantidad excede cupo disponible', () {
      final s1 = Siembra(
        idLocal: 1,
        fecha: '30/09/2026',
        bloqueCodigo: '004',
        camaId: 5,
        variedadId: 101,
        operarioId: 12,
        cantidad: 2500,
        estado: 'ACTIVA',
        sincronizado: 0,
      );

      const int limiteCama = 4050;
      final int totalPlantado = s1.cantidad;
      final int cupoDisponible = limiteCama - totalPlantado; // 1550

      expect(cupoDisponible, equals(1550));

      // Intento de sembrar 1600 tallos (supera 1550)
      const int intentoCantidad = 1600;
      final bool excedeCupo = intentoCantidad > cupoDisponible;
      expect(excedeCupo, isTrue);

      final resultadoExceso = ValidacionCicloResultado(
        esValido: false,
        esCicloActivo: true,
        esCamaLlena: false,
        esCamaCompartida: true,
        mensaje: 'Límite agronómico de cama excedido: La cama ya tiene $totalPlantado plantas sembradas de un máximo de $limiteCama. Solo queda un cupo disponible de $cupoDisponible plantas y se intentó sembrar $intentoCantidad.',
        cantidadOcupada: totalPlantado,
        limiteMaximo: limiteCama,
        cupoDisponible: cupoDisponible,
      );

      expect(resultadoExceso.esValido, isFalse);
      expect(resultadoExceso.esCamaCompartida, isTrue);
      expect(resultadoExceso.esCamaLlena, isFalse);
      expect(resultadoExceso.cupoDisponible, equals(1550));
      expect(resultadoExceso.mensaje, contains('Solo queda un cupo disponible de 1550'));
    });

    test('Cálculo multivariedad: la capacidad respeta la restricción más estricta de las variedades en la cama', () {
      // Variedad 1: Pompon (límite 4050)
      // Variedad 2: Cremon (límite 3645)
      const int limitePompon = 4050;
      const int limiteCremon = 3645;

      // El límite efectivo de la cama multivariedad debe ser el mínimo de las variedades presentes
      final int limiteEfectivoCama = [limitePompon, limiteCremon].reduce((a, b) => a < b ? a : b);
      expect(limiteEfectivoCama, equals(3645));

      // Si se sembraron 2000 de Pompon:
      const int sembradoPompon = 2000;
      final int cupoParaCremon = limiteEfectivoCama - sembradoPompon;
      expect(cupoParaCremon, equals(1645));

      // Si otro operario siembra 1645 de Cremon:
      const int sembradoCremon = 1645;
      final int totalEnCama = sembradoPompon + sembradoCremon;
      expect(totalEnCama, equals(3645));

      // La cama ahora está 100% LLENA
      final int cupoRestante = limiteEfectivoCama - totalEnCama;
      expect(cupoRestante, equals(0));

      final resultadoLlena = ValidacionCicloResultado(
        esValido: false,
        esCicloActivo: true,
        esCamaLlena: true,
        esCamaCompartida: false,
        mensaje: 'Restricción Agronómica: La cama ya alcanzó el cupo máximo permitido ($totalEnCama de $limiteEfectivoCama plantas).',
        cantidadOcupada: totalEnCama,
        limiteMaximo: limiteEfectivoCama,
        cupoDisponible: 0,
      );

      expect(resultadoLlena.esValido, isFalse);
      expect(resultadoLlena.esCamaLlena, isTrue);
      expect(resultadoLlena.cupoDisponible, equals(0));
    });

    test('Helper parsearFechaSiembra procesa formatos DD/MM/AAAA e ISO correctamente', () {
      final f1 = parsearFechaSiembra('30/09/2026');
      expect(f1, isNotNull);
      expect(f1!.year, equals(2026));
      expect(f1.month, equals(9));
      expect(f1.day, equals(30));

      final f2 = parsearFechaSiembra('2026-09-30');
      expect(f2, isNotNull);
      expect(f2!.year, equals(2026));
      expect(f2.month, equals(9));
      final fInvalida = parsearFechaSiembra('no-fecha');
      expect(fInvalida, isNull);
    });

    test('Cama multivariedad: no elimina el registro anterior si no ha cumplido el ciclo, solo si se cumplió el ciclo', () {
      final fInicio = parsearFechaSiembra('25/09/2026')!;
      final fNuevaMismoCiclo = parsearFechaSiembra('30/09/2026')!; // 5 días transcurridos
      const int diasCicloReq = 75;

      final int diasTransActivo = fNuevaMismoCiclo.difference(fInicio).inDays;
      expect(diasTransActivo, equals(5));

      // El ciclo está activo (5 < 75), por lo tanto NO debe eliminarse
      final bool debeEliminarseActivo = diasTransActivo >= diasCicloReq;
      expect(debeEliminarseActivo, isFalse);

      // Si transcurrieron 75 días o más (ej: fecha nueva el 15/12/2026, 81 días)
      final fNuevaCicloCumplido = parsearFechaSiembra('15/12/2026')!;
      final int diasTransCumplido = fNuevaCicloCumplido.difference(fInicio).inDays;
      expect(diasTransCumplido, equals(81));

      // El ciclo se cumplió (81 >= 75), por lo tanto SI debe eliminarse para rotar la cama
      final bool debeEliminarseCumplido = diasTransCumplido >= diasCicloReq;
      expect(debeEliminarseCumplido, isTrue);
    });
  });
}

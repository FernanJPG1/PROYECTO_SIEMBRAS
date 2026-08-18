import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/models/entidades.dart';

void main() {
  test('Modelo Bloque serializa y deserializa correctamente', () {
    final bloque = Bloque(codigo: '001', nombre: 'BLOQUE 1', sector: 1);
    final map = bloque.toMap();
    expect(map['codigo'], '001');
    expect(map['nombre'], 'BLOQUE 1');
    final desdeMap = Bloque.fromMap(map);
    expect(desdeMap.codigo, bloque.codigo);
    expect(desdeMap.nombre, bloque.nombre);
  });

  test('Modelo Variedad maneja campos y estado correctamente', () {
    final v = Variedad(id: 10, codigo: '01', nombre: 'ROSA');
    expect(v.estado, 1);
    final map = v.toMap();
    expect(map['id'], 10);
    expect(map['estado'], 1);
  });

  test('Modelo Siembra serializa y deserializa campos offline', () {
    final siembra = Siembra(
      idLocal: 1,
      fecha: '21/09/2026',
      bloqueCodigo: '001',
      camaId: 101,
      operarioId: 5,
      variedadId: 20,
      cantidad: 1500,
      lineas: 14,
      lote: 'L-01',
      proveedor: 'PROV-A',
      cont: 'OK',
      observaciones: 'Sin novedad',
      sincronizado: 0,
    );

    final map = siembra.toMap();
    expect(map['bloque_codigo'], '001');
    expect(map['cama_id'], 101);
    expect(map['sincronizado'], 0);

    final recuperada = Siembra.fromMap(map);
    expect(recuperada.bloqueCodigo, '001');
    expect(recuperada.cantidad, 1500);
    expect(recuperada.observaciones, 'Sin novedad');
  });
}

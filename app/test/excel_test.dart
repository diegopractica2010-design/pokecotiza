import 'package:flutter_test/flutter_test.dart';
import 'package:pokecotiza/servicios/excel_io.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'flujo_test.dart' show estadoDePrueba, AlmacenMemoria;

void main() {
  test('xlsx: lo escrito se lee igual (texto, enteros, decimales, japonés y vacíos)', () {
    final filas = <List<Object?>>[
      ['nombre', 'idioma', 'cantidad', 'valor'],
      ['Lucario GX', 'es', 2, 33.81],
      ['ピカチュウ', 'ja', 1, ''],
    ];
    final leidas = leerXlsx(escribirXlsx(filas));
    expect(leidas[0], ['nombre', 'idioma', 'cantidad', 'valor']);
    expect(leidas[1], ['Lucario GX', 'es', 2, 33.81]);
    expect(leidas[2].take(3), ['ピカチュウ', 'ja', 1]);
  });

  test('exportar e importar la colección por Excel conserva las cartas', () async {
    const cartas = [
      CartaColeccion(
          id: 'c1',
          nombre: 'Lucario GX',
          idioma: Idioma.espanol,
          numero: '122/131',
          acabado: Acabado.holo,
          tcgmatchId: 44078,
          cantidad: 2),
      CartaColeccion(id: 'c2', nombre: 'Pidgey', idioma: Idioma.ingles, numero: '016/165', condicion: Condicion.lp),
    ];
    final bytes = escribirXlsx(exportarFilas(cartas, {'c1': const ValorCarta(publicadoClp: 34783)}));
    final r = importarFilas(leerXlsx(bytes), nuevoId: () => 'nuevo');
    expect(r.invalidas, isEmpty);
    expect(r.cartas.map((c) => (c.id, c.numero, c.cantidad, c.acabado, c.condicion, c.tcgmatchId)), [
      ('c1', '122/131', 2, Acabado.holo, Condicion.nm, 44078),
      ('c2', '016/165', 1, Acabado.normal, Condicion.lp, null),
    ]);

    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen);
    expect(await estado.importar(r.cartas), 2);
    expect(almacen.cartas.keys, ['c1', 'c2']);
    expect(await estado.importar([r.cartas.first]), 1); // reimportar reemplaza, no duplica
    expect(estado.cartas.length, 2);
  });
}

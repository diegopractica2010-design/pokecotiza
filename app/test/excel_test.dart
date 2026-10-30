import 'package:flutter_test/flutter_test.dart';
import 'package:pokecotiza/servicios/almacen.dart';
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
    final r = importarFilas(leerXlsx(bytes));
    expect(r.invalidas, isEmpty);
    expect(r.cartas.map((c) => (c.id, c.numero, c.cantidad, c.acabado, c.condicion, c.tcgmatchId)), [
      ('c1', '122/131', 2, Acabado.holo, Condicion.nm, 44078),
      ('c2', '016/165', 1, Acabado.normal, Condicion.lp, null),
    ]);

    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen);
    expect((await estado.importar(r.cartas)).guardadas, 2);
    expect(almacen.cartas.keys, ['c1', 'c2']);
    expect((await estado.importar([r.cartas.first])).guardadas, 1); // reimportar reemplaza, no duplica
    expect(estado.cartas.length, 2);
  });

  test('reemplazar por otra carta con el mismo id borra su precio guardado', () async {
    final almacen = AlmacenMemoria()
      ..cartas['c1'] = const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol)
      ..cots['c1'] = CotizacionGuardada(
          fecha: DateTime(2026), valor: const ValorCarta(publicadoClp: 30000), cotizaciones: const []);
    final estado = estadoDePrueba(almacen);
    await estado.cargar();
    // Solo cambia la cantidad: el precio sigue valiendo.
    await estado.importar([const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol, cantidad: 3)]);
    expect(estado.cotizaciones['c1'], isNotNull);
    // Ahora es otra carta: el precio anterior se olvida.
    await estado.importar([const CartaColeccion(id: 'c1', nombre: 'Charizard', idioma: Idioma.espanol)]);
    expect(estado.cotizaciones['c1'], isNull);
    expect(almacen.cots['c1'], isNull);
  });

  test('si una carta falla al guardarse, sigue con las demás y la informa', () async {
    final almacen = _AlmacenQueFalla('b');
    final estado = estadoDePrueba(almacen);
    final r = await estado.importar(const [
      CartaColeccion(id: 'a', nombre: 'A', idioma: Idioma.ingles),
      CartaColeccion(id: 'b', nombre: 'B', idioma: Idioma.ingles),
      CartaColeccion(id: 'c', nombre: 'C', idioma: Idioma.ingles),
    ]);
    expect(r.guardadas, 2);
    expect(r.fallidas.keys, ['B']);
    expect(almacen.cartas.keys, ['a', 'c']);
  });

  test('no se puede importar mientras la colección carga', () async {
    final estado = estadoDePrueba(AlmacenMemoria())..cargando = true;
    expect(() => estado.importar(const []), throwsStateError);
  });
}

class _AlmacenQueFalla extends AlmacenMemoria {
  _AlmacenQueFalla(this.idQueFalla);
  final String idQueFalla;
  @override
  Future<void> guardarCarta(CartaColeccion carta) async {
    if (carta.id == idQueFalla) throw Exception('Google Sheets no respondió');
    await super.guardarCarta(carta);
  }
}

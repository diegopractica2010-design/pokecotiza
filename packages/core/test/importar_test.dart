import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

void main() {
  test('reconoce encabezados escritos a mano, en cualquier orden', () {
    final r = importarFilas([
      ['Número', 'Nombre', 'Idioma', 'Cantidad', 'Condición', 'Acabado'],
      ['122/131', 'Lucario GX', 'Español', 2, 'LP', 'Holo'],
      ['016/165', 'Pidgey', 'inglés', null, '', ''],
      ['', '', '', '', '', ''], // vacía: se ignora
    ]);
    expect(r.invalidas, isEmpty);
    final l = r.cartas.first;
    expect((l.nombre, l.numero, l.idioma, l.cantidad, l.condicion, l.acabado),
        ('Lucario GX', '122/131', Idioma.espanol, 2, Condicion.lp, Acabado.holo));
    expect(l.id, startsWith('imp-'));
    final p = r.cartas.last;
    expect((p.idioma, p.cantidad, p.condicion, p.acabado), (Idioma.ingles, 1, Condicion.nm, Acabado.normal));
  });

  test('filas con errores se informan con su número', () {
    final r = importarFilas([
      ['nombre', 'idioma', 'cantidad'],
      ['Mew', 'francés', 1],
      ['Eevee', 'en', 1.5],
      ['Snorlax', 'en', 3],
    ]);
    expect(r.cartas.map((c) => c.nombre), ['Snorlax']);
    expect(r.invalidas.map((f) => f.numeroFila), [2, 3]);
  });

  test('sin columnas Nombre e Idioma no importa nada y lo explica', () {
    final r = importarFilas([
      ['carta?', 'precio'],
      ['Mew', 100],
    ]);
    expect(r.cartas, isEmpty);
    expect(r.invalidas.single.motivo, contains('Nombre'));
    expect(importarFilas([]).invalidas.single.motivo, contains('vacío'));
  });

  test('lo exportado se puede volver a importar igual', () {
    const cartas = [
      CartaColeccion(
          id: 'c1',
          nombre: 'Lucario GX',
          idioma: Idioma.espanol,
          numero: '122/131',
          acabado: Acabado.holo,
          tcgmatchId: 44078),
      CartaColeccion(
          id: 'c2',
          nombre: 'ピカチュウ',
          idioma: Idioma.japones,
          gradeo: Gradeo(empresa: 'PSA', nota: '10'),
          valorManualClp: 450000),
    ];
    final filas = exportarFilas(cartas, {'c1': const ValorCarta(publicadoClp: 34783, ventasClp: 45540)});
    expect(filas.first.last, 'valor_ventas_clp');
    expect(filas[1].sublist(filas[1].length - 2), [34783, 45540]);
    final r = importarFilas(filas);
    expect(r.invalidas, isEmpty);
    expect(r.cartas.map((c) => (c.id, c.nombre, c.tcgmatchId, c.gradeo?.nota, c.valorManualClp)),
        [('c1', 'Lucario GX', 44078, null, null), ('c2', 'ピカチュウ', null, '10', 450000)]);
  });

  test('sin id, el id se calcula con los datos: reimportar no duplica', () {
    final filas = [
      ['nombre', 'idioma', 'numero'],
      ['Pidgey', 'en', '016/165'],
      ['Budew', 'en', '004/131'],
    ];
    final a = importarFilas(filas).cartas.map((c) => c.id).toList();
    final b = importarFilas(filas).cartas.map((c) => c.id).toList();
    expect(a, b);
    expect(a.toSet().length, 2);
  });

  test('filas repetidas, cantidad 0 o valor manual negativo se informan', () {
    final r = importarFilas([
      ['id', 'nombre', 'idioma', 'cantidad', 'valor_manual_clp', 'gradeadora'],
      ['x1', 'Mew', 'en', 1, '', ''],
      ['x1', 'Mew otra', 'en', 1, '', ''],
      ['', 'Eevee', 'en', 0, '', ''],
      ['', 'Pikachu', 'ja', 1, -5, 'PSA'],
      ['', 'Snorlax', 'en', 2, '', ''],
      ['', 'snorlax', 'EN', 1, '', ''],
    ]);
    expect(r.cartas.map((c) => c.nombre), ['Mew', 'Snorlax']);
    expect(r.invalidas.map((f) => f.numeroFila), [3, 4, 5, 7]);
    expect(r.invalidas.first.motivo, contains('repite'));
    expect(r.invalidas[1].motivo, contains('1 o más'));
    expect(r.invalidas[2].motivo, contains('negativo'));
  });
}

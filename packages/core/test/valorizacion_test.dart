import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

void main() {
  final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime(2026, 10, 30));
  const carta = CartaColeccion(id: '1', nombre: 'Lucario GX', idioma: Idioma.espanol);

  Cotizacion cot(TipoPrecio tipo, Moneda moneda, double valor) =>
      Cotizacion(fuente: 'x', tipo: tipo, moneda: moneda, valor: valor);

  test('mediana', () {
    expect(mediana([]), isNull);
    expect(mediana([3, 1, 2]), 2);
    expect(mediana([4, 1, 3, 2]), 2.5);
  });

  test('publicado es la mediana en CLP de todas las fuentes', () {
    final v = valorizar(
        carta,
        [
          cot(TipoPrecio.publicado, Moneda.clp, 30000),
          cot(TipoPrecio.publicado, Moneda.usd, 35), // 35.000
          cot(TipoPrecio.publicado, Moneda.eur, 10), // 11.000
        ],
        cambio);
    expect(v.publicadoClp, 30000);
  });

  test('ventas prefiere las ventas en CLP (mercado chileno)', () {
    final v = valorizar(
        carta,
        [
          cot(TipoPrecio.ventas, Moneda.clp, 27000),
          cot(TipoPrecio.ventas, Moneda.eur, 40),
        ],
        cambio);
    expect(v.ventasClp, 27000);
  });

  test('sin ventas en CLP usa las de otras fuentes convertidas', () {
    final v = valorizar(carta, [cot(TipoPrecio.ventas, Moneda.eur, 10)], cambio);
    expect(v.ventasClp, 11000);
  });

  test('gradeadas usan el valor manual', () {
    const gradeada = CartaColeccion(
        id: '2',
        nombre: 'Pikachu',
        idioma: Idioma.japones,
        gradeo: Gradeo(empresa: 'PSA', nota: '10'),
        valorManualClp: 500000);
    final v = valorizar(gradeada, [cot(TipoPrecio.publicado, Moneda.usd, 1)], cambio);
    expect(v.manual, isTrue);
    expect(v.publicadoClp, 500000);
  });

  test('valor de la colección multiplica por cantidad', () {
    const dos = CartaColeccion(id: '3', nombre: 'Exeggcute', idioma: Idioma.ingles, cantidad: 2);
    final total = valorColeccion([
      (dos, const ValorCarta(publicadoClp: 300, ventasClp: 400)),
      (carta, const ValorCarta(publicadoClp: 1000)),
    ]);
    expect(total.publicadoClp, 1600);
    expect(total.ventasClp, 1800); // la carta sin ventas aporta su publicado
  });
}

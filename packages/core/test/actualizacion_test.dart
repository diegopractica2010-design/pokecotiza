import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:pokecotiza_core/testing.dart';
import 'package:test/test.dart';

String fixture(String nombre) => File('test/fixtures/$nombre').readAsStringSync();

Cotizador cotizador({bool tcgmatchCaido = false, bool mindicadorCaido = false}) {
  http.Response r(String c) =>
      http.Response.bytes(utf8.encode(c), 200, headers: {'content-type': 'text/plain; charset=utf-8'});
  final h = ClienteCortes(
    pausaMinima: Duration.zero,
    cliente: MockClient((req) async {
      if (req.url.host == 'tcgmatch.cl') {
        return tcgmatchCaido ? http.Response('', 503) : r(fixture('tcgmatch_catalogo.html'));
      }
      if (req.url.host == 'mindicador.cl') {
        return mindicadorCaido ? http.Response('', 503) : r(fixture('mindicador.json'));
      }
      return r(fixture('tcgdex_carta_es.json'));
    }),
  );
  return Cotizador(tcgdex: TcgdexCliente(h), tcgmatch: TcgmatchCliente(h), mindicador: MindicadorCliente(h));
}

void main() {
  late SheetsFalso falso;
  late PlanillaColeccion planilla;

  setUp(() async {
    falso = SheetsFalso();
    planilla = await PlanillaColeccion.crear(SheetsCliente(() async => 'token-prueba', cliente: falso.cliente));
    await planilla.guardarCarta(const CartaColeccion(
        id: 'c1',
        nombre: 'Lucario GX',
        idioma: Idioma.ingles,
        acabado: Acabado.holo,
        tcgdexId: 'sm6-122',
        tcgmatchId: 43946));
    await planilla.guardarCarta(const CartaColeccion(
        id: 'c2',
        nombre: 'Pikachu',
        idioma: Idioma.japones,
        gradeo: Gradeo(empresa: 'PSA', nota: '10'),
        valorManualClp: 450000,
        cantidad: 2));
  });

  test('cotiza todas, registra precios, resumen y tipo de cambio', () async {
    final r = await actualizarColeccion(planilla, cotizador(), ahora: DateTime.utc(2026, 10, 31, 10));
    expect((r.cartas, r.cotizadas), (2, 2));
    expect(r.fallas, isEmpty);
    expect((await planilla.historial('c1')).length, greaterThanOrEqualTo(3));
    final resumen = falso.hojas['Resumen']!.last;
    expect(resumen.first, '2026-10-31T10:00:00.000Z');
    expect(resumen[1], greaterThan(900000)); // incluye 2 × 450.000 de la gradeada
    expect((await planilla.leerTipoCambio())?.usd, 993.22);
    expect(r.resumen(), contains('Cartas: 2'));
  });

  test('si TCGmatch falla, sigue y lo informa', () async {
    final r = await actualizarColeccion(planilla, cotizador(tcgmatchCaido: true));
    expect(r.fallas['Lucario GX']!.keys, ['TCGmatch']);
    expect(r.cotizadas, 2);
    expect(r.resumen(), contains('TCGmatch no respondió'));
  });

  test('si mindicador falla, usa el tipo de cambio guardado en la planilla', () async {
    await planilla.guardarTipoCambio(TipoCambio(usd: 950, eur: 1000, fecha: DateTime.utc(2026, 10, 29)));
    final r = await actualizarColeccion(planilla, cotizador(mindicadorCaido: true));
    expect(r.cambio.usd, 950);
  });
}

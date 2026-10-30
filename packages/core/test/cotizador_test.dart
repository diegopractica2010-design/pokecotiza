import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

String fixture(String nombre) => File('test/fixtures/$nombre').readAsStringSync();

Cotizador cotizadorFalso({bool tcgmatchCaido = false, List<Uri>? pedidas}) {
  final http_ = ClienteCortes(
    pausaMinima: Duration.zero,
    cliente: MockClient((req) async {
      pedidas?.add(req.url);
      if (req.url.host == 'tcgmatch.cl') {
        if (tcgmatchCaido) return http.Response('', 503);
        return http.Response.bytes(utf8.encode(fixture('tcgmatch_catalogo.html')), 200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return http.Response.bytes(utf8.encode(fixture('tcgdex_carta_es.json')), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  );
  return Cotizador(
      tcgdex: TcgdexCliente(http_), tcgmatch: TcgmatchCliente(http_), mindicador: MindicadorCliente(http_));
}

void main() {
  final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30));
  const carta = CartaColeccion(
      id: 'c1',
      nombre: 'Lucario GX',
      idioma: Idioma.ingles,
      acabado: Acabado.holo,
      tcgdexId: 'sm6-122',
      tcgmatchId: 43946);

  test('junta TCGdex y TCGmatch y calcula el valor', () async {
    final r = await cotizadorFalso().cotizar(carta, cambio);
    expect(r.fallas, isEmpty);
    expect(r.cotizaciones.map((c) => c.fuente).toSet(), {'TCGmatch', 'Cardmarket', 'TCGplayer'});
    // Ventas: prefiere la de TCGmatch en CLP (inglés, mediana 400).
    expect(r.valor.ventasClp, 400);
  });

  test('si TCGmatch falla, sigue con TCGdex y lo informa', () async {
    final r = await cotizadorFalso(tcgmatchCaido: true).cotizar(carta, cambio);
    expect(r.fallas.keys, ['TCGmatch']);
    expect(r.cotizaciones.map((c) => c.fuente).toSet(), {'Cardmarket', 'TCGplayer'});
    expect(r.valor.publicadoClp, isNotNull);
  });

  test('una carta sin vínculos no consulta nada', () async {
    final pedidas = <Uri>[];
    final r = await cotizadorFalso(pedidas: pedidas)
        .cotizar(const CartaColeccion(id: 'c2', nombre: 'X', idioma: Idioma.espanol), cambio);
    expect(pedidas, isEmpty);
    expect(r.valor.publicadoClp, isNull);
  });

  test('las gradeadas usan el valor manual sin consultar fuentes', () async {
    final pedidas = <Uri>[];
    final r = await cotizadorFalso(pedidas: pedidas).cotizar(
        const CartaColeccion(
            id: 'c3',
            nombre: 'Pikachu',
            idioma: Idioma.japones,
            tcgdexId: 'x',
            gradeo: Gradeo(empresa: 'PSA', nota: '10'),
            valorManualClp: 450000),
        cambio);
    expect(pedidas, isEmpty);
    expect((r.valor.manual, r.valor.publicadoClp), (true, 450000));
  });
}

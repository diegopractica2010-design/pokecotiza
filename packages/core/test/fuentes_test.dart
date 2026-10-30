import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

String fixture(String nombre) => File('test/fixtures/$nombre').readAsStringSync();

ClienteCortes clienteFalso(Map<String, String> respuestas, {List<Uri>? pedidas}) => ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        pedidas?.add(req.url);
        final cuerpo = respuestas[req.url.path];
        if (cuerpo == null) return http.Response('no encontrado', 404);
        return http.Response.bytes(utf8.encode(cuerpo), 200, headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );

void main() {
  group('TCGmatch', () {
    test('lee precios por idioma y mediana de ventas de la página de catálogo', () {
      final p = leerCatalogoTcgmatch(fixture('tcgmatch_catalogo.html'));
      expect(p.idCatalogo, 43946);
      expect(p.nombre, 'Exeggcute');
      expect(p.codigo, '1/131');
      expect(p.general.mercado, 200);
      expect(p.general.ventasCantidad, 8);
      expect(p.general.ventasMediana, 200);
      expect(p.porIdioma[Idioma.espanol]!.mercado, 150);
      expect(p.porIdioma[Idioma.espanol]!.ventasCantidad, isNull);
      expect(p.porIdioma[Idioma.ingles]!.ventasMediana, 400);
      expect(p.porIdioma.containsKey(Idioma.japones), isFalse);
    });

    test('cotizaciones no mezclan idiomas', () {
      final p = leerCatalogoTcgmatch(fixture('tcgmatch_catalogo.html'));
      final en = cotizacionesDesdeTcgmatch(p, Idioma.ingles);
      expect(en.map((c) => (c.tipo, c.valor)), [(TipoPrecio.publicado, 350.0), (TipoPrecio.ventas, 400.0)]);
      expect(en.first.url.toString(), 'https://tcgmatch.cl/producto/catalogo/43946');
      final es = cotizacionesDesdeTcgmatch(p, Idioma.espanol);
      expect(es.map((c) => c.tipo), [TipoPrecio.publicado]);
      expect(cotizacionesDesdeTcgmatch(p, Idioma.japones), isEmpty);
    });

    test('analiza enlaces de carta y de publicación', () {
      expect((analizarEnlaceTcgmatch('https://tcgmatch.cl/producto/catalogo/43946') as EnlaceCatalogo).id, 43946);
      expect(
          (analizarEnlaceTcgmatch(' https://tcgmatch.cl/producto/64e1875e1506843f0f4a3604 ') as EnlacePublicacion).id,
          '64e1875e1506843f0f4a3604');
      expect(analizarEnlaceTcgmatch('https://tcgmatch.cl/cartas/pokemon'), isNull);
      expect(analizarEnlaceTcgmatch('https://otro.cl/producto/catalogo/1'), isNull);
    });

    test('resuelve una publicación a su carta sin tocar /api/', () async {
      final pedidas = <Uri>[];
      final cliente = TcgmatchCliente(clienteFalso({
        '/producto/64e1875e1506843f0f4a3604': fixture('tcgmatch_producto.html'),
      }, pedidas: pedidas));
      expect(await cliente.resolverEnlace('https://tcgmatch.cl/producto/64e1875e1506843f0f4a3604'), 44078);
      expect(pedidas.any((u) => u.path.startsWith('/api/')), isFalse);
    });

    test('una página sin __NEXT_DATA__ da FormatoInesperado', () {
      expect(() => leerCatalogoTcgmatch('<html></html>'), throwsA(isA<FormatoInesperado>()));
    });
  });

  group('TCGdex', () {
    test('holo: Cardmarket usa campos normales y TCGplayer la variante holofoil', () {
      final c = leerCartaTcgdex(fixture('tcgdex_carta_es.json'), acabado: Acabado.holo);
      expect(c.id, 'sm6-122');
      expect(c.nombre, 'Lucario GX');
      expect(c.nombreSet, 'Luz Prohibida');
      final porDetalle = {for (final q in c.cotizaciones) q.detalle: q};
      expect(porDetalle['cardmarket trend vía TCGdex']!.valor, 33.81);
      expect(porDetalle['cardmarket avg30 vía TCGdex']!.tipo, TipoPrecio.ventas);
      expect(porDetalle['cardmarket avg30 vía TCGdex']!.valor, 41.05);
      expect(porDetalle['tcgplayer holofoil marketPrice vía TCGdex']!.valor, 35.02);
      expect(porDetalle['tcgplayer holofoil marketPrice vía TCGdex']!.moneda, Moneda.usd);
    });

    test('reverse holo: Cardmarket usa los campos -holo y omite TCGplayer si no tiene esa variante', () {
      final c = leerCartaTcgdex(fixture('tcgdex_carta_es.json'), acabado: Acabado.reverseHolo);
      expect(c.cotizaciones.map((q) => q.detalle),
          ['cardmarket trend-holo vía TCGdex', 'cardmarket avg30-holo vía TCGdex']);
      expect(c.cotizaciones.first.valor, 11.56);
    });

    test('normal: si TCGplayer solo tiene holofoil, no se usa (no mezcla acabados)', () {
      final c = leerCartaTcgdex(fixture('tcgdex_carta_es.json'));
      expect(c.cotizaciones.where((q) => q.fuente == 'TCGplayer'), isEmpty);
      expect(c.cotizaciones.map((q) => q.detalle), ['cardmarket trend vía TCGdex', 'cardmarket avg30 vía TCGdex']);
    });

    test('búsqueda descarta cartas de TCG Pocket', () async {
      final pedidas = <Uri>[];
      final cliente = TcgdexCliente(clienteFalso({
        '/v2/en/cards': fixture('tcgdex_busqueda.json'),
      }, pedidas: pedidas));
      final r = await cliente.buscar(idioma: Idioma.ingles, nombre: 'lucario', numeroLocal: '122');
      expect(r.map((e) => e.id), ['sm6-122', 'dp2-122']);
      expect(pedidas.single.queryParameters, {'name': 'lucario', 'localId': '122'});
      expect(const ResultadoTcgdex(id: 'A2b-043', numeroLocal: '043', nombre: 'Lucario ex').esTcgPocket, isTrue);
    });
  });

  test('TCGdex reintenta sin ceros a la izquierda si no hay resultados', () async {
    final pedidas = <String?>[];
    final cliente = TcgdexCliente(ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        final local = req.url.queryParameters['localId'];
        pedidas.add(local);
        return http.Response(local == '25' ? '[{"id":"sv3pt5-25","localId":"25","name":"Pikachu"}]' : '[]', 200);
      }),
    ));
    final r = await cliente.buscar(idioma: Idioma.ingles, nombre: 'pikachu', numeroLocal: '025');
    expect(pedidas, ['025', '25']);
    expect(r.single.id, 'sv3pt5-25');
  });

  test('TCGdex reintenta con el nombre sin guion y luego con la primera palabra', () async {
    final pedidas = <String?>[];
    final cliente = TcgdexCliente(ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        final nombre = req.url.queryParameters['name'];
        pedidas.add(nombre);
        return http.Response(
            nombre == 'Lucario' ? '[{"id":"sm6-122","localId":"122","name":"Lucario GX"}]' : '[]', 200);
      }),
    ));
    final r = await cliente.buscar(idioma: Idioma.espanol, nombre: 'Lucario-GX', numeroLocal: '122');
    expect(pedidas, ['Lucario-GX', 'Lucario GX', 'Lucario']);
    expect(r.single.id, 'sm6-122');
  });

  test('TCGdex deja solo números exactos y ordena por total de la expansión', () async {
    final cliente = TcgdexCliente(ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        if (req.url.path.endsWith('/cards')) {
          return http.Response(
              '[{"id":"sm5-1","localId":"1","name":"Exeggcute"},{"id":"sm6-1","localId":"1","name":"Exeggcute"},'
              '{"id":"bw10-102","localId":"102","name":"Exeggcute"},{"id":"sv08.5-001","localId":"001","name":"Exeggcute"}]',
              200);
        }
        final oficial = {'sm5': 156, 'sm6': 131, 'sv08.5': 131}[req.url.pathSegments.last];
        return http.Response('{"cardCount":{"official":$oficial}}', 200);
      }),
    ));
    final r = await cliente.buscar(idioma: Idioma.ingles, nombre: 'Exeggcute', numeroLocal: '1', totalSet: 131);
    expect(r.map((e) => e.id), ['sm6-1', 'sv08.5-001', 'sm5-1']);
  });

  test('ClienteCortes separa peticiones simultáneas al mismo dominio', () async {
    final inicios = <DateTime>[];
    final cliente = ClienteCortes(
      pausaMinima: const Duration(milliseconds: 200),
      cliente: MockClient((req) async {
        inicios.add(DateTime.now());
        return http.Response('ok', 200);
      }),
    );
    final uri = Uri.parse('https://ejemplo.cl/a');
    await Future.wait([for (var i = 0; i < 3; i++) cliente.obtenerTexto(uri, fuente: 'prueba')]);
    inicios.sort();
    for (var i = 1; i < inicios.length; i++) {
      expect(inicios[i].difference(inicios[i - 1]).inMilliseconds, greaterThanOrEqualTo(190));
    }
  });

  test('TCGdex limita cuántas expansiones consulta por búsqueda', () async {
    var consultasSet = 0;
    final cartas = [for (var i = 0; i < 20; i++) '{"id":"set$i-1","localId":"1","name":"X"}'].join(',');
    final cliente = TcgdexCliente(ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        if (req.url.path.endsWith('/cards')) return http.Response('[$cartas]', 200);
        consultasSet++;
        return http.Response('{"cardCount":{"official":131}}', 200);
      }),
    ));
    final r = await cliente.buscar(idioma: Idioma.ingles, nombre: 'X', numeroLocal: '1', totalSet: 131);
    expect(r, hasLength(20));
    expect(consultasSet, TcgdexCliente.maxExpansionesPorBusqueda);
  });

  test('TCGdex reintenta el total de una expansión si antes falló', () async {
    var fallar = true;
    final cliente = TcgdexCliente(ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient(
          (req) async => fallar ? http.Response('', 503) : http.Response('{"cardCount":{"official":131}}', 200)),
    ));
    expect(await cliente.totalOficialSet(Idioma.ingles, 'sm6'), isNull);
    fallar = false;
    expect(await cliente.totalOficialSet(Idioma.ingles, 'sm6'), 131);
  });

  group('mindicador', () {
    test('lee dólar y euro', () {
      final t = leerMindicador(fixture('mindicador.json'));
      expect(t.usd, 993.22);
      expect(t.eur, 1109.37);
      expect(t.aClp(10, Moneda.usd), closeTo(9932.2, 0.001));
    });

    test('si el servicio falla usa el último tipo de cambio conocido', () async {
      final cliente = MindicadorCliente(ClienteCortes(
        pausaMinima: Duration.zero,
        cliente: MockClient((_) async => http.Response('', 503)),
      ));
      final ultimo = TipoCambio(usd: 950, eur: 1000, fecha: DateTime(2026, 10, 29));
      expect((await cliente.obtener(ultimoConocido: ultimo)).usd, 950);
      expect(cliente.obtener(), throwsA(isA<FuenteNoDisponible>()));
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:pokecotiza_core/testing.dart';
import 'package:test/test.dart';

String fixture(String nombre) => File('test/fixtures/$nombre').readAsStringSync();
final afk = tiendasShopify.single;

void main() {
  test('reconoce enlaces de producto de AFK Store', () {
    final e =
        analizarEnlaceTienda('https://www.afkstore.cl/products/mega-charizard-x-ex-125-094?variant=50624175079719');
    expect((e?.tienda.id, e?.handle), ('afkstore', 'mega-charizard-x-ex-125-094'));
    expect(
        analizarEnlaceTienda('https://afkstore.cl/collections/singles-pokemon/products/lugia-149-147-aquapolis-aq')
            ?.handle,
        'lugia-149-147-aquapolis-aq');
    expect(analizarEnlaceTienda('https://otra.cl/products/x'), isNull);
    expect(analizarEnlaceTienda('https://www.afkstore.cl/collections/singles-pokemon'), isNull);
  });

  test('interpreta variantes de idioma y condición; ignora las que no entiende', () {
    expect(interpretarVariante('Ingles'), (idioma: Idioma.ingles, condicion: Condicion.nm));
    expect(interpretarVariante('Español (Lp)'), (idioma: Idioma.espanol, condicion: Condicion.lp));
    expect(interpretarVariante('ingles (HP)'), (idioma: Idioma.ingles, condicion: Condicion.hp));
    expect(interpretarVariante('Ingles (Pikachu 173 no Raw. esta Psa 8)'), isNull);
  });

  test('lee el producto real (precios en centavos) y cotiza según idioma y condición', () {
    final p = leerProductoShopify(afk, fixture('afk_producto.js'));
    expect(p.titulo, 'Mega Charizard X Ex 125/094');
    expect(p.variantes.map((v) => (v.titulo, v.precioClp)),
        [('Ingles', 700000), ('Español', 350000), ('Español (Lp)', 280000)]);
    CartaColeccion carta(Idioma i, Condicion c) => CartaColeccion(id: 'x', nombre: 'MCX', idioma: i, condicion: c);
    expect(cotizacionesDesdeTienda(p, carta(Idioma.espanol, Condicion.lp)).single.valor, 280000);
    expect(cotizacionesDesdeTienda(p, carta(Idioma.ingles, Condicion.nm)).single.url.toString(),
        'https://www.afkstore.cl/products/mega-charizard-x-ex-125-094');
    expect(cotizacionesDesdeTienda(p, carta(Idioma.japones, Condicion.nm)), isEmpty);
    expect(cotizacionesDesdeTienda(p, carta(Idioma.ingles, Condicion.mp)), isEmpty);
  });

  test('lee la búsqueda real', () {
    final r = leerBusquedaShopify(afk, fixture('afk_busqueda.json'));
    expect(r.first.handle, 'charizard-base-set-4-102-espanol');
    expect(r.first.precioDesdeClp, 700000);
  });

  test('el cotizador suma la tienda vinculada y una falla de la tienda no detiene el resto', () async {
    var tiendaCaida = false;
    final h = ClienteCortes(
      pausaMinima: Duration.zero,
      cliente: MockClient((req) async {
        if (req.url.host == 'www.afkstore.cl') {
          return tiendaCaida
              ? http.Response('', 503)
              : http.Response.bytes(utf8.encode(fixture('afk_producto.js')), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('', 404);
      }),
    );
    final c = Cotizador(
        tcgdex: TcgdexCliente(h),
        tcgmatch: TcgmatchCliente(h),
        mindicador: MindicadorCliente(h),
        tiendas: TiendaShopifyCliente(h));
    const carta = CartaColeccion(
        id: 'x', nombre: 'MCX', idioma: Idioma.espanol, enlacesTiendas: {'afkstore': 'mega-charizard-x-ex-125-094'});
    final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026));
    expect((await c.cotizar(carta, cambio)).valor.publicadoClp, 350000);
    tiendaCaida = true;
    expect((await c.cotizar(carta, cambio)).fallas.keys, ['AFK Store']);
  });

  test('los vínculos con tiendas se guardan en la planilla (columna nueva al final)', () async {
    final falso = SheetsFalso();
    final p = await PlanillaColeccion.crear(SheetsCliente(() async => 'token-prueba', cliente: falso.cliente));
    await p.guardarCarta(const CartaColeccion(
        id: 'x', nombre: 'MCX', idioma: Idioma.espanol, enlacesTiendas: {'afkstore': 'mega-charizard-x-ex-125-094'}));
    expect(falso.hojas['Coleccion']!.first.last, 'tiendas');
    expect((await p.leerColeccion()).cartas.single.enlacesTiendas, {'afkstore': 'mega-charizard-x-ex-125-094'});
  });
}

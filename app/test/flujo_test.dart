import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecotiza/main.dart';
import 'package:pokecotiza/servicios/almacen.dart';
import 'package:pokecotiza/servicios/estado.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

/// Respuestas reales guardadas del núcleo (2026-10-30).
String fixture(String nombre) => File('../packages/core/test/fixtures/$nombre').readAsStringSync();

class AlmacenMemoria implements Almacen {
  final Map<String, CartaColeccion> cartas = {};
  final Map<String, CotizacionGuardada> cots = {};
  TipoCambio? cambio;

  @override
  String get descripcion => 'memoria';
  @override
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerCartas() async =>
      (cartas: cartas.values.toList(), invalidas: <FilaInvalida>[]);
  @override
  Future<void> guardarCarta(CartaColeccion carta) async => cartas[carta.id] = carta;
  @override
  Future<void> eliminarCarta(String id) async => cartas.remove(id);
  @override
  Future<Map<String, CotizacionGuardada>> leerCotizaciones() async => cots;
  @override
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c) async => cots[idCarta] = c;
  @override
  Future<void> eliminarCotizacion(String idCarta) async => cots.remove(idCarta);
  final List<PuntoValor> resumen = [];
  @override
  Future<List<PuntoValor>> historialCarta(CartaColeccion carta) async => const [];
  @override
  Future<List<PuntoValor>> historialColeccion() async => resumen;
  @override
  Future<void> registrarResumen(({int publicadoClp, int ventasClp}) total, int cartas, DateTime fecha) async =>
      resumen.add(PuntoValor(fecha: fecha, publicadoClp: total.publicadoClp, ventasClp: total.ventasClp));
  @override
  Future<TipoCambio?> leerTipoCambio() async => cambio;
  @override
  Future<void> guardarTipoCambio(TipoCambio t) async => cambio = t;
}

EstadoApp estadoDePrueba(AlmacenMemoria almacen, {bool mindicadorCaido = false, bool fuentesCaidas = false}) {
  http.Response r(String cuerpo, String tipo) =>
      http.Response.bytes(utf8.encode(cuerpo), 200, headers: {'content-type': '$tipo; charset=utf-8'});
  final cliente = ClienteCortes(
    pausaMinima: Duration.zero,
    cliente: MockClient((req) async {
      final u = req.url;
      if (fuentesCaidas && (u.host == 'tcgmatch.cl' || u.host == 'api.tcgdex.net')) return http.Response('', 503);
      if (u.host == 'tcgmatch.cl') return r(fixture('tcgmatch_catalogo.html'), 'text/html');
      if (u.host == 'www.afkstore.cl') return r(fixture('afk_producto.js'), 'application/json');
      if (u.host == 'mindicador.cl') {
        return mindicadorCaido
            ? http.Response('<html>error</html>', 200)
            : r(fixture('mindicador.json'), 'application/json');
      }
      if (u.path.endsWith('/cards')) return r(fixture('tcgdex_busqueda.json'), 'application/json');
      if (u.path.contains('/sets/')) return r('{"cardCount":{"official":131}}', 'application/json');
      if (u.path.contains('/cards/')) return r(fixture('tcgdex_carta_es.json'), 'application/json');
      return http.Response('', 404);
    }),
  );
  final tcgdex = TcgdexCliente(cliente);
  final tcgmatch = TcgmatchCliente(cliente);
  return EstadoApp(
    almacen: almacen,
    cotizador: Cotizador(
        tcgdex: tcgdex,
        tcgmatch: tcgmatch,
        mindicador: MindicadorCliente(cliente),
        tiendas: TiendaShopifyCliente(cliente)),
    tcgdex: tcgdex,
    tcgmatch: tcgmatch,
  );
}

/// La lista desplazable de la pantalla visible (no la de un campo de texto).
final listaPrincipal =
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable), matchRoot: true).first;

void main() {
  testWidgets('agregar una carta: buscar, confirmar con TCGmatch y ver su valor', (tester) async {
    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen);
    await tester.pumpWidget(PokeCotizaApp(estado: estado));
    await estado.cargar();
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu colección está vacía'), findsOneWidget);

    await tester.tap(find.text('Agregar carta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Lucario-GX');
    await tester.enterText(find.widgetWithText(TextField, 'Número (ej. 122/131)'), '122/131');
    await tester.tap(find.text('Buscar en TCGdex'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elige la carta correcta'), findsOneWidget);

    await tester.tap(find.text('sm6-122 · número 122'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar carta'), findsOneWidget);
    await tester.tap(find.text('Holo'));
    await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Enlace de TCGmatch (opcional)'), 200,
        scrollable: listaPrincipal);
    await tester.enterText(
        find.widgetWithText(TextField, 'Enlace de TCGmatch (opcional)'), 'https://tcgmatch.cl/producto/catalogo/43946');
    await tester.scrollUntilVisible(find.text('Guardar y cotizar'), 200, scrollable: listaPrincipal);
    await tester.tap(find.text('Guardar y cotizar'));
    await tester.pumpAndSettle();

    // De vuelta en la colección, con la carta cotizada y guardada.
    expect(find.text('PokeCotiza'), findsOneWidget);
    expect(find.text('Lucario GX'), findsOneWidget);
    final guardada = almacen.cartas.values.single;
    expect((guardada.tcgdexId, guardada.tcgmatchId, guardada.acabado), ('sm6-122', 43946, Acabado.holo));
    final cot = almacen.cots[guardada.id]!;
    expect(cot.valor.publicadoClp, isNotNull);
    expect(cot.fallas, isEmpty);
    expect(almacen.cambio?.usd, 993.22);
  });

  testWidgets('vincular AFK Store suma su precio a la cotización', (tester) async {
    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen);
    await tester.pumpWidget(PokeCotizaApp(estado: estado));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar carta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Lucario');
    await tester.tap(find.text('Buscar en TCGdex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sm6-122 · número 122'));
    await tester.pumpAndSettle();
    final campo = find.widgetWithText(TextField, 'Enlace de AFK Store (opcional)');
    await tester.scrollUntilVisible(campo, 200, scrollable: listaPrincipal);
    await tester.enterText(campo, 'https://www.afkstore.cl/products/mega-charizard-x-ex-125-094');
    await tester.scrollUntilVisible(find.text('Guardar y cotizar'), 200, scrollable: listaPrincipal);
    await tester.tap(find.text('Guardar y cotizar'));
    await tester.pumpAndSettle();
    final carta = almacen.cartas.values.single;
    expect(carta.enlacesTiendas, {'afkstore': 'mega-charizard-x-ex-125-094'});
    // La carta es en español NM: la variante "Español" de la tienda vale $350.000.
    expect(almacen.cots[carta.id]!.cotizaciones.where((c) => c.fuente == 'AFK Store').single.valor, 350000);
  });

  testWidgets('un enlace que no es de TCGmatch muestra un error y no guarda', (tester) async {
    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen);
    await tester.pumpWidget(PokeCotizaApp(estado: estado));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar carta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Lucario');
    await tester.tap(find.text('Buscar en TCGdex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sm6-122 · número 122'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Enlace de TCGmatch (opcional)'), 200,
        scrollable: listaPrincipal);
    await tester.enterText(find.widgetWithText(TextField, 'Enlace de TCGmatch (opcional)'), 'https://otro.cl/x');
    await tester.scrollUntilVisible(find.text('Guardar y cotizar'), 200, scrollable: listaPrincipal);
    await tester.tap(find.text('Guardar y cotizar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no es de una carta de TCGmatch'), findsOneWidget);
    expect(almacen.cartas, isEmpty);
  });

  test('el almacén local guarda y relee cartas y cotizaciones', () async {
    final dir = await Directory.systemTemp.createTemp('pokecotiza');
    final a = AlmacenLocal(File('${dir.path}/coleccion.json'));
    const carta = CartaColeccion(id: 'c1', nombre: 'Pidgey', idioma: Idioma.ingles, cantidad: 2);
    await a.guardarCarta(carta);
    await a.guardarCarta(const CartaColeccion(id: 'c1', nombre: 'Pidgey', idioma: Idioma.ingles, cantidad: 3));
    await a.guardarCotizacion(
        'c1',
        CotizacionGuardada(
            fecha: DateTime.utc(2026, 10, 30),
            valor: const ValorCarta(publicadoClp: 199, ventasClp: 151),
            cotizaciones: const [
              Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.ventas, moneda: Moneda.clp, valor: 151),
            ]));
    final otra = AlmacenLocal(File('${dir.path}/coleccion.json'));
    final leidas = await otra.leerCartas();
    expect(leidas.cartas.single.cantidad, 3);
    expect((await otra.leerCotizaciones())['c1']!.valor.ventasClp, 151);
    await otra.eliminarCarta('c1');
    expect((await otra.leerCartas()).cartas, isEmpty);
    await dir.delete(recursive: true);
  });

  test('guardados simultáneos en el almacén local no se pisan', () async {
    final dir = await Directory.systemTemp.createTemp('pokecotiza');
    final a = AlmacenLocal(File('${dir.path}/coleccion.json'));
    await Future.wait([
      for (var i = 0; i < 10; i++) a.guardarCarta(CartaColeccion(id: 'c$i', nombre: 'Carta $i', idioma: Idioma.ingles)),
    ]);
    expect((await a.leerCartas()).cartas.length, 10);
    await dir.delete(recursive: true);
  });

  test('una gradeada se guarda con su valor aunque el dólar no esté disponible', () async {
    final almacen = AlmacenMemoria();
    final estado = estadoDePrueba(almacen, mindicadorCaido: true);
    final cot = await estado.guardarYCotizar(const CartaColeccion(
        id: 'g1',
        nombre: 'Pikachu',
        idioma: Idioma.japones,
        gradeo: Gradeo(empresa: 'PSA', nota: '10'),
        valorManualClp: 450000));
    expect(cot?.valor.publicadoClp, 450000);
    expect(estado.total.publicadoClp, 450000);
  });

  test('si el dólar falla al actualizar, el botón no queda bloqueado', () async {
    final almacen = AlmacenMemoria()
      ..cartas['c1'] = const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol, tcgdexId: 'sm6-122');
    final estado = estadoDePrueba(almacen, mindicadorCaido: true);
    await estado.cargar();
    await estado.actualizarPrecios();
    expect(estado.progreso, isNull);
    expect(estado.error, contains('mindicador'));
  });
}

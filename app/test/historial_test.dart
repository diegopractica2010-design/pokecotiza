import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokecotiza/pantallas/grafico.dart';
import 'package:pokecotiza/pantallas/historial_futuro.dart';
import 'package:pokecotiza/servicios/almacen.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:pokecotiza_core/testing.dart';

import 'flujo_test.dart' show estadoDePrueba, AlmacenMemoria;

void main() {
  test('el almacén local guarda un punto por cotización y el resumen', () async {
    final dir = await Directory.systemTemp.createTemp('pokecotiza');
    final a = AlmacenLocal(File('${dir.path}/c.json'));
    const carta = CartaColeccion(id: 'c1', nombre: 'Pidgey', idioma: Idioma.ingles);
    for (final (dia, valor) in [(31, 250), (30, 199)]) {
      await a.guardarCotizacion(
          'c1',
          CotizacionGuardada(
              fecha: DateTime.utc(2026, 10, dia), valor: ValorCarta(publicadoClp: valor), cotizaciones: const []));
    }
    // Una cotización sin valor no agrega punto.
    await a.guardarCotizacion(
        'c1', CotizacionGuardada(fecha: DateTime.utc(2026, 11), valor: const ValorCarta(), cotizaciones: const []));
    expect((await a.historialCarta(carta)).map((p) => p.publicadoClp), [199, 250]);
    await a.registrarResumen((publicadoClp: 1000, ventasClp: 900), 1, DateTime.utc(2026, 10, 31));
    expect((await a.historialColeccion()).single.ventasClp, 900);
    await dir.delete(recursive: true);
  });

  test('actualizar precios registra el total del día', () async {
    final almacen = AlmacenMemoria()
      ..cartas['c1'] = const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol, tcgdexId: 'sm6-122');
    final estado = estadoDePrueba(almacen);
    await estado.cargar();
    final antes = estado.versionHistorial;
    await estado.actualizarPrecios();
    expect(almacen.resumen.single.publicadoClp, estado.total.publicadoClp);
    expect(estado.versionHistorial, greaterThan(antes));
  });

  testWidgets('el gráfico se dibuja con 0, 1 y varios puntos sin errores', (tester) async {
    Future<void> mostrar(List<PuntoValor> p) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: GraficoValor(puntos: p))));
    await mostrar(const []);
    expect(find.textContaining('Aún no hay historial'), findsOneWidget);
    await mostrar([PuntoValor(fecha: DateTime.utc(2026, 10, 30), publicadoClp: 30000)]);
    expect(find.text('Publicado'), findsOneWidget);
    await mostrar([
      PuntoValor(fecha: DateTime.utc(2026, 10, 30), publicadoClp: 30000, ventasClp: 28000),
      PuntoValor(fecha: DateTime.utc(2026, 10, 31), publicadoClp: 34783),
      PuntoValor(fecha: DateTime.utc(2026, 11, 1), publicadoClp: 33000, ventasClp: 45540),
    ]);
    expect(tester.takeException(), isNull);
  });

  test('con Google Sheets, el historial une la planilla y el dispositivo, y se reinicia al cambiar de carta', () async {
    final dir = await Directory.systemTemp.createTemp('pokecotiza');
    final falso = SheetsFalso();
    final planilla = await PlanillaColeccion.crear(SheetsCliente(() async => 'token-prueba', cliente: falso.cliente));
    final cache = AlmacenLocal(File('${dir.path}/c.json'));
    final a = AlmacenPlanilla(planilla, cache);
    const carta = CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol);
    // Punto solo local (de antes de conectar Google).
    await cache.guardarCotizacion(
        'c1',
        CotizacionGuardada(
            fecha: DateTime.utc(2026, 10, 1), valor: const ValorCarta(publicadoClp: 20000), cotizaciones: const []));
    // Punto en la planilla.
    await planilla.registrarPrecios(
        'c1',
        const [
          Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.publicado, moneda: Moneda.clp, valor: 30000),
        ],
        TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30)),
        fecha: DateTime.utc(2026, 10, 30));
    expect((await a.historialCarta(carta)).map((p) => p.publicadoClp), [20000, 30000]);

    await a.eliminarCotizacion('c1'); // el id pasa a ser otra carta
    expect(await a.historialCarta(carta), isEmpty);
    await dir.delete(recursive: true);
  });

  test('si todas las fuentes fallan, se conserva el último precio y no se registra el total', () async {
    final almacen = AlmacenMemoria()
      ..cartas['c1'] = const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol, tcgdexId: 'sm6-122')
      ..cartas['c2'] = const CartaColeccion(id: 'c2', nombre: 'Pidgey', idioma: Idioma.ingles, tcgdexId: 'sv03.5-016')
      ..cots['c1'] = CotizacionGuardada(
          fecha: DateTime(2026), valor: const ValorCarta(publicadoClp: 30000), cotizaciones: const []);
    final estado = estadoDePrueba(almacen, fuentesCaidas: true);
    await estado.cargar();
    await estado.actualizarPrecios();
    expect(estado.cotizaciones['c1']!.valor.publicadoClp, 30000); // no se pisó con un valor vacío
    expect(almacen.resumen, isEmpty); // Pidgey quedó sin valor: no se registra una baja falsa
    expect(estado.error, contains('no respondió'));
  });

  testWidgets('el gráfico no vuelve a leer el historial si no cambió la versión', (tester) async {
    var lecturas = 0;
    Future<List<PuntoValor>> cargar() async {
      lecturas++;
      return const [];
    }

    Future<void> mostrar(int version) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: HistorialFuturo(version: version, cargar: cargar))));
    await mostrar(1);
    await mostrar(1);
    await mostrar(1);
    expect(lecturas, 1);
    await mostrar(2);
    expect(lecturas, 2);
  });
}

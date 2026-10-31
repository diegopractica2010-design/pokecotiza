import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokecotiza/pantallas/grafico.dart';
import 'package:pokecotiza/servicios/almacen.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

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
}

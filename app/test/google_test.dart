import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokecotiza/main.dart';
import 'package:pokecotiza/pantallas/ajustes.dart';
import 'package:pokecotiza/servicios/ajustes.dart';
import 'package:pokecotiza/servicios/almacen.dart';
import 'package:pokecotiza/servicios/sesion_google.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:pokecotiza_core/testing.dart';

import 'flujo_test.dart' show estadoDePrueba, AlmacenMemoria;

class SesionFalsa implements SesionGoogle {
  bool conectado = false;
  int inicios = 0;
  @override
  Future<bool> conectada() async => conectado;
  @override
  Future<void> iniciar() async {
    inicios++;
    conectado = true;
  }

  @override
  Future<String> token() async => 'token-prueba';
  @override
  Future<void> cerrar() async => conectado = false;
}

/// Espera a que termine la conexión (operaciones reales de archivo) y
/// desaparezca la barra de progreso.
Future<void> esperarFinDeTrabajo(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  expect(find.byType(LinearProgressIndicator), findsNothing, reason: 'la conexión no terminó');
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('pokecotiza'));
  tearDown(() async => dir.delete(recursive: true));

  test('migrar sube solo las cartas que faltan en la planilla', () async {
    final falso = SheetsFalso();
    final planilla = await PlanillaColeccion.crear(SheetsCliente(() async => 'token-prueba', cliente: falso.cliente));
    final local = AlmacenLocal(File('${dir.path}/c.json'));
    await local.guardarCarta(const CartaColeccion(id: 'a', nombre: 'A', idioma: Idioma.ingles));
    await local.guardarCarta(const CartaColeccion(id: 'b', nombre: 'B', idioma: Idioma.ingles));
    await planilla.guardarCarta(const CartaColeccion(id: 'a', nombre: 'A', idioma: Idioma.ingles));
    expect(await migrarALaPlanilla(local, planilla), 1);
    expect((await planilla.leerColeccion()).cartas.map((c) => c.id), ['a', 'b']);
  });

  test('una cotización guardada se agrega al historial de la planilla', () async {
    final falso = SheetsFalso();
    final planilla = await PlanillaColeccion.crear(SheetsCliente(() async => 'token-prueba', cliente: falso.cliente));
    final a = AlmacenPlanilla(planilla, AlmacenLocal(File('${dir.path}/c.json')));
    await a.guardarTipoCambio(TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30)));
    await a.guardarCotizacion(
        'c1',
        CotizacionGuardada(
          fecha: DateTime.utc(2026, 10, 30, 12),
          valor: const ValorCarta(publicadoClp: 30000),
          cotizaciones: const [
            Cotizacion(fuente: 'TCGplayer', tipo: TipoPrecio.publicado, moneda: Moneda.usd, valor: 30),
          ],
        ));
    final h = await planilla.historial('c1');
    expect(h.single.valorClp, 30000);
    expect((await a.leerCotizaciones())['c1']!.valor.publicadoClp, 30000);
    expect((await planilla.leerTipoCambio())?.usd, 1000);
  });

  testWidgets('Ajustes: conectar con Google crea la planilla, sube las cartas y cambia el almacén', (tester) async {
    final falso = SheetsFalso();
    final sesion = SesionFalsa();
    final local = AlmacenLocal(File('${dir.path}/coleccion.json'));
    final ajustes = Ajustes(File('${dir.path}/ajustes.json'));
    final estado = estadoDePrueba(AlmacenMemoria())..almacen = local;
    await tester
        .runAsync(() => local.guardarCarta(const CartaColeccion(id: 'c1', nombre: 'Pidgey', idioma: Idioma.ingles)));

    await tester.pumpWidget(MaterialApp(
      home: PantallaAjustes(
        estado: estado,
        ajustes: ajustes,
        local: local,
        sesion: sesion,
        crearSheets: (s) => SheetsCliente(s.token, cliente: falso.cliente),
      ),
    ));
    expect(find.text('En este dispositivo.'), findsOneWidget);
    await tester.tap(find.text('Conectar con Google y crear planilla'));
    await esperarFinDeTrabajo(tester);

    expect(sesion.inicios, 1);
    expect(find.textContaining('Se subieron 1 cartas'), findsOneWidget);
    expect(estado.almacen, isA<AlmacenPlanilla>());
    expect(falso.hojas['Coleccion']!.length, 2); // encabezado + Pidgey
    expect(ajustes.idPlanilla, 'planilla-1');
    final releidos = Ajustes(File('${dir.path}/ajustes.json'));
    await tester.runAsync(releidos.cargar);
    expect(releidos.idPlanilla, 'planilla-1');
  });

  testWidgets('Ajustes: un segundo dispositivo se conecta pegando el enlace', (tester) async {
    final falso = SheetsFalso();
    final sheets = SheetsCliente(() async => 'token-prueba', cliente: falso.cliente);
    await tester.runAsync(() async {
      final p = await PlanillaColeccion.crear(sheets);
      await p.guardarCarta(const CartaColeccion(id: 'x', nombre: 'Budew', idioma: Idioma.ingles));
    });
    final local = AlmacenLocal(File('${dir.path}/coleccion.json'));
    final estado = estadoDePrueba(AlmacenMemoria())..almacen = local;
    await tester.pumpWidget(MaterialApp(
      home: PantallaAjustes(
        estado: estado,
        ajustes: Ajustes(File('${dir.path}/ajustes.json')),
        local: local,
        sesion: SesionFalsa(),
        crearSheets: (s) => SheetsCliente(s.token, cliente: falso.cliente),
      ),
    ));
    await tester.enterText(
        find.byType(TextField), 'https://docs.google.com/spreadsheets/d/xxxxxxxxxxxxxxxxxxxxxxxx/edit');
    await tester.tap(find.text('Conectar con esa planilla'));
    await esperarFinDeTrabajo(tester);
    // El simulador solo conoce "planilla-1": un id distinto da 404 y se informa.
    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    expect(estado.almacen, isA<AlmacenLocal>());
  });

  test('sin credenciales en la compilación no hay sesión de Google', () {
    expect(crearSesionGoogle(), isNull);
  });

  testWidgets('la colección muestra dónde está guardada', (tester) async {
    final estado = estadoDePrueba(AlmacenMemoria());
    await tester.pumpWidget(PokeCotizaApp(estado: estado));
    await tester.pumpAndSettle();
    expect(find.text('Guardada: memoria'), findsOneWidget);
  });

  test('si Google falla, se muestra la copia del dispositivo con un aviso', () async {
    final falso = SheetsFalso();
    var token = 'token-prueba';
    final sheets = SheetsCliente(() async => token, cliente: falso.cliente);
    final planilla = await PlanillaColeccion.crear(sheets);
    final cache = AlmacenLocal(File('${dir.path}/c.json'));
    final a = AlmacenPlanilla(planilla, cache);
    await a.guardarCarta(const CartaColeccion(id: 'c1', nombre: 'Lucario', idioma: Idioma.espanol));
    expect((await a.leerCartas()).cartas.single.id, 'c1');
    expect(a.aviso, isNull);

    token = 'vencido'; // el simulador responde 401
    final estado = estadoDePrueba(AlmacenMemoria())..almacen = a;
    await estado.cargar();
    expect(estado.cartas.single.nombre, 'Lucario');
    expect(estado.error, contains('copia del dispositivo'));
    expect(a.descripcion, contains('copia del dispositivo'));
  });
}

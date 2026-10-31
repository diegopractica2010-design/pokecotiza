import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

import 'package:pokecotiza_core/testing.dart';

void main() {
  late SheetsFalso falso;
  late SheetsCliente sheets;

  setUp(() {
    falso = SheetsFalso();
    sheets = SheetsCliente(() async => 'token-prueba', cliente: falso.cliente);
  });

  final lucario = CartaColeccion(
    id: 'c1',
    nombre: 'Lucario GX',
    idioma: Idioma.espanol,
    codigoSet: 'FLI',
    numero: '122/131',
    acabado: Acabado.holo,
    condicion: Condicion.lp,
    cantidad: 2,
    tcgdexId: 'sm6-122',
    tcgmatchId: 44078,
    fechaAlta: DateTime.utc(2026, 10, 30, 12),
  );
  const pikachu = CartaColeccion(
    id: 'c2',
    nombre: 'ピカチュウ',
    idioma: Idioma.japones,
    numero: '025/165',
    gradeo: Gradeo(empresa: 'PSA', nota: '10'),
    valorManualClp: 450000,
  );

  test('crear la planilla deja las 4 pestañas con encabezados y versión', () async {
    final p = await PlanillaColeccion.crear(sheets);
    expect(p.idPlanilla, 'planilla-1');
    expect(falso.hojas.keys, Esquema.pestanas);
    expect(falso.hojas['Coleccion']!.first, Esquema.columnasColeccion);
    expect(falso.hojas['Precios']!.first, Esquema.columnasPrecios);
    expect(falso.hojas['Config']![1], ['version_esquema', '2']);
  });

  test('las peticiones usan el token, RAW al escribir y valores sin formato al leer', () async {
    final p = await PlanillaColeccion.crear(sheets);
    await p.guardarCarta(lucario);
    await p.leerColeccion();
    expect(falso.pedidas.every((r) => r.headers['Authorization'] == 'Bearer token-prueba'), isTrue);
    final escrituras = falso.pedidas.where((r) => r.method == 'PUT' || r.url.path.endsWith(':append'));
    expect(escrituras.every((r) => r.url.queryParameters['valueInputOption'] == 'RAW'), isTrue);
    final lecturas = falso.pedidas.where((r) => r.method == 'GET' && r.url.path.contains('/values/'));
    expect(lecturas.every((r) => r.url.queryParameters['valueRenderOption'] == 'UNFORMATTED_VALUE'), isTrue);
  });

  test('guardar, leer, reemplazar y eliminar cartas', () async {
    final p = await PlanillaColeccion.crear(sheets);
    await p.guardarCarta(lucario);
    await p.guardarCarta(pikachu);
    var leida = await p.leerColeccion();
    expect(leida.invalidas, isEmpty);
    expect(leida.cartas.map((c) => c.id), ['c1', 'c2']);
    final l = leida.cartas.first;
    expect((l.nombre, l.idioma, l.acabado, l.condicion, l.cantidad, l.tcgmatchId, l.tcgdexId),
        ('Lucario GX', Idioma.espanol, Acabado.holo, Condicion.lp, 2, 44078, 'sm6-122'));
    expect(l.fechaAlta, DateTime.utc(2026, 10, 30, 12));
    final pk = leida.cartas.last;
    expect((pk.gradeo?.empresa, pk.gradeo?.nota, pk.valorManualClp), ('PSA', '10', 450000));

    // Reemplazar: mismo id, no se duplica.
    await p.guardarCarta(CartaColeccion(id: 'c1', nombre: 'Lucario GX', idioma: Idioma.espanol, cantidad: 3));
    leida = await p.leerColeccion();
    expect(leida.cartas.length, 2);
    expect(leida.cartas.first.cantidad, 3);

    expect(await p.eliminarCarta('c1'), isTrue);
    expect(await p.eliminarCarta('no-existe'), isFalse);
    leida = await p.leerColeccion();
    expect(leida.cartas.map((c) => c.id), ['c2']);
  });

  test('filas editadas a mano con errores se informan sin detener la lectura', () async {
    final p = await PlanillaColeccion.crear(sheets);
    await p.guardarCarta(lucario);
    falso.hojas['Coleccion']!.addAll([
      ['c3', 'Charizard', 'fr'], // idioma inválido
      [], // fila vacía: se ignora
      ['c4', 'Mew', 'en', '', '', '', 'NM', '', '', '', 'dos'], // cantidad inválida
      ['c5', 'Snorlax', 'EN'], // celdas finales omitidas y mayúsculas: válida
    ]);
    final leida = await p.leerColeccion();
    expect(leida.cartas.map((c) => c.id), ['c1', 'c5']);
    expect(leida.cartas.last.condicion, Condicion.nm);
    expect(leida.cartas.last.cantidad, 1);
    expect(leida.invalidas.map((f) => f.numeroFila), [3, 5]);
    expect(leida.invalidas.first.motivo, contains('idioma'));
  });

  test('historial de precios y resumen', () async {
    final p = await PlanillaColeccion.crear(sheets);
    final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30));
    const cots = [
      Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.publicado, moneda: Moneda.clp, valor: 30000),
      Cotizacion(fuente: 'Cardmarket', tipo: TipoPrecio.ventas, moneda: Moneda.eur, valor: 41.05),
    ];
    await p.registrarPrecios('c1', cots, cambio, fecha: DateTime.utc(2026, 10, 31));
    await p.registrarPrecios('c1', cots.take(1).toList(), cambio, fecha: DateTime.utc(2026, 10, 30));
    await p.registrarPrecios('c2', cots.take(1).toList(), cambio, fecha: DateTime.utc(2026, 10, 30));
    final h = await p.historial('c1');
    expect(h.length, 3);
    expect(h.first.fecha, DateTime.utc(2026, 10, 30));
    expect(h.last.valorClp, 45155);
    expect(h.last.cotizacion.tipo, TipoPrecio.ventas);

    await p.registrarResumen((publicadoClp: 64783, ventasClp: 45540), 2, fecha: DateTime.utc(2026, 10, 30));
    expect(falso.hojas['Resumen']!.last, ['2026-10-30T00:00:00.000Z', 64783, 45540, 2]);
  });

  test('cantidad con decimales e id repetido se informan como filas inválidas', () async {
    final p = await PlanillaColeccion.crear(sheets);
    await p.guardarCarta(lucario);
    falso.hojas['Coleccion']!.addAll([
      ['c6', 'Eevee', 'en', '', '', '', 'NM', '', '', '', 1.6],
      ['c1', 'Lucario GX', 'es'],
    ]);
    final leida = await p.leerColeccion();
    expect(leida.cartas.map((c) => c.id), ['c1']);
    expect(leida.invalidas.map((f) => f.numeroFila), [3, 4]);
    expect(leida.invalidas.first.motivo, contains('entero'));
    expect(leida.invalidas.last.motivo, contains('repetido'));
  });

  test('el historial conserva la fecha del dato según la fuente', () async {
    final p = await PlanillaColeccion.crear(sheets);
    final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30));
    final cot = Cotizacion(
        fuente: 'Cardmarket',
        tipo: TipoPrecio.ventas,
        moneda: Moneda.eur,
        valor: 10,
        fecha: DateTime.utc(2026, 10, 20));
    await p.registrarPrecios('c1', [cot], cambio, fecha: DateTime.utc(2026, 10, 30));
    final h = (await p.historial('c1')).single;
    expect(h.fecha, DateTime.utc(2026, 10, 30));
    expect(h.cotizacion.fecha, DateTime.utc(2026, 10, 20));
  });

  test('preparar estructura no sobrescribe una fila 1 con datos', () async {
    final p = await PlanillaColeccion.crear(sheets);
    falso.hojas['Resumen']![0] = ['mis datos', 123];
    await expectLater(p.prepararEstructura, throwsA(isA<FormatoInesperado>()));
    expect(falso.hojas['Resumen']![0], ['mis datos', 123]);
  });

  test('preparar estructura completa encabezados de una versión anterior', () async {
    final p = await PlanillaColeccion.crear(sheets);
    falso.hojas['Precios']![0] = Esquema.columnasPrecios.take(9).toList();
    await p.prepararEstructura();
    expect(falso.hojas['Precios']![0], Esquema.columnasPrecios);
  });

  test('tipo de cambio se guarda en Config y se recupera', () async {
    final p = await PlanillaColeccion.crear(sheets);
    expect(await p.leerTipoCambio(), isNull);
    await p.guardarTipoCambio(TipoCambio(usd: 993.22, eur: 1109.37, fecha: DateTime.utc(2026, 10, 30, 3)));
    final t = await p.leerTipoCambio();
    expect((t?.usd, t?.eur, t?.fecha), (993.22, 1109.37, DateTime.utc(2026, 10, 30, 3)));
    // La versión del esquema no se pierde al guardar otras claves.
    expect(falso.hojas['Config']!.skip(1).map((f) => f.first), contains('version_esquema'));
  });

  test('preparar estructura agrega pestañas faltantes sin borrar datos', () async {
    final p = await PlanillaColeccion.crear(sheets);
    await p.guardarCarta(lucario);
    falso.hojas.remove('Resumen');
    falso.ids.remove('Resumen');
    await p.prepararEstructura();
    expect(falso.hojas.containsKey('Resumen'), isTrue);
    expect((await p.leerColeccion()).cartas.single.id, 'c1');
  });

  test('errores de Google se traducen a mensajes claros', () async {
    final sinPermiso = SheetsCliente(() async => 'otro-token', cliente: falso.cliente);
    await PlanillaColeccion.crear(sheets);
    expect(
      () => PlanillaColeccion(sinPermiso, 'planilla-1').leerColeccion(),
      throwsA(isA<FuenteNoDisponible>()
          .having((e) => e.codigoHttp, 'codigo', 401)
          .having((e) => e.mensaje, 'mensaje', contains('sesión de Google'))),
    );
    expect(
      () => PlanillaColeccion(sheets, 'otra').leerColeccion(),
      throwsA(isA<FuenteNoDisponible>().having((e) => e.codigoHttp, 'codigo', 404)),
    );
  });

  test('id de planilla desde un enlace', () {
    expect(idPlanillaDesdeEnlace('https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz_-123/edit#gid=0'),
        '1AbCdEfGhIjKlMnOpQrStUvWxYz_-123');
    expect(idPlanillaDesdeEnlace(' 1AbCdEfGhIjKlMnOpQrStUvWxYz_-123 '), '1AbCdEfGhIjKlMnOpQrStUvWxYz_-123');
    expect(idPlanillaDesdeEnlace('https://tcgmatch.cl/producto/catalogo/1'), isNull);
    expect(enlacePlanilla('abc').toString(), 'https://docs.google.com/spreadsheets/d/abc/edit');
  });

  test('puntos de valor por fecha desde el historial y resumen ordenado', () async {
    final p = await PlanillaColeccion.crear(sheets);
    final cambio = TipoCambio(usd: 1000, eur: 1100, fecha: DateTime.utc(2026, 10, 30));
    await p.registrarPrecios(
        'c1',
        const [
          Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.publicado, moneda: Moneda.clp, valor: 30000),
          Cotizacion(fuente: 'TCGplayer', tipo: TipoPrecio.publicado, moneda: Moneda.usd, valor: 40), // 40.000
          Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.ventas, moneda: Moneda.clp, valor: 28000),
        ],
        cambio,
        fecha: DateTime.utc(2026, 10, 31));
    await p.registrarPrecios(
        'c1',
        const [
          Cotizacion(fuente: 'TCGmatch', tipo: TipoPrecio.publicado, moneda: Moneda.clp, valor: 25000),
        ],
        cambio,
        fecha: DateTime.utc(2026, 10, 30));
    final puntos = puntosDesdeHistorial(lucario, await p.historial('c1'));
    expect(puntos.map((x) => (x.fecha.day, x.publicadoClp, x.ventasClp)), [(30, 25000, null), (31, 35000, 28000)]);

    await p.registrarResumen((publicadoClp: 2, ventasClp: 1), 1, fecha: DateTime.utc(2026, 11, 2));
    await p.registrarResumen((publicadoClp: 1, ventasClp: 1), 1, fecha: DateTime.utc(2026, 11, 1));
    expect((await p.leerResumen()).map((x) => x.publicadoClp), [1, 2]);
  });
}

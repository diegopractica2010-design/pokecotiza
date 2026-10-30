// Cotiza una carta contra las fuentes reales. Uso:
//   dart run example/cotizar.dart <enlace TCGmatch> <id TCGdex> <en|es|ja> [normal|holo|reverseHolo]
// Ejemplo:
//   dart run example/cotizar.dart https://tcgmatch.cl/producto/catalogo/44078 sm6-122 es holo
import 'package:pokecotiza_core/pokecotiza_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    print('Uso: dart run example/cotizar.dart <enlace TCGmatch> <id TCGdex> <en|es|ja> [normal|holo|reverseHolo]');
    return;
  }
  final idioma = Idioma.values.firstWhere((i) => i.codigoTcgdex == args[2]);
  final acabado = args.length > 3 ? Acabado.values.byName(args[3]) : Acabado.normal;
  final http = ClienteCortes();
  try {
    final tcgmatch = TcgmatchCliente(http);
    final idCatalogo = await tcgmatch.resolverEnlace(args[0]);
    final precios = await tcgmatch.precios(idCatalogo);
    final carta = await TcgdexCliente(http).carta(idioma, args[1], acabado: acabado);
    final fallback = TipoCambio(usd: 993.22, eur: 1109.37, fecha: DateTime.utc(2026, 10, 30));
    final cambio = await MindicadorCliente(http).obtener(ultimoConocido: fallback);

    final cotizaciones = [...cotizacionesDesdeTcgmatch(precios, idioma, fecha: DateTime.now()), ...carta.cotizaciones];
    final valor = valorizar(
      CartaColeccion(id: 'ejemplo', nombre: carta.nombre, idioma: idioma, acabado: acabado),
      cotizaciones,
      cambio,
    );
    print('Carta: ${carta.nombre} (${carta.nombreSet}) · TCGmatch: ${precios.nombre} ${precios.codigo}');
    print('Tipo de cambio: USD ${cambio.usd} · EUR ${cambio.eur} · ${cambio.fecha.toIso8601String()}'
        '${identical(cambio, fallback) ? ' (último conocido: mindicador no respondió)' : ''}');
    for (final c in cotizaciones) {
      print('  $c → ${cambio.aClp(c.valor, c.moneda).round()} CLP');
    }
    print('Valor publicado: ${valor.publicadoClp} CLP · Valor ventas reales: ${valor.ventasClp} CLP');
  } finally {
    http.cerrar();
  }
}

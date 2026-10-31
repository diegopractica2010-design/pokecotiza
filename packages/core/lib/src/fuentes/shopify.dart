import 'dart:convert';

import '../errores.dart';
import '../http/cliente_cortes.dart';
import '../modelos.dart';

/// Tienda chilena que publica su catálogo con Shopify (feed público).
class TiendaShopify {
  const TiendaShopify({required this.id, required this.nombre, required this.dominio});

  /// Clave corta que se guarda en la planilla, por ejemplo "afkstore".
  final String id;
  final String nombre;
  final String dominio;

  Uri urlProducto(String handle) => Uri.https(dominio, '/products/$handle');
}

/// Tiendas soportadas. Revisadas el 2026-10-30: robots.txt permite las
/// páginas de productos y sus términos no mencionan scraping (ver
/// docs/investigacion/fase-1-fuentes.md).
const tiendasShopify = [TiendaShopify(id: 'afkstore', nombre: 'AFK Store', dominio: 'www.afkstore.cl')];

TiendaShopify? tiendaPorId(String id) => tiendasShopify.where((t) => t.id == id).firstOrNull;

/// Reconoce un enlace de producto de una tienda soportada.
({TiendaShopify tienda, String handle})? analizarEnlaceTienda(String texto) {
  final uri = Uri.tryParse(texto.trim());
  if (uri == null) return null;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final tienda = tiendasShopify.where((t) => t.dominio.replaceFirst(RegExp(r'^www\.'), '') == host).firstOrNull;
  final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  final i = s.indexOf('products');
  if (tienda == null || i < 0 || i + 1 >= s.length) return null;
  final handle = s[i + 1].replaceFirst(RegExp(r'\.(js|json)$'), '');
  return RegExp(r'^[a-z0-9][a-z0-9\-]*$').hasMatch(handle) ? (tienda: tienda, handle: handle) : null;
}

/// Una variante de un producto: idioma, condición, precio (CLP) y stock.
class VarianteTienda {
  const VarianteTienda(
      {required this.titulo, required this.precioClp, required this.disponible, this.idioma, this.condicion});

  final String titulo;
  final int precioClp;
  final bool disponible;

  /// Null si el título de la variante no se pudo interpretar.
  final Idioma? idioma;
  final Condicion? condicion;
}

class ProductoTienda {
  const ProductoTienda({required this.tienda, required this.handle, required this.titulo, required this.variantes});

  final TiendaShopify tienda;
  final String handle;
  final String titulo;
  final List<VarianteTienda> variantes;

  Uri get url => tienda.urlProducto(handle);
}

final _reVariante = RegExp(
    r'^\s*(ingles|inglés|english|espanol|español|japones|japonés|japanese)\s*(?:\(\s*(nm|lp|mp|hp|dmg)\s*\))?\s*$',
    caseSensitive: false);

/// Interpreta títulos como "Ingles", "Español (Lp)". Si no indica condición
/// se asume NM (supuesto sobre cómo publica la tienda, no confirmado).
({Idioma idioma, Condicion condicion})? interpretarVariante(String titulo) {
  final m = _reVariante.firstMatch(titulo);
  if (m == null) return null;
  final i = m.group(1)!.toLowerCase();
  final idioma = i.startsWith('ingl') || i == 'english'
      ? Idioma.ingles
      : i.startsWith('esp')
          ? Idioma.espanol
          : Idioma.japones;
  final c = m.group(2);
  return (idioma: idioma, condicion: c == null ? Condicion.nm : Condicion.desdeTexto(c)!);
}

/// Lee `/products/<handle>.js` (precios en centavos de peso).
ProductoTienda leerProductoShopify(TiendaShopify tienda, String cuerpo) {
  final Object? d;
  try {
    d = jsonDecode(cuerpo);
  } on FormatException {
    throw FormatoInesperado(tienda.nombre, 'el producto no es JSON válido');
  }
  if (d is! Map<String, dynamic> || d['variants'] is! List) {
    throw FormatoInesperado(tienda.nombre, 'el producto no tiene variantes');
  }
  return ProductoTienda(
    tienda: tienda,
    handle: '${d['handle']}',
    titulo: '${d['title']}',
    variantes: [
      for (final v in (d['variants'] as List).whereType<Map<String, dynamic>>())
        if (v['price'] is num)
          () {
            final titulo = '${v['title']}';
            final x = interpretarVariante(titulo);
            return VarianteTienda(
              titulo: titulo,
              precioClp: ((v['price'] as num) / 100).round(),
              disponible: v['available'] == true,
              idioma: x?.idioma,
              condicion: x?.condicion,
            );
          }(),
    ],
  );
}

/// Resultado del buscador de la tienda (`/search/suggest.json`).
class ResultadoTienda {
  const ResultadoTienda({required this.handle, required this.titulo, this.precioDesdeClp});
  final String handle;
  final String titulo;
  final int? precioDesdeClp;
}

List<ResultadoTienda> leerBusquedaShopify(TiendaShopify tienda, String cuerpo) {
  final Object? d;
  try {
    d = jsonDecode(cuerpo);
  } on FormatException {
    throw FormatoInesperado(tienda.nombre, 'la búsqueda no es JSON válido');
  }
  final recursos = d is Map ? d['resources'] : null;
  final resultados = recursos is Map ? recursos['results'] : null;
  final productos = resultados is Map ? resultados['products'] : null;
  if (productos is! List) return const [];
  return [
    for (final p in productos.whereType<Map<String, dynamic>>())
      ResultadoTienda(
        handle: '${p['handle']}',
        titulo: '${p['title']}',
        precioDesdeClp: num.tryParse('${p['price']}')?.round(),
      ),
  ];
}

/// Precio publicado en la tienda para la carta: la variante con el mismo
/// idioma y condición, solo si tiene stock. Si no hay, no devuelve nada (otra
/// condición u otro idioma tienen otro precio).
List<Cotizacion> cotizacionesDesdeTienda(ProductoTienda p, CartaColeccion carta, {DateTime? fecha}) {
  final v = p.variantes
      .where((v) => v.disponible && v.idioma == carta.idioma && v.condicion == carta.condicion)
      .map((v) => v.precioClp)
      .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
  if (v == null) return const [];
  return [
    Cotizacion(
      fuente: p.tienda.nombre,
      tipo: TipoPrecio.publicado,
      moneda: Moneda.clp,
      valor: v.toDouble(),
      fecha: fecha,
      url: p.url,
      detalle: '${p.tienda.id} ${carta.idioma.codigoTcgdex} ${carta.condicion.abreviatura}',
    ),
  ];
}

class TiendaShopifyCliente {
  TiendaShopifyCliente(this._http);

  final ClienteCortes _http;

  Future<ProductoTienda> producto(TiendaShopify tienda, String handle) async => leerProductoShopify(
      tienda, await _http.obtenerTexto(Uri.https(tienda.dominio, '/products/$handle.js'), fuente: tienda.nombre));

  Future<List<ResultadoTienda>> buscar(TiendaShopify tienda, String consulta) async {
    final uri = Uri.https(tienda.dominio, '/search/suggest.json',
        {'q': consulta, 'resources[type]': 'product', 'resources[limit]': '10'});
    return leerBusquedaShopify(tienda, await _http.obtenerTexto(uri, fuente: tienda.nombre));
  }
}

import 'dart:convert';

import '../errores.dart';
import '../http/cliente_cortes.dart';
import '../modelos.dart';

const _fuente = 'TCGmatch';
final _base = Uri.parse('https://tcgmatch.cl/');

/// Precios agregados de TCGmatch para un grupo (todas o un idioma).
/// Valores en CLP.
class PreciosGrupo {
  const PreciosGrupo(
      {this.bajo, this.medio, this.alto, this.mercado, this.vendedores, this.ventasCantidad, this.ventasMediana});

  final int? bajo;
  final int? medio;
  final int? alto;
  final int? mercado;
  final int? vendedores;
  final int? ventasCantidad;
  final int? ventasMediana;
}

/// Lo que se lee de la página `/producto/catalogo/{id}`.
class PreciosTcgmatch {
  const PreciosTcgmatch(
      {required this.idCatalogo, required this.nombre, this.codigo, required this.general, required this.porIdioma});

  final int idCatalogo;
  final String nombre;

  /// Número impreso, por ejemplo "1/131".
  final String? codigo;
  final PreciosGrupo general;
  final Map<Idioma, PreciosGrupo> porIdioma;

  Uri get url => _base.resolve('producto/catalogo/$idCatalogo');
}

/// Enlace de TCGmatch que pegó el usuario o que abrió en el navegador embebido.
sealed class EnlaceTcgmatch {
  const EnlaceTcgmatch();
}

/// `/producto/catalogo/{id}`: ya trae el id de la carta.
class EnlaceCatalogo extends EnlaceTcgmatch {
  const EnlaceCatalogo(this.id);
  final int id;
}

/// `/producto/{id}`: una publicación; hay que abrirla para saber su carta.
class EnlacePublicacion extends EnlaceTcgmatch {
  const EnlacePublicacion(this.id);
  final String id;
}

/// Reconoce un enlace de TCGmatch. Devuelve null si no es una página de carta
/// o de publicación.
EnlaceTcgmatch? analizarEnlaceTcgmatch(String texto) {
  final uri = Uri.tryParse(texto.trim());
  if (uri == null || !(uri.host == 'tcgmatch.cl' || uri.host == 'www.tcgmatch.cl')) return null;
  final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (s.length == 3 && s[0] == 'producto' && s[1] == 'catalogo') {
    final id = int.tryParse(s[2]);
    return id == null ? null : EnlaceCatalogo(id);
  }
  if (s.length == 2 && s[0] == 'producto' && RegExp(r'^[0-9a-f]{24}$').hasMatch(s[1])) {
    return EnlacePublicacion(s[1]);
  }
  return null;
}

/// Extrae el JSON que Next.js incrusta en `<script id="__NEXT_DATA__">`.
Map<String, dynamic> extraerNextData(String html) {
  final m = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html);
  if (m == null) throw FormatoInesperado(_fuente, 'La página no trae __NEXT_DATA__');
  final datos = jsonDecode(m.group(1)!);
  if (datos is! Map<String, dynamic>) throw FormatoInesperado(_fuente, '__NEXT_DATA__ no es un objeto');
  return datos;
}

Map<String, dynamic> _pageProps(String html) {
  final props = extraerNextData(html)['props'];
  final pp = props is Map ? props['pageProps'] : null;
  if (pp is! Map<String, dynamic>) throw FormatoInesperado(_fuente, 'Falta props.pageProps');
  return pp;
}

/// Lee los precios de una página `/producto/catalogo/{id}`.
PreciosTcgmatch leerCatalogoTcgmatch(String html) {
  final catalogo = _pageProps(html)['catalog'];
  if (catalogo is! Map<String, dynamic>) throw FormatoInesperado(_fuente, 'Falta catalog');
  final markets = catalogo['markets'];
  final tm = markets is Map ? markets['tcgmatch'] : null;
  if (tm is! Map<String, dynamic>) throw FormatoInesperado(_fuente, 'Falta markets.tcgmatch');

  final porIdioma = <Idioma, PreciosGrupo>{};
  final por = tm['byLanguage'];
  if (por is Map<String, dynamic>) {
    for (final idioma in Idioma.values) {
      final g = por[idioma.codigoTcgmatch];
      if (g is Map<String, dynamic>) porIdioma[idioma] = _grupo(g);
    }
  }
  final info = catalogo['cardInfo'];
  return PreciosTcgmatch(
    idCatalogo: catalogo['_id'] as int,
    nombre: '${catalogo['name']}',
    codigo: info is Map ? info['code'] as String? : null,
    general: _grupo(tm),
    porIdioma: porIdioma,
  );
}

PreciosGrupo _grupo(Map<String, dynamic> g) {
  final precios = g['prices'] is Map ? g['prices'] as Map : const {};
  final ventas = g['sales'] is Map ? g['sales'] as Map : const {};
  int? entero(Object? v) => v is num ? v.round() : null;
  return PreciosGrupo(
    bajo: entero(precios['low']),
    medio: entero(precios['mid']),
    alto: entero(precios['high']),
    mercado: entero(precios['market']),
    vendedores: entero(g['countSellers']),
    ventasCantidad: entero(ventas['count']),
    ventasMediana: entero(ventas['median']),
  );
}

/// De una página `/producto/{id}` (publicación), obtiene el id de su carta.
int idCatalogoDesdePublicacion(String html) {
  final producto = _pageProps(html)['product'];
  final catalogo = producto is Map ? producto['catalog'] : null;
  final id = catalogo is Map ? catalogo['_id'] : null;
  if (id is! int) throw FormatoInesperado(_fuente, 'La publicación no trae catalog._id');
  return id;
}

/// Cotizaciones de TCGmatch para un idioma. No mezcla idiomas: si no hay
/// datos para ese idioma, no devuelve nada.
List<Cotizacion> cotizacionesDesdeTcgmatch(PreciosTcgmatch p, Idioma idioma, {DateTime? fecha}) {
  final g = p.porIdioma[idioma];
  if (g == null) return const [];
  final resultado = <Cotizacion>[];
  final publicado = (g.mercado != null && g.mercado! > 0) ? g.mercado : g.medio;
  if (publicado != null && publicado > 0) {
    resultado.add(Cotizacion(
      fuente: _fuente,
      tipo: TipoPrecio.publicado,
      moneda: Moneda.clp,
      valor: publicado.toDouble(),
      fecha: fecha,
      url: p.url,
      detalle: 'tcgmatch ${idioma.codigoTcgmatch} ${publicado == g.mercado ? 'market' : 'mid'}',
    ));
  }
  if ((g.ventasCantidad ?? 0) > 0 && g.ventasMediana != null) {
    resultado.add(Cotizacion(
      fuente: _fuente,
      tipo: TipoPrecio.ventas,
      moneda: Moneda.clp,
      valor: g.ventasMediana!.toDouble(),
      fecha: fecha,
      url: p.url,
      detalle: 'tcgmatch ${idioma.codigoTcgmatch} mediana de ${g.ventasCantidad} ventas',
    ));
  }
  return resultado;
}

/// Lee páginas públicas de TCGmatch. No usa `/api/` (excluida en su
/// robots.txt). Una petición por carta, con pausa entre peticiones.
class TcgmatchCliente {
  TcgmatchCliente(this._http);

  final ClienteCortes _http;

  Future<PreciosTcgmatch> precios(int idCatalogo) async {
    final html = await _http.obtenerTexto(_base.resolve('producto/catalogo/$idCatalogo'), fuente: _fuente);
    return leerCatalogoTcgmatch(html);
  }

  /// Convierte un enlace pegado por el usuario en el id de la carta.
  Future<int> resolverEnlace(String texto) async {
    final enlace = analizarEnlaceTcgmatch(texto);
    switch (enlace) {
      case EnlaceCatalogo(:final id):
        return id;
      case EnlacePublicacion(:final id):
        final html = await _http.obtenerTexto(_base.resolve('producto/$id'), fuente: _fuente);
        return idCatalogoDesdePublicacion(html);
      case null:
        throw ArgumentError.value(texto, 'texto', 'No es un enlace de carta o publicación de TCGmatch');
    }
  }
}

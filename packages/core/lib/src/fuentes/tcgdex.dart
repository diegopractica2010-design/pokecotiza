import 'dart:convert';

import '../errores.dart';
import '../http/cliente_cortes.dart';
import '../modelos.dart';

const _fuente = 'TCGdex';

/// Resultado de una búsqueda en el catálogo de TCGdex.
class ResultadoTcgdex {
  const ResultadoTcgdex({required this.id, required this.numeroLocal, required this.nombre, this.imagen});

  final String id;
  final String numeroLocal;
  final String nombre;
  final String? imagen;

  /// TCGdex incluye cartas del juego digital TCG Pocket (ids "A1-001",
  /// "P-A-001"), que no son cartas físicas.
  bool get esTcgPocket => RegExp(r'^(A\d|P-A)').hasMatch(id) || (imagen?.contains('/tcgp/') ?? false);
}

/// Ficha de una carta en TCGdex, con sus precios.
class CartaTcgdex {
  const CartaTcgdex({
    required this.id,
    required this.nombre,
    required this.numeroLocal,
    this.nombreSet,
    this.ps,
    this.imagen,
    required this.cotizaciones,
  });

  final String id;
  final String nombre;
  final String numeroLocal;
  final String? nombreSet;
  final int? ps;
  final String? imagen;
  final List<Cotizacion> cotizaciones;
}

class TcgdexCliente {
  TcgdexCliente(this._http, {Uri? base}) : _base = base ?? Uri.parse('https://api.tcgdex.net/v2/');

  final ClienteCortes _http;
  final Uri _base;

  /// Busca cartas físicas por nombre y, opcionalmente, número local
  /// ("122" o "025"). Si con ceros a la izquierda no hay resultados, reintenta sin ellos.
  Future<List<ResultadoTcgdex>> buscar({
    required Idioma idioma,
    required String nombre,
    String? numeroLocal,
  }) async {
    final resultados = await _buscar(idioma, nombre, numeroLocal);
    if (resultados.isEmpty && numeroLocal != null && numeroLocal.startsWith('0')) {
      final sinCeros = numeroLocal.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      return _buscar(idioma, nombre, sinCeros);
    }
    return resultados;
  }

  Future<List<ResultadoTcgdex>> _buscar(Idioma idioma, String nombre, String? numeroLocal) async {
    final uri = _base.resolve('${idioma.codigoTcgdex}/cards').replace(queryParameters: {
      'name': nombre,
      if (numeroLocal != null) 'localId': numeroLocal,
    });
    final cuerpo = await _http.obtenerTexto(uri, fuente: _fuente);
    return leerBusquedaTcgdex(cuerpo).where((r) => !r.esTcgPocket).toList();
  }

  Future<CartaTcgdex> carta(Idioma idioma, String id, {Acabado acabado = Acabado.normal}) async {
    final uri = _base.resolve('${idioma.codigoTcgdex}/cards/${Uri.encodeComponent(id)}');
    final cuerpo = await _http.obtenerTexto(uri, fuente: _fuente);
    return leerCartaTcgdex(cuerpo, acabado: acabado);
  }
}

List<ResultadoTcgdex> leerBusquedaTcgdex(String cuerpo) {
  final datos = jsonDecode(cuerpo);
  if (datos is! List) throw FormatoInesperado(_fuente, 'La búsqueda no devolvió una lista');
  return [
    for (final e in datos.whereType<Map<String, dynamic>>())
      ResultadoTcgdex(
        id: e['id'] as String,
        numeroLocal: '${e['localId']}',
        nombre: e['name'] as String,
        imagen: e['image'] as String?,
      ),
  ];
}

CartaTcgdex leerCartaTcgdex(String cuerpo, {Acabado acabado = Acabado.normal}) {
  final datos = jsonDecode(cuerpo);
  if (datos is! Map<String, dynamic> || datos['id'] == null) {
    throw FormatoInesperado(_fuente, 'La carta no tiene el formato esperado');
  }
  final set = datos['set'];
  return CartaTcgdex(
    id: datos['id'] as String,
    nombre: datos['name'] as String,
    numeroLocal: '${datos['localId']}',
    nombreSet: set is Map ? set['name'] as String? : null,
    ps: datos['hp'] is int ? datos['hp'] as int : int.tryParse('${datos['hp']}'),
    imagen: datos['image'] as String?,
    cotizaciones: cotizacionesDesdeTcgdex(datos['pricing'], acabado: acabado),
  );
}

/// Convierte el bloque `pricing` de TCGdex en cotizaciones.
///
/// - Cardmarket (EUR): `trend` como precio publicado y `avg30` (promedio de
///   ventas de 30 días, según fuentes secundarias) como ventas. Los campos con
///   sufijo `-holo` se usan solo para [Acabado.reverseHolo]: con datos reales,
///   el `-holo` de una carta Full Art daba un tercio del precio normal, lo que
///   indica que corresponde a la versión reverse holo (deducido, no documentado).
/// - TCGplayer (USD): `marketPrice` de la variante según el acabado.
List<Cotizacion> cotizacionesDesdeTcgdex(Object? pricing, {Acabado acabado = Acabado.normal}) {
  if (pricing is! Map<String, dynamic>) return const [];
  final resultado = <Cotizacion>[];
  final reverse = acabado == Acabado.reverseHolo;

  final cm = pricing['cardmarket'];
  if (cm is Map<String, dynamic>) {
    final fecha = DateTime.tryParse('${cm['updated']}');
    String clave(String nombre) => reverse ? '$nombre-holo' : nombre;

    final trend = _numero(cm[clave('trend')]);
    if (trend != null && trend > 0) {
      resultado.add(Cotizacion(
        fuente: 'Cardmarket',
        tipo: TipoPrecio.publicado,
        moneda: Moneda.eur,
        valor: trend,
        fecha: fecha,
        detalle: 'cardmarket ${clave('trend')} vía TCGdex',
      ));
    }
    final avg30 = _numero(cm[clave('avg30')]);
    if (avg30 != null && avg30 > 0) {
      resultado.add(Cotizacion(
        fuente: 'Cardmarket',
        tipo: TipoPrecio.ventas,
        moneda: Moneda.eur,
        valor: avg30,
        fecha: fecha,
        detalle: 'cardmarket ${clave('avg30')} vía TCGdex',
      ));
    }
  }

  final tp = pricing['tcgplayer'];
  if (tp is Map<String, dynamic>) {
    final fecha = DateTime.tryParse('${tp['updated']}');
    final variantes = {
      for (final e in tp.entries)
        if (e.value is Map<String, dynamic>) e.key: e.value as Map<String, dynamic>,
    };
    final preferidas = switch (acabado) {
      Acabado.normal => ['normal', 'holofoil'],
      Acabado.holo => ['holofoil', 'normal'],
      Acabado.reverseHolo => ['reverseHolofoil'],
    };
    // Si no existe la variante del acabado pedido se omite TCGplayer: mezclar acabados da precios engañosos.
    final clave = preferidas.firstWhere(variantes.containsKey, orElse: () => '');
    final market = _numero(variantes[clave]?['marketPrice']);
    if (market != null && market > 0) {
      resultado.add(Cotizacion(
        fuente: 'TCGplayer',
        tipo: TipoPrecio.publicado,
        moneda: Moneda.usd,
        valor: market,
        fecha: fecha,
        detalle: 'tcgplayer $clave marketPrice vía TCGdex',
      ));
    }
  }
  return resultado;
}

double? _numero(Object? v) => v is num ? v.toDouble() : null;

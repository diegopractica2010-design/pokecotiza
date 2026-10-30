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

  /// Id de la expansión: "sv03.5-016" → "sv03.5".
  String get idSet => id.substring(0, id.lastIndexOf('-'));

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
  /// ("122" o "025").
  ///
  /// El nombre leído de la carta no siempre coincide con el de TCGdex
  /// ("Lucario-GX" en la carta, "Lucario GX" en TCGdex), así que si no hay
  /// resultados reintenta: con guiones como espacios, luego solo con la
  /// primera palabra, y en cada caso también sin ceros a la izquierda en el número.
  ///
  /// El filtro de número de TCGdex es aproximado ("1" también trae "102"), así
  /// que se dejan solo los números exactos. Si se da [totalSet] (el "131" de
  /// "1/131"), se ponen primero las expansiones con ese total oficial.
  Future<List<ResultadoTcgdex>> buscar({
    required Idioma idioma,
    required String nombre,
    String? numeroLocal,
    int? totalSet,
  }) async {
    final nombres = <String>{
      nombre.trim(),
      nombre.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      nombre.trim().split(RegExp(r'[\s-]+')).first,
    }.where((n) => n.isNotEmpty);
    final numeros = <String?>{
      numeroLocal,
      if (numeroLocal != null) numeroLocal.replaceFirst(RegExp(r'^0+(?=\d)'), ''),
    };
    for (final n in nombres) {
      for (final numero in numeros) {
        var resultados = await _buscar(idioma, n, numero);
        if (numeroLocal != null) {
          resultados = resultados.where((r) => _mismoNumero(r.numeroLocal, numeroLocal)).toList();
        }
        if (resultados.isNotEmpty) {
          return totalSet == null ? resultados : _ordenarPorTotal(idioma, resultados, totalSet);
        }
      }
    }
    return const [];
  }

  /// Máximo de expansiones distintas cuyo total se consulta por búsqueda.
  /// Cada consulta respeta la pausa del cliente (2 s por defecto), así que
  /// sin límite una búsqueda con muchas candidatas podría tardar minutos.
  static const maxExpansionesPorBusqueda = 6;

  Future<List<ResultadoTcgdex>> _ordenarPorTotal(Idioma idioma, List<ResultadoTcgdex> r, int total) async {
    final coinciden = <ResultadoTcgdex>[];
    final resto = <ResultadoTcgdex>[];
    final consultadas = <String>{};
    for (final c in r) {
      final yaConocido = _totales.containsKey('${idioma.codigoTcgdex}/${c.idSet}');
      final dentroDelLimite = consultadas.length < maxExpansionesPorBusqueda || consultadas.contains(c.idSet);
      int? oficial;
      if (yaConocido || dentroDelLimite) {
        if (!yaConocido) consultadas.add(c.idSet);
        oficial = await totalOficialSet(idioma, c.idSet);
      }
      (oficial == total ? coinciden : resto).add(c);
    }
    return [...coinciden, ...resto];
  }

  /// Totales ya obtenidos. Solo se guardan los que se leyeron bien, para
  /// reintentar una expansión si TCGdex falló la vez anterior.
  final Map<String, int> _totales = {};

  /// Cantidad oficial de cartas de una expansión (el número tras la barra).
  Future<int?> totalOficialSet(Idioma idioma, String idSet) async {
    final clave = '${idioma.codigoTcgdex}/$idSet';
    final guardado = _totales[clave];
    if (guardado != null) return guardado;
    final uri = _base.resolve('${idioma.codigoTcgdex}/sets/${Uri.encodeComponent(idSet)}');
    try {
      final datos = jsonDecode(await _http.obtenerTexto(uri, fuente: _fuente));
      final conteo = datos is Map ? datos['cardCount'] : null;
      final total = conteo is Map && conteo['official'] is int ? conteo['official'] as int : null;
      if (total != null) _totales[clave] = total;
      return total;
    } on FuenteNoDisponible {
      return null;
    }
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
      Acabado.normal => ['normal'],
      Acabado.holo => ['holofoil'],
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

bool _mismoNumero(String a, String b) {
  String sinCeros(String x) => x.replaceFirst(RegExp(r'^0+(?=\d)'), '').toLowerCase();
  return sinCeros(a) == sinCeros(b);
}

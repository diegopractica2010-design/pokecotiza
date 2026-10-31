import 'fuentes/mindicador.dart';
import 'modelos.dart';

/// Mediana de una lista de números. Null si está vacía.
double? mediana(Iterable<num> valores) {
  final v = valores.map((e) => e.toDouble()).toList()..sort();
  if (v.isEmpty) return null;
  final m = v.length ~/ 2;
  return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
}

/// Valor de una carta en CLP (por unidad).
class ValorCarta {
  const ValorCarta({this.publicadoClp, this.ventasClp, this.manual = false, this.usadas = const []});

  /// Mediana de los precios publicados, convertidos a CLP.
  final int? publicadoClp;

  /// Mediana de ventas reales en CLP.
  final int? ventasClp;

  /// True si el valor viene de `valorManualClp` (cartas gradeadas).
  final bool manual;

  /// Cotizaciones usadas en el cálculo, para mostrar de dónde sale cada valor.
  final List<Cotizacion> usadas;
}

/// Calcula el valor de una carta a partir de sus cotizaciones.
///
/// - Gradeadas: valor manual, porque no hay fuente pública gratuita (fase 1).
/// - Publicado: mediana de todas las cotizaciones "publicado", en CLP.
/// - Ventas: si hay ventas en CLP (TCGmatch, mercado chileno) se usan esas;
///   si no, la mediana de las ventas de otras fuentes convertidas a CLP.
ValorCarta valorizar(CartaColeccion carta, List<Cotizacion> cotizaciones, TipoCambio cambio) {
  if (carta.gradeo != null) {
    return ValorCarta(publicadoClp: carta.valorManualClp, ventasClp: carta.valorManualClp, manual: true);
  }
  final publicadas = cotizaciones.where((c) => c.tipo == TipoPrecio.publicado).toList();
  final ventas = cotizaciones.where((c) => c.tipo == TipoPrecio.ventas).toList();
  final ventasChile = ventas.where((c) => c.moneda == Moneda.clp).toList();
  final ventasUsadas = ventasChile.isNotEmpty ? ventasChile : ventas;

  final publicado = mediana(publicadas.map((c) => cambio.aClp(c.valor, c.moneda)));
  final vendido = mediana(ventasUsadas.map((c) => cambio.aClp(c.valor, c.moneda)));
  return ValorCarta(
    publicadoClp: publicado?.round(),
    ventasClp: vendido?.round(),
    usadas: [...publicadas, ...ventasUsadas],
  );
}

/// Valor total de la colección: suma de cada valor por la cantidad de copias.
/// Si una carta no tiene precio de ventas, en el total de ventas se usa su
/// precio publicado.
({int publicadoClp, int ventasClp}) valorColeccion(Iterable<(CartaColeccion, ValorCarta)> cartas) {
  var publicado = 0;
  var ventas = 0;
  for (final (carta, valor) in cartas) {
    publicado += (valor.publicadoClp ?? 0) * carta.cantidad;
    ventas += (valor.ventasClp ?? valor.publicadoClp ?? 0) * carta.cantidad;
  }
  return (publicadoClp: publicado, ventasClp: ventas);
}

/// Valor de una carta (o de la colección) en una fecha, para los gráficos.
class PuntoValor {
  const PuntoValor({required this.fecha, this.publicadoClp, this.ventasClp});

  final DateTime fecha;
  final int? publicadoClp;
  final int? ventasClp;

  Map<String, Object?> aJson() => {'fecha': fecha.toUtc().toIso8601String(), 'p': publicadoClp, 'v': ventasClp};

  static PuntoValor desdeJson(Map<String, dynamic> j) =>
      PuntoValor(fecha: DateTime.parse(j['fecha'] as String), publicadoClp: j['p'] as int?, ventasClp: j['v'] as int?);
}

/// Convierte el historial de precios de una carta (filas de la pestaña
/// Precios, ya en CLP) en un punto por fecha de registro, ordenados.
List<PuntoValor> puntosDesdeHistorial(
    CartaColeccion carta, List<({DateTime fecha, Cotizacion cotizacion, int valorClp})> historial) {
  final porFecha = <DateTime, List<Cotizacion>>{};
  for (final h in historial) {
    porFecha.putIfAbsent(h.fecha, () => []).add(Cotizacion(
          fuente: h.cotizacion.fuente,
          tipo: h.cotizacion.tipo,
          moneda: Moneda.clp, // ya convertido al registrarlo
          valor: h.valorClp.toDouble(),
        ));
  }
  // Los valores ya están en pesos: el tipo de cambio no se usa.
  final sinConversion = TipoCambio(usd: 0, eur: 0, fecha: DateTime.utc(2000));
  final fechas = porFecha.keys.toList()..sort();
  return [
    for (final f in fechas)
      () {
        final v = valorizar(carta, porFecha[f]!, sinConversion);
        return PuntoValor(fecha: f, publicadoClp: v.publicadoClp, ventasClp: v.ventasClp);
      }(),
  ];
}

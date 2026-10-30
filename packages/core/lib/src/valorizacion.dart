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

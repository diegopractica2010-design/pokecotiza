import 'errores.dart';
import 'fuentes/mindicador.dart';
import 'fuentes/shopify.dart';
import 'fuentes/tcgdex.dart';
import 'fuentes/tcgmatch.dart';
import 'modelos.dart';
import 'valorizacion.dart';

/// Resultado de cotizar una carta: lo que dijo cada fuente, el valor
/// calculado y qué fuentes fallaron (para mostrarlo sin ocultar el resto).
class ResultadoCotizacion {
  const ResultadoCotizacion(
      {required this.cotizaciones, required this.valor, required this.fallas, required this.fecha});

  final List<Cotizacion> cotizaciones;
  final ValorCarta valor;

  /// Fuente → motivo, para las fuentes que no respondieron.
  final Map<String, String> fallas;
  final DateTime fecha;
}

/// Cotiza cartas de la colección consultando TCGdex y TCGmatch. Lo usan la
/// app (al agregar o actualizar una carta) y la tarea diaria.
class Cotizador {
  Cotizador({required this.tcgdex, required this.tcgmatch, required this.mindicador, this.tiendas});

  final TcgdexCliente tcgdex;
  final TcgmatchCliente tcgmatch;
  final MindicadorCliente mindicador;

  /// Tiendas chilenas (Shopify). Null = no se consultan.
  final TiendaShopifyCliente? tiendas;

  /// Tipo de cambio del día; si mindicador.cl falla, usa [ultimoConocido].
  Future<TipoCambio> tipoCambio({TipoCambio? ultimoConocido}) => mindicador.obtener(ultimoConocido: ultimoConocido);

  /// Cotiza una carta. Una fuente que falla no detiene a las demás: queda en
  /// `fallas`. Las cartas gradeadas no se consultan (valor manual).
  Future<ResultadoCotizacion> cotizar(CartaColeccion carta, TipoCambio cambio, {DateTime? ahora}) async {
    final fecha = ahora ?? DateTime.now();
    final cotizaciones = <Cotizacion>[];
    final fallas = <String, String>{};
    if (carta.gradeo == null) {
      if (carta.tcgdexId != null) {
        try {
          final c = await tcgdex.carta(carta.idioma, carta.tcgdexId!, acabado: carta.acabado);
          cotizaciones.addAll(c.cotizaciones);
        } on FuenteNoDisponible catch (e) {
          fallas['TCGdex'] = e.mensaje;
        } on FormatoInesperado catch (e) {
          fallas['TCGdex'] = e.mensaje;
        } on FormatException catch (e) {
          fallas['TCGdex'] = 'respuesta ilegible: ${e.message}';
        }
      }
      if (carta.tcgmatchId != null) {
        try {
          final p = await tcgmatch.precios(carta.tcgmatchId!);
          cotizaciones.addAll(cotizacionesDesdeTcgmatch(p, carta.idioma, fecha: fecha));
        } on FuenteNoDisponible catch (e) {
          fallas['TCGmatch'] = e.mensaje;
        } on FormatoInesperado catch (e) {
          fallas['TCGmatch'] = e.mensaje;
        } on FormatException catch (e) {
          fallas['TCGmatch'] = 'respuesta ilegible: ${e.message}';
        }
      }
      final clienteTiendas = tiendas;
      if (clienteTiendas != null) {
        for (final e in carta.enlacesTiendas.entries) {
          final tienda = tiendaPorId(e.key);
          if (tienda == null) continue;
          try {
            final p = await clienteTiendas.producto(tienda, e.value);
            cotizaciones.addAll(cotizacionesDesdeTienda(p, carta, fecha: fecha));
          } on FuenteNoDisponible catch (x) {
            fallas[tienda.nombre] = x.mensaje;
          } on FormatoInesperado catch (x) {
            fallas[tienda.nombre] = x.mensaje;
          }
        }
      }
    }
    return ResultadoCotizacion(
      cotizaciones: cotizaciones,
      valor: valorizar(carta, cotizaciones, cambio),
      fallas: fallas,
      fecha: fecha,
    );
  }
}

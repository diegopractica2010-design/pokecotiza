import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'almacen.dart';

/// Estado de la app: la colección, sus últimas cotizaciones y el total.
/// Las pantallas lo escuchan y se redibujan cuando cambia.
class EstadoApp extends ChangeNotifier {
  EstadoApp({required this.almacen, required this.cotizador, required this.tcgdex, required this.tcgmatch});

  final Almacen almacen;
  final Cotizador cotizador;
  final TcgdexCliente tcgdex;
  final TcgmatchCliente tcgmatch;

  List<CartaColeccion> cartas = [];
  List<FilaInvalida> invalidas = [];
  Map<String, CotizacionGuardada> cotizaciones = {};
  TipoCambio? tipoCambio;
  bool cargando = false;

  /// Avance de "Actualizar precios": (hechas, total), o null si no corre.
  (int, int)? progreso;
  String? error;

  ({int publicadoClp, int ventasClp}) get total => valorColeccion([
        for (final c in cartas) (c, cotizaciones[c.id]?.valor ?? const ValorCarta()),
      ]);

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final r = await almacen.leerCartas();
      cartas = r.cartas;
      invalidas = r.invalidas;
      cotizaciones = await almacen.leerCotizaciones();
      tipoCambio = await almacen.leerTipoCambio();
    } on Object catch (e) {
      error = 'No se pudo leer la colección: $e';
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Id nuevo para una carta: tiempo + azar, sin depender de otro paquete.
  static String nuevoId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  Future<TipoCambio> _cambio() async {
    final t = await cotizador.tipoCambio(ultimoConocido: tipoCambio);
    if (!identical(t, tipoCambio)) {
      tipoCambio = t;
      await almacen.guardarTipoCambio(t);
    }
    return t;
  }

  /// Guarda la carta y la cotiza. Devuelve la cotización (o null si falló
  /// el tipo de cambio y no había uno guardado).
  Future<CotizacionGuardada?> guardarYCotizar(CartaColeccion carta) async {
    await almacen.guardarCarta(carta);
    final i = cartas.indexWhere((c) => c.id == carta.id);
    if (i >= 0) {
      cartas[i] = carta;
    } else {
      cartas.add(carta);
    }
    notifyListeners();
    return cotizarUna(carta);
  }

  Future<CotizacionGuardada?> cotizarUna(CartaColeccion carta) async {
    try {
      final r = await cotizador.cotizar(carta, await _cambio());
      final g = CotizacionGuardada(fecha: r.fecha, valor: r.valor, cotizaciones: r.cotizaciones, fallas: r.fallas);
      await almacen.guardarCotizacion(carta.id, g);
      cotizaciones[carta.id] = g;
      notifyListeners();
      return g;
    } on FuenteNoDisponible catch (e) {
      error = 'No se pudo cotizar: ${e.mensaje}';
      notifyListeners();
      return null;
    }
  }

  /// Cotiza todas las cartas, una a la vez (con pausa entre sitios).
  Future<void> actualizarPrecios() async {
    if (progreso != null) return;
    progreso = (0, cartas.length);
    error = null;
    notifyListeners();
    for (var i = 0; i < cartas.length; i++) {
      await cotizarUna(cartas[i]);
      progreso = (i + 1, cartas.length);
      notifyListeners();
    }
    progreso = null;
    notifyListeners();
  }

  Future<void> eliminar(String id) async {
    await almacen.eliminarCarta(id);
    cartas.removeWhere((c) => c.id == id);
    cotizaciones.remove(id);
    notifyListeners();
  }
}

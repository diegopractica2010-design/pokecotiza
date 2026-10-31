import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'almacen.dart';

/// Estado de la app: la colección, sus últimas cotizaciones y el total.
/// Las pantallas lo escuchan y se redibujan cuando cambia.
class EstadoApp extends ChangeNotifier {
  EstadoApp({required this.almacen, required this.cotizador, required this.tcgdex, required this.tcgmatch});

  /// Dónde está la colección (dispositivo o Google Sheets). Cambia desde Ajustes.
  Almacen almacen;
  final Cotizador cotizador;
  final TcgdexCliente tcgdex;
  final TcgmatchCliente tcgmatch;

  List<CartaColeccion> cartas = [];
  List<FilaInvalida> invalidas = [];
  Map<String, CotizacionGuardada> cotizaciones = {};
  TipoCambio? tipoCambio;
  bool cargando = false;

  /// Cambia cuando hay historial nuevo, para que los gráficos se vuelvan a leer.
  int versionHistorial = 0;

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
      final a = almacen;
      if (a is AlmacenPlanilla && a.aviso != null) error = a.aviso;
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
      // Las gradeadas usan su valor manual en pesos: no necesitan tipo de
      // cambio, así que se guardan aunque mindicador.cl no responda.
      final cambio =
          carta.gradeo != null ? (tipoCambio ?? TipoCambio(usd: 0, eur: 0, fecha: DateTime.now())) : await _cambio();
      final r = await cotizador.cotizar(carta, cambio);
      final g = CotizacionGuardada(fecha: r.fecha, valor: r.valor, cotizaciones: r.cotizaciones, fallas: r.fallas);
      await almacen.guardarCotizacion(carta.id, g);
      cotizaciones[carta.id] = g;
      versionHistorial++;
      notifyListeners();
      return g;
    } on FuenteNoDisponible catch (e) {
      error = 'No se pudo cotizar ${carta.nombre} (${e.fuente}): ${e.mensaje}';
      notifyListeners();
      return null;
    } on FormatoInesperado catch (e) {
      error = 'No se pudo cotizar ${carta.nombre} (${e.fuente}): ${e.mensaje}';
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
    try {
      final lista = [...cartas];
      var cotizadas = 0;
      for (var i = 0; i < lista.length; i++) {
        if (await cotizarUna(lista[i]) != null) cotizadas++;
        progreso = (i + 1, lista.length);
        notifyListeners();
      }
      // El total del día alimenta el gráfico de la colección.
      if (cotizadas > 0) {
        await almacen.registrarResumen(total, lista.length, DateTime.now());
        versionHistorial++;
      }
    } on Object catch (e) {
      error = 'La actualización se detuvo: $e';
    } finally {
      // Siempre se libera, para que el botón no quede bloqueado.
      progreso = null;
      notifyListeners();
    }
  }

  /// Agrega o reemplaza (por id) las cartas importadas. No las cotiza: eso se
  /// hace con "Actualizar precios". Si una carta falla al guardarse, sigue con
  /// las demás y la informa; como los ids importados son estables, reintentar
  /// el mismo archivo no duplica las ya guardadas.
  Future<({int guardadas, Map<String, String> fallidas})> importar(List<CartaColeccion> nuevas) async {
    if (cargando) throw StateError('Espera a que termine de cargar la colección.');
    var guardadas = 0;
    final fallidas = <String, String>{};
    for (final c in nuevas) {
      try {
        await almacen.guardarCarta(c);
      } on Object catch (e) {
        fallidas[c.nombre] = '$e';
        continue;
      }
      guardadas++;
      final i = cartas.indexWhere((x) => x.id == c.id);
      if (i >= 0) {
        if (!mismaCarta(cartas[i], c)) {
          // Ahora es otra carta: su precio guardado ya no corresponde.
          cotizaciones.remove(c.id);
          await almacen.eliminarCotizacion(c.id);
        }
        cartas[i] = c;
      } else {
        cartas.add(c);
      }
    }
    notifyListeners();
    return (guardadas: guardadas, fallidas: fallidas);
  }

  /// True si dos versiones de una carta tienen el mismo precio de mercado
  /// (cambiar solo la cantidad o la foto no cambia su precio).
  static bool mismaCarta(CartaColeccion a, CartaColeccion b) =>
      a.nombre == b.nombre &&
      a.idioma == b.idioma &&
      a.numero == b.numero &&
      a.acabado == b.acabado &&
      a.condicion == b.condicion &&
      a.tcgdexId == b.tcgdexId &&
      a.tcgmatchId == b.tcgmatchId &&
      a.gradeo?.toString() == b.gradeo?.toString() &&
      a.valorManualClp == b.valorManualClp;

  /// Cambia dónde se guarda la colección y la vuelve a leer.
  Future<void> cambiarAlmacen(Almacen nuevo) async {
    almacen = nuevo;
    await cargar();
  }

  Future<void> eliminar(String id) async {
    await almacen.eliminarCarta(id);
    cartas.removeWhere((c) => c.id == id);
    cotizaciones.remove(id);
    notifyListeners();
  }
}

import '../errores.dart';
import '../fuentes/mindicador.dart';
import '../modelos.dart';
import 'esquema.dart';
import 'sheets_cliente.dart';

/// La colección guardada en una planilla de Google Sheets. La usan la app
/// (teléfono y PC) y la tarea diaria, así que todos ven los mismos datos.
class PlanillaColeccion {
  PlanillaColeccion(this._sheets, this.idPlanilla);

  final SheetsCliente _sheets;
  final String idPlanilla;

  /// Crea una planilla nueva con todas las pestañas y encabezados.
  static Future<PlanillaColeccion> crear(SheetsCliente sheets, {String titulo = 'PokeCotiza'}) async {
    final id = await sheets.crear(titulo, Esquema.pestanas);
    final planilla = PlanillaColeccion(sheets, id);
    await planilla.prepararEstructura();
    return planilla;
  }

  /// Agrega las pestañas que falten y escribe los encabezados. Se puede
  /// llamar siempre al abrir la planilla: no toca los datos existentes.
  Future<void> prepararEstructura() async {
    final existentes = await _sheets.pestanas(idPlanilla);
    await _sheets.agregarPestanas(idPlanilla, [
      for (final p in Esquema.pestanas)
        if (!existentes.containsKey(p)) p,
    ]);
    for (final p in Esquema.pestanas) {
      await _sheets.escribir(idPlanilla, '$p!A1', [Esquema.encabezados(p)]);
    }
    await _escribirConfig({'version_esquema': '${Esquema.versionEsquema}'});
  }

  /// Lee la colección. Las filas que no se pueden interpretar se devuelven
  /// en `invalidas` con el motivo, para mostrárselas al usuario.
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerColeccion() async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.coleccion));
    final cartas = <CartaColeccion>[];
    final invalidas = <FilaInvalida>[];
    for (var i = 1; i < filas.length; i++) {
      final fila = filas[i];
      if (fila.every((v) => v == null || '$v'.trim().isEmpty)) continue;
      try {
        cartas.add(filaACarta(fila));
      } on FormatoInesperado catch (e) {
        invalidas.add(FilaInvalida(i + 1, e.mensaje));
      }
    }
    return (cartas: cartas, invalidas: invalidas);
  }

  /// Agrega la carta o, si ya existe una con el mismo id, la reemplaza.
  Future<void> guardarCarta(CartaColeccion carta) async {
    final fila = await _filaDe(carta.id);
    if (fila == null) {
      await _sheets.agregar(idPlanilla, Esquema.rango(Esquema.coleccion), [cartaAFila(carta)]);
    } else {
      await _sheets.escribir(idPlanilla, '${Esquema.coleccion}!A$fila', [cartaAFila(carta)]);
    }
  }

  /// Elimina la carta de la colección. Su historial de precios se conserva.
  /// Devuelve false si no existía.
  Future<bool> eliminarCarta(String id) async {
    final fila = await _filaDe(id);
    if (fila == null) return false;
    final pestanas = await _sheets.pestanas(idPlanilla);
    await _sheets.eliminarFila(idPlanilla, pestanas[Esquema.coleccion]!, fila - 1);
    return true;
  }

  /// Agrega al historial las cotizaciones de una carta, con su valor en CLP.
  Future<void> registrarPrecios(String idCarta, List<Cotizacion> cotizaciones, TipoCambio cambio,
      {DateTime? fecha}) async {
    final cuando = fecha ?? DateTime.now();
    await _sheets.agregar(idPlanilla, Esquema.rango(Esquema.precios), [
      for (final c in cotizaciones) cotizacionAFila(idCarta, c, cambio.aClp(c.valor, c.moneda).round(), cuando),
    ]);
  }

  /// Historial de precios de una carta, del más antiguo al más reciente.
  Future<List<({DateTime fecha, Cotizacion cotizacion, int valorClp})>> historial(String idCarta) async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.precios));
    final resultado = <({DateTime fecha, Cotizacion cotizacion, int valorClp})>[];
    for (final f in filas.skip(1)) {
      String t(int i) => i < f.length && f[i] != null ? '${f[i]}' : '';
      if (t(1) != idCarta) continue;
      final fecha = DateTime.tryParse(t(0));
      final tipo = TipoPrecio.values.where((x) => x.name == t(3)).firstOrNull;
      final moneda = Moneda.values.where((x) => x.name == t(4).toLowerCase()).firstOrNull;
      final valor = f.length > 5 && f[5] is num ? (f[5] as num).toDouble() : double.tryParse(t(5));
      final clp = f.length > 6 && f[6] is num ? (f[6] as num).round() : int.tryParse(t(6));
      if (fecha == null || tipo == null || moneda == null || valor == null || clp == null) continue;
      resultado.add((
        fecha: fecha,
        valorClp: clp,
        cotizacion: Cotizacion(
          fuente: t(2),
          tipo: tipo,
          moneda: moneda,
          valor: valor,
          fecha: fecha,
          detalle: t(7).isEmpty ? null : t(7),
          url: t(8).isEmpty ? null : Uri.tryParse(t(8)),
        ),
      ));
    }
    resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
    return resultado;
  }

  /// Agrega una fila al resumen diario con el valor total de la colección.
  Future<void> registrarResumen(({int publicadoClp, int ventasClp}) total, int cartas, {DateTime? fecha}) async {
    await _sheets.agregar(idPlanilla, Esquema.rango(Esquema.resumen), [
      [(fecha ?? DateTime.now()).toUtc().toIso8601String(), total.publicadoClp, total.ventasClp, cartas],
    ]);
  }

  /// Guarda el último tipo de cambio conocido, para usarlo si mindicador.cl falla.
  Future<void> guardarTipoCambio(TipoCambio t) => _escribirConfig({
        'tipo_cambio_usd': '${t.usd}',
        'tipo_cambio_eur': '${t.eur}',
        'tipo_cambio_fecha': t.fecha.toUtc().toIso8601String(),
      });

  Future<TipoCambio?> leerTipoCambio() async {
    final c = await _leerConfig();
    final usd = double.tryParse(c['tipo_cambio_usd'] ?? '');
    final eur = double.tryParse(c['tipo_cambio_eur'] ?? '');
    final fecha = DateTime.tryParse(c['tipo_cambio_fecha'] ?? '');
    if (usd == null || eur == null || fecha == null) return null;
    return TipoCambio(usd: usd, eur: eur, fecha: fecha);
  }

  /// Número de fila (desde 1) de la carta con ese id, o null.
  Future<int?> _filaDe(String id) async {
    final ids = await _sheets.leer(idPlanilla, '${Esquema.coleccion}!A:A');
    for (var i = 1; i < ids.length; i++) {
      if (ids[i].isNotEmpty && '${ids[i].first}'.trim() == id) return i + 1;
    }
    return null;
  }

  Future<Map<String, String>> _leerConfig() async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.config));
    return {
      for (final f in filas.skip(1))
        if (f.isNotEmpty && '${f.first}'.isNotEmpty) '${f.first}': f.length > 1 ? '${f[1]}' : '',
    };
  }

  Future<void> _escribirConfig(Map<String, String> cambios) async {
    final actual = await _leerConfig()
      ..addAll(cambios);
    final claves = actual.keys.toList()..sort();
    await _sheets.escribir(idPlanilla, '${Esquema.config}!A2', [
      for (final k in claves) [k, actual[k]],
    ]);
  }
}

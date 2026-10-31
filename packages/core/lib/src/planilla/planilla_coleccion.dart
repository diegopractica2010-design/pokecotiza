import '../errores.dart';
import '../fuentes/mindicador.dart';
import '../modelos.dart';
import '../valorizacion.dart';
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
      final esperados = Esquema.encabezados(p);
      final actual = (await _sheets.leer(idPlanilla, '$p!A1:${Esquema.ultimaColumna(p)}1')).firstOrNull ?? const [];
      final textos = [for (final v in actual) '${v ?? ''}'.trim()];
      if (textos.every((t) => t.isEmpty)) {
        await _sheets.escribir(idPlanilla, '$p!A1', [esperados]);
        continue;
      }
      // Encabezados de una versión anterior (prefijo): se completan las columnas nuevas.
      var esPrefijo = textos.length <= esperados.length;
      for (var i = 0; esPrefijo && i < textos.length; i++) {
        esPrefijo = textos[i] == esperados[i];
      }
      if (!esPrefijo) {
        throw FormatoInesperado('planilla',
            'la fila 1 de la pestaña "$p" no tiene los encabezados esperados; no se modificó para no perder datos');
      }
      if (textos.length < esperados.length) await _sheets.escribir(idPlanilla, '$p!A1', [esperados]);
    }
    await _escribirConfig({'version_esquema': '${Esquema.versionEsquema}'});
  }

  /// Lee la colección. Las filas que no se pueden interpretar se devuelven
  /// en `invalidas` con el motivo, para mostrárselas al usuario.
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerColeccion() async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.coleccion));
    final cartas = <CartaColeccion>[];
    final invalidas = <FilaInvalida>[];
    final vistos = <String, int>{};
    for (var i = 1; i < filas.length; i++) {
      final fila = filas[i];
      if (fila.every((v) => v == null || '$v'.trim().isEmpty)) continue;
      try {
        final carta = filaACarta(fila);
        // Dos dispositivos que agregan la misma carta a la vez pueden duplicarla
        // (Google Sheets no permite evitarlo): se usa la primera y se avisa de la repetida.
        final previa = vistos[carta.id];
        if (previa != null) {
          invalidas.add(FilaInvalida(i + 1, 'id "${carta.id}" repetido (ya está en la fila $previa)'));
          continue;
        }
        vistos[carta.id] = i + 1;
        cartas.add(carta);
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
      final fechaFuente = DateTime.tryParse(t(9));
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
          fecha: fechaFuente ?? fecha,
          detalle: t(7).isEmpty ? null : t(7),
          url: t(8).isEmpty ? null : Uri.tryParse(t(8)),
        ),
      ));
    }
    resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
    return resultado;
  }

  /// Últimas cotizaciones registradas de cada carta (las de su fecha de
  /// registro más reciente). Sirve para no contar como 0 una carta cuyas
  /// fuentes fallaron hoy.
  Future<Map<String, List<Cotizacion>>> ultimasCotizaciones() async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.precios));
    final ultimaFecha = <String, String>{};
    final porCarta = <String, List<List<Object?>>>{};
    for (final f in filas.skip(1)) {
      if (f.length < 7) continue;
      final id = '${f[1]}';
      final fecha = '${f[0]}';
      final previa = ultimaFecha[id];
      if (previa == null || fecha.compareTo(previa) > 0) {
        ultimaFecha[id] = fecha;
        porCarta[id] = [f];
      } else if (fecha == previa) {
        porCarta[id]!.add(f);
      }
    }
    final r = <String, List<Cotizacion>>{};
    for (final e in porCarta.entries) {
      r[e.key] = [
        for (final f in e.value)
          if (TipoPrecio.values.where((t) => t.name == '${f[3]}').firstOrNull case final tipo?)
            if (Moneda.values.where((m) => m.name == '${f[4]}'.toLowerCase()).firstOrNull case final moneda?)
              if (f[5] is num)
                Cotizacion(
                    fuente: '${f[2]}',
                    tipo: tipo,
                    moneda: moneda,
                    valor: (f[5] as num).toDouble(),
                    detalle: 'precio anterior'),
      ];
    }
    return r;
  }

  /// Resumen diario del valor de la colección (pestaña Resumen), ordenado.
  Future<List<PuntoValor>> leerResumen() async {
    final filas = await _sheets.leer(idPlanilla, Esquema.rango(Esquema.resumen));
    final r = <PuntoValor>[];
    for (final f in filas.skip(1)) {
      final fecha = f.isEmpty ? null : DateTime.tryParse('${f[0]}');
      if (fecha == null) continue;
      int? n(int i) =>
          i < f.length && f[i] is num ? (f[i] as num).round() : int.tryParse(i < f.length ? '${f[i]}' : '');
      r.add(PuntoValor(fecha: fecha, publicadoClp: n(1), ventasClp: n(2)));
    }
    r.sort((a, b) => a.fecha.compareTo(b.fecha));
    return r;
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

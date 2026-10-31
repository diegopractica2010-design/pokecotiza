import 'dart:convert';
import 'dart:io';

import 'package:pokecotiza_core/pokecotiza_core.dart';

/// Última cotización guardada de una carta, para mostrar la colección sin
/// volver a consultar las fuentes cada vez que se abre la app.
class CotizacionGuardada {
  const CotizacionGuardada(
      {required this.fecha, required this.valor, required this.cotizaciones, this.fallas = const {}});

  final DateTime fecha;
  final ValorCarta valor;
  final List<Cotizacion> cotizaciones;
  final Map<String, String> fallas;

  Map<String, Object?> aJson() => {
        'fecha': fecha.toUtc().toIso8601String(),
        'publicadoClp': valor.publicadoClp,
        'ventasClp': valor.ventasClp,
        'manual': valor.manual,
        'fallas': fallas,
        'cotizaciones': [
          for (final c in cotizaciones)
            {
              'fuente': c.fuente,
              'tipo': c.tipo.name,
              'moneda': c.moneda.name,
              'valor': c.valor,
              'fecha': c.fecha?.toUtc().toIso8601String(),
              'url': c.url?.toString(),
              'detalle': c.detalle,
            },
        ],
      };

  static CotizacionGuardada desdeJson(Map<String, dynamic> j) => CotizacionGuardada(
        fecha: DateTime.parse(j['fecha'] as String),
        valor: ValorCarta(
          publicadoClp: j['publicadoClp'] as int?,
          ventasClp: j['ventasClp'] as int?,
          manual: j['manual'] as bool? ?? false,
        ),
        fallas: Map<String, String>.from(j['fallas'] as Map? ?? const {}),
        cotizaciones: [
          for (final c in (j['cotizaciones'] as List? ?? const []).cast<Map<String, dynamic>>())
            Cotizacion(
              fuente: c['fuente'] as String,
              tipo: TipoPrecio.values.byName(c['tipo'] as String),
              moneda: Moneda.values.byName(c['moneda'] as String),
              valor: (c['valor'] as num).toDouble(),
              fecha: c['fecha'] == null ? null : DateTime.tryParse(c['fecha'] as String),
              url: c['url'] == null ? null : Uri.tryParse(c['url'] as String),
              detalle: c['detalle'] as String?,
            ),
        ],
      );
}

/// Dónde se guarda la colección. Hoy: un archivo en el dispositivo. Con
/// Google configurado (fase 4b): la planilla de Google Sheets.
abstract class Almacen {
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerCartas();
  Future<void> guardarCarta(CartaColeccion carta);
  Future<void> eliminarCarta(String id);
  Future<Map<String, CotizacionGuardada>> leerCotizaciones();
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c);

  /// Olvida la última cotización de una carta (por ejemplo, si cambió de carta).
  Future<void> eliminarCotizacion(String idCarta);

  /// Evolución del valor de una carta, de la más antigua a la más reciente.
  Future<List<PuntoValor>> historialCarta(CartaColeccion carta);

  /// Evolución del valor total de la colección.
  Future<List<PuntoValor>> historialColeccion();

  /// Registra el valor total de la colección (después de actualizar precios).
  Future<void> registrarResumen(({int publicadoClp, int ventasClp}) total, int cartas, DateTime fecha);
  Future<TipoCambio?> leerTipoCambio();
  Future<void> guardarTipoCambio(TipoCambio t);

  /// Texto para mostrar dónde están los datos.
  String get descripcion;
}

/// Colección en un archivo JSON del dispositivo. Usa el mismo formato de
/// fila que la planilla, así el paso a Google Sheets no cambia los datos.
class AlmacenLocal implements Almacen {
  AlmacenLocal(this.archivo);

  final File archivo;

  /// Cola de operaciones: cada lectura-modificación-escritura espera a la
  /// anterior, para que dos guardados simultáneos no se pisen.
  Future<void> _cola = Future.value();

  Future<T> _enCola<T>(Future<T> Function() operacion) {
    final resultado = _cola.then((_) => operacion());
    _cola = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }

  @override
  String get descripcion => 'En este dispositivo';

  Future<Map<String, dynamic>> _leer() async {
    if (!await archivo.exists()) return {};
    try {
      final datos = jsonDecode(await archivo.readAsString());
      return datos is Map<String, dynamic> ? datos : {};
    } on FormatException {
      // Archivo dañado: se conserva una copia y se empieza de cero.
      await archivo.copy('${archivo.path}.danado');
      return {};
    }
  }

  Future<void> _escribir(Map<String, dynamic> datos) async {
    await archivo.parent.create(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(const JsonEncoder.withIndent(' ').convert(datos));
    try {
      await temporal.rename(archivo.path); // reemplazo de una vez: el archivo no queda a medias
    } on FileSystemException {
      // Por si el sistema no permite reemplazar al renombrar: se borra y se reintenta.
      if (await archivo.exists()) await archivo.delete();
      await temporal.rename(archivo.path);
    }
  }

  @override
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerCartas() async {
    final filas = ((await _leer())['cartas'] as List? ?? const []).cast<List>();
    final cartas = <CartaColeccion>[];
    final invalidas = <FilaInvalida>[];
    for (var i = 0; i < filas.length; i++) {
      try {
        cartas.add(filaACarta(filas[i]));
      } on FormatoInesperado catch (e) {
        invalidas.add(FilaInvalida(i + 1, e.mensaje));
      }
    }
    return (cartas: cartas, invalidas: invalidas);
  }

  @override
  Future<void> guardarCarta(CartaColeccion carta) => _enCola(() async {
        final datos = await _leer();
        final filas = ((datos['cartas'] as List?) ?? []).cast<List>().toList();
        final fila = cartaAFila(carta);
        final i = filas.indexWhere((f) => f.isNotEmpty && f.first == carta.id);
        if (i >= 0) {
          filas[i] = fila;
        } else {
          filas.add(fila);
        }
        datos['cartas'] = filas;
        await _escribir(datos);
      });

  @override
  Future<void> eliminarCarta(String id) => _enCola(() async {
        final datos = await _leer();
        datos['cartas'] =
            ((datos['cartas'] as List?) ?? []).cast<List>().where((f) => f.isEmpty || f.first != id).toList();
        (datos['cotizaciones'] as Map?)?.remove(id);
        await _escribir(datos);
      });

  @override
  Future<Map<String, CotizacionGuardada>> leerCotizaciones() async {
    final m = (await _leer())['cotizaciones'] as Map<String, dynamic>? ?? {};
    final r = <String, CotizacionGuardada>{};
    for (final e in m.entries) {
      try {
        r[e.key] = CotizacionGuardada.desdeJson(e.value as Map<String, dynamic>);
      } on Object {
        // Una cotización ilegible se descarta: se recalcula al actualizar.
      }
    }
    return r;
  }

  /// Máximo de puntos guardados por carta y para la colección (~1 año diario).
  static const maxPuntos = 400;

  @override
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c) => _enCola(() async {
        final datos = await _leer();
        final m = Map<String, dynamic>.from(datos['cotizaciones'] as Map? ?? {});
        m[idCarta] = c.aJson();
        datos['cotizaciones'] = m;
        if (c.valor.publicadoClp != null || c.valor.ventasClp != null) {
          final h = Map<String, dynamic>.from(datos['historial'] as Map? ?? {});
          final puntos = [...(h[idCarta] as List? ?? const [])];
          puntos.add(
              PuntoValor(fecha: c.fecha, publicadoClp: c.valor.publicadoClp, ventasClp: c.valor.ventasClp).aJson());
          h[idCarta] = puntos.length > maxPuntos ? puntos.sublist(puntos.length - maxPuntos) : puntos;
          datos['historial'] = h;
        }
        await _escribir(datos);
      });

  List<PuntoValor> _puntos(Object? lista) {
    final r = <PuntoValor>[];
    for (final p in (lista as List? ?? const [])) {
      try {
        r.add(PuntoValor.desdeJson(p as Map<String, dynamic>));
      } on Object {
        // punto ilegible: se omite
      }
    }
    return r..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  @override
  Future<List<PuntoValor>> historialCarta(CartaColeccion carta) async =>
      _puntos(((await _leer())['historial'] as Map?)?[carta.id]);

  @override
  Future<List<PuntoValor>> historialColeccion() async => _puntos((await _leer())['resumen']);

  @override
  Future<void> registrarResumen(({int publicadoClp, int ventasClp}) total, int cartas, DateTime fecha) =>
      _enCola(() async {
        final datos = await _leer();
        final puntos = [
          ...(datos['resumen'] as List? ?? const []),
          PuntoValor(fecha: fecha, publicadoClp: total.publicadoClp, ventasClp: total.ventasClp).aJson(),
        ];
        datos['resumen'] = puntos.length > maxPuntos ? puntos.sublist(puntos.length - maxPuntos) : puntos;
        await _escribir(datos);
      });

  /// Reemplaza todas las cartas (copia local de la planilla).
  Future<void> reemplazarCartas(List<CartaColeccion> cartas) => _enCola(() async {
        final datos = await _leer();
        datos['cartas'] = [for (final c in cartas) cartaAFila(c)];
        await _escribir(datos);
      });

  @override
  Future<void> eliminarCotizacion(String idCarta) => _enCola(() async {
        final datos = await _leer();
        (datos['cotizaciones'] as Map?)?.remove(idCarta);
        await _escribir(datos);
      });

  @override
  Future<TipoCambio?> leerTipoCambio() async {
    final t = (await _leer())['tipoCambio'];
    return t is Map<String, dynamic> ? TipoCambio.desdeJson(t) : null;
  }

  @override
  Future<void> guardarTipoCambio(TipoCambio t) => _enCola(() async {
        final datos = await _leer();
        datos['tipoCambio'] = t.aJson();
        await _escribir(datos);
      });
}

/// Colección en Google Sheets. Las últimas cotizaciones se guardan además en
/// el dispositivo ([cache]) para abrir la app sin consultar la planilla de
/// precios; cada cotización nueva se agrega al historial de la planilla.
class AlmacenPlanilla implements Almacen {
  AlmacenPlanilla(this.planilla, this.cache);

  final PlanillaColeccion planilla;
  final AlmacenLocal cache;
  TipoCambio? _cambio;

  /// Si la última lectura no pudo usar la planilla, explica por qué (se
  /// mostró la copia del dispositivo). Null si se leyó bien.
  String? aviso;

  @override
  String get descripcion => aviso == null ? 'Google Sheets' : 'copia del dispositivo (Google Sheets no disponible)';

  /// Lee la planilla y actualiza la copia del dispositivo. Si Google no
  /// responde (sin internet, sesión vencida), devuelve esa copia.
  @override
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerCartas() async {
    try {
      final r = await planilla.leerColeccion();
      await cache.reemplazarCartas(r.cartas);
      aviso = null;
      return r;
    } on Exception catch (e) {
      aviso = 'No se pudo leer tu planilla de Google ($e). Se muestra la copia del dispositivo.';
      return cache.leerCartas();
    }
  }

  @override
  Future<void> guardarCarta(CartaColeccion carta) async {
    await planilla.guardarCarta(carta);
    await cache.guardarCarta(carta);
  }

  @override
  Future<void> eliminarCarta(String id) async {
    await planilla.eliminarCarta(id);
    await cache.eliminarCarta(id); // borra su cotización guardada en el dispositivo
  }

  @override
  Future<Map<String, CotizacionGuardada>> leerCotizaciones() => cache.leerCotizaciones();

  @override
  Future<void> eliminarCotizacion(String idCarta) => cache.eliminarCotizacion(idCarta);

  /// Del historial de la planilla; si Google no responde, de la copia local.
  @override
  Future<List<PuntoValor>> historialCarta(CartaColeccion carta) async {
    try {
      return puntosDesdeHistorial(carta, await planilla.historial(carta.id));
    } on Exception {
      return cache.historialCarta(carta);
    }
  }

  @override
  Future<List<PuntoValor>> historialColeccion() async {
    try {
      return await planilla.leerResumen();
    } on Exception {
      return cache.historialColeccion();
    }
  }

  @override
  Future<void> registrarResumen(({int publicadoClp, int ventasClp}) total, int cartas, DateTime fecha) async {
    await cache.registrarResumen(total, cartas, fecha);
    await planilla.registrarResumen(total, cartas, fecha: fecha);
  }

  @override
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c) async {
    await cache.guardarCotizacion(idCarta, c);
    final cambio = _cambio ?? await leerTipoCambio();
    if (cambio != null && c.cotizaciones.isNotEmpty) {
      await planilla.registrarPrecios(idCarta, c.cotizaciones, cambio, fecha: c.fecha);
    }
  }

  @override
  Future<TipoCambio?> leerTipoCambio() async {
    if (_cambio != null) return _cambio;
    try {
      _cambio = await planilla.leerTipoCambio();
    } on Exception {
      _cambio = null; // sin planilla: se usa la copia del dispositivo
    }
    return _cambio ??= await cache.leerTipoCambio();
  }

  @override
  Future<void> guardarTipoCambio(TipoCambio t) async {
    _cambio = t;
    await planilla.guardarTipoCambio(t);
    await cache.guardarTipoCambio(t);
  }
}

/// Sube a la planilla las cartas del dispositivo que aún no estén en ella.
/// Devuelve cuántas subió.
Future<int> migrarALaPlanilla(Almacen origen, PlanillaColeccion destino) async {
  final enPlanilla = (await destino.leerColeccion()).cartas.map((c) => c.id).toSet();
  var subidas = 0;
  for (final c in (await origen.leerCartas()).cartas) {
    if (enPlanilla.contains(c.id)) continue;
    await destino.guardarCarta(c);
    subidas++;
  }
  return subidas;
}

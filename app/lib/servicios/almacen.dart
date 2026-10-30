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

  @override
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c) => _enCola(() async {
        final datos = await _leer();
        final m = Map<String, dynamic>.from(datos['cotizaciones'] as Map? ?? {});
        m[idCarta] = c.aJson();
        datos['cotizaciones'] = m;
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

  @override
  String get descripcion => 'Google Sheets';

  @override
  Future<({List<CartaColeccion> cartas, List<FilaInvalida> invalidas})> leerCartas() => planilla.leerColeccion();

  @override
  Future<void> guardarCarta(CartaColeccion carta) => planilla.guardarCarta(carta);

  @override
  Future<void> eliminarCarta(String id) async {
    await planilla.eliminarCarta(id);
    await cache.eliminarCarta(id); // borra su cotización guardada en el dispositivo
  }

  @override
  Future<Map<String, CotizacionGuardada>> leerCotizaciones() => cache.leerCotizaciones();

  @override
  Future<void> guardarCotizacion(String idCarta, CotizacionGuardada c) async {
    await cache.guardarCotizacion(idCarta, c);
    final cambio = _cambio ?? await leerTipoCambio();
    if (cambio != null && c.cotizaciones.isNotEmpty) {
      await planilla.registrarPrecios(idCarta, c.cotizaciones, cambio, fecha: c.fecha);
    }
  }

  @override
  Future<TipoCambio?> leerTipoCambio() async =>
      _cambio ??= await planilla.leerTipoCambio() ?? await cache.leerTipoCambio();

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

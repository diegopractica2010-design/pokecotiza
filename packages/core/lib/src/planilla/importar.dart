import '../errores.dart';
import '../modelos.dart';
import '../valorizacion.dart';
import 'esquema.dart';

/// Columnas que se aceptan al importar, con sus nombres alternativos
/// (minúsculas, sin tildes, espacios como "_").
const _alias = {
  'id': ['id'],
  'nombre': ['nombre', 'carta', 'name'],
  'idioma': ['idioma', 'lengua', 'language'],
  'codigo_set': ['codigo_set', 'set', 'expansion', 'codigo'],
  'numero': ['numero', 'n', 'nro', 'number'],
  'regulacion': ['regulacion', 'letra'],
  'condicion': ['condicion', 'estado', 'condition'],
  'acabado': ['acabado', 'holo', 'finish'],
  'gradeadora': ['gradeadora', 'empresa'],
  'nota_gradeo': ['nota_gradeo', 'nota', 'grado'],
  'cantidad': ['cantidad', 'copias', 'qty'],
  'tcgdex_id': ['tcgdex_id', 'tcgdex'],
  'tcgmatch_id': ['tcgmatch_id', 'tcgmatch'],
  'valor_manual_clp': ['valor_manual_clp', 'valor_manual'],
  'foto_url': ['foto_url', 'foto'],
  'fecha_alta': ['fecha_alta'],
};

String _normalizar(Object? v) {
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n', 'ü': 'u'};
  var t = '${v ?? ''}'.trim().toLowerCase();
  tildes.forEach((k, r) => t = t.replaceAll(k, r));
  return t.replaceAll(RegExp(r'[\s\-.°º]+'), '_').replaceAll(RegExp(r'_+$'), '');
}

String _idioma(String v) => switch (_normalizar(v)) {
      'ingles' || 'english' || 'en' || 'eng' => 'en',
      'espanol' || 'es' || 'spa' => 'es',
      'japones' || 'japanese' || 'ja' || 'jp' || 'jpn' => 'ja',
      _ => v,
    };

String _acabado(String v) => switch (_normalizar(v)) {
      'reverse' || 'reverse_holo' || 'reverseholo' || 'rh' => 'reverseHolo',
      'holo' || 'si' || 'full_art' => 'holo',
      'normal' || 'no' || '' => 'normal',
      _ => v,
    };

/// Convierte las filas de una planilla (Excel u otra) en cartas. La primera
/// fila debe tener los encabezados; se reconocen por nombre, en cualquier
/// orden. Si una fila no trae `id`, se le asigna uno con [nuevoId].
({List<CartaColeccion> cartas, List<FilaInvalida> invalidas}) importarFilas(List<List<Object?>> filas,
    {required String Function() nuevoId}) {
  if (filas.isEmpty) {
    return (cartas: const [], invalidas: const [FilaInvalida(1, 'el archivo está vacío')]);
  }
  final encabezados = [for (final v in filas.first) _normalizar(v)];
  final posicion = <String, int>{};
  _alias.forEach((columna, nombres) {
    final i = encabezados.indexWhere(nombres.contains);
    if (i >= 0) posicion[columna] = i;
  });
  if (!posicion.containsKey('nombre') || !posicion.containsKey('idioma')) {
    return (
      cartas: const [],
      invalidas: const [FilaInvalida(1, 'faltan las columnas "Nombre" e "Idioma" en la primera fila')],
    );
  }

  final cartas = <CartaColeccion>[];
  final invalidas = <FilaInvalida>[];
  for (var i = 1; i < filas.length; i++) {
    final f = filas[i];
    Object? celda(String columna) {
      final p = posicion[columna];
      return p == null || p >= f.length ? null : f[p];
    }

    if (f.every((v) => '${v ?? ''}'.trim().isEmpty)) continue;
    // Se arma una fila con el orden de la pestaña Coleccion y se reutiliza su lector.
    final fila = <Object?>[
      for (final columna in Esquema.columnasColeccion)
        switch (columna) {
          'id' => '${celda('id') ?? ''}'.trim().isEmpty ? nuevoId() : celda('id'),
          'idioma' => _idioma('${celda('idioma') ?? ''}'),
          'acabado' => _acabado('${celda('acabado') ?? ''}'),
          _ => celda(columna),
        },
    ];
    try {
      cartas.add(filaACarta(fila));
    } on FormatoInesperado catch (e) {
      invalidas.add(FilaInvalida(i + 1, e.mensaje));
    }
  }
  return (cartas: cartas, invalidas: invalidas);
}

/// Filas para exportar la colección: las columnas de la pestaña Coleccion
/// más el último valor publicado y de ventas reales. Se puede volver a importar.
List<List<Object?>> exportarFilas(List<CartaColeccion> cartas, Map<String, ValorCarta> valores) => [
      [...Esquema.columnasColeccion, 'valor_publicado_clp', 'valor_ventas_clp'],
      for (final c in cartas) [...cartaAFila(c), valores[c.id]?.publicadoClp ?? '', valores[c.id]?.ventasClp ?? ''],
    ];

import 'dart:convert';

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

/// Id estable para una fila importada sin `id`: se calcula con los datos que
/// identifican la carta (FNV-1a de 64 bits). Así, reimportar el mismo archivo
/// reemplaza en vez de duplicar, aunque una importación anterior quedara a medias.
String idDeImportacion(List<Object?> fila) {
  final clave = [
    for (final c in ['nombre', 'idioma', 'codigo_set', 'numero', 'acabado', 'condicion', 'gradeadora', 'nota_gradeo'])
      _normalizar(fila[Esquema.columnasColeccion.indexOf(c)]),
  ].join('|');
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final primo = BigInt.parse('100000001b3', radix: 16);
  final mascara = (BigInt.one << 64) - BigInt.one;
  for (final b in utf8.encode(clave)) {
    h = ((h ^ BigInt.from(b)) * primo) & mascara;
  }
  return 'imp-${h.toRadixString(36)}';
}

/// Convierte las filas de una planilla (Excel u otra) en cartas. La primera
/// fila debe tener los encabezados; se reconocen por nombre, en cualquier
/// orden. Si una fila no trae `id`, se calcula con [idDeImportacion]. Si dos
/// filas terminan con el mismo id, la segunda se informa como repetida.
({List<CartaColeccion> cartas, List<FilaInvalida> invalidas}) importarFilas(List<List<Object?>> filas) {
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
  final vistos = <String, int>{};
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
          'id' => celda('id'),
          'idioma' => _idioma('${celda('idioma') ?? ''}'),
          'acabado' => _acabado('${celda('acabado') ?? ''}'),
          _ => celda(columna),
        },
    ];
    if ('${fila[0] ?? ''}'.trim().isEmpty) fila[0] = idDeImportacion(fila);
    try {
      final carta = filaACarta(fila);
      final previa = vistos[carta.id];
      if (previa != null) {
        invalidas.add(
            FilaInvalida(i + 1, 'repite la carta de la fila $previa (para varias copias usa la columna Cantidad)'));
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

/// Filas para exportar la colección: las columnas de la pestaña Coleccion
/// más el último valor publicado y de ventas reales. Se puede volver a importar.
List<List<Object?>> exportarFilas(List<CartaColeccion> cartas, Map<String, ValorCarta> valores) => [
      [...Esquema.columnasColeccion, 'valor_publicado_clp', 'valor_ventas_clp'],
      for (final c in cartas) [...cartaAFila(c), valores[c.id]?.publicadoClp ?? '', valores[c.id]?.ventasClp ?? ''],
    ];

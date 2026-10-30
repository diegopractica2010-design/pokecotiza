// Google Sheets simulado para pruebas (de este paquete y de la app). No se
// usa en producción.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Google Sheets simulado en memoria. Imita solo las operaciones que usa
/// PokeCotiza, con el comportamiento documentado de la API v4: omite celdas
/// vacías al final de cada fila y filas vacías al final.
class SheetsFalso {
  final Map<String, List<List<Object?>>> hojas = {};
  final Map<String, int> ids = {};
  final List<http.Request> pedidas = [];
  String? idPlanilla;
  int _siguienteId = 0;

  late final MockClient cliente = MockClient((req) async {
    pedidas.add(req);
    if (req.headers['Authorization'] != 'Bearer token-prueba') return http.Response('{}', 401);
    final s = req.url.pathSegments; // [v4, spreadsheets, ...]
    if (req.method == 'POST' && s.length == 2) return _crear(jsonDecode(req.body));
    final id = s[2].split(':').first;
    if (id != idPlanilla) return http.Response('{}', 404);
    if (s.length == 3 && req.method == 'GET') return _json(_metadatos());
    if (s.length == 3 && s[2].endsWith(':batchUpdate')) return _batch(jsonDecode(req.body));
    final rango = s[4];
    if (rango.endsWith(':append')) return _agregar(rango.substring(0, rango.length - 7), jsonDecode(req.body));
    if (req.method == 'PUT') return _escribir(rango, jsonDecode(req.body));
    if (req.method == 'GET') return _leer(rango);
    return http.Response('{}', 400);
  });

  http.Response _json(Object o) => http.Response.bytes(utf8.encode(jsonEncode(o)), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  void _nuevaHoja(String nombre) {
    hojas[nombre] = [];
    ids[nombre] = _siguienteId++;
  }

  http.Response _crear(Map<String, dynamic> cuerpo) {
    idPlanilla = 'planilla-1';
    for (final h in cuerpo['sheets'] as List) {
      _nuevaHoja(h['properties']['title'] as String);
    }
    return _json({'spreadsheetId': idPlanilla});
  }

  Map<String, Object> _metadatos() => {
        'sheets': [
          for (final e in ids.entries)
            {
              'properties': {'title': e.key, 'sheetId': e.value},
            },
        ],
      };

  http.Response _batch(Map<String, dynamic> cuerpo) {
    for (final r in cuerpo['requests'] as List) {
      if (r['addSheet'] != null) _nuevaHoja(r['addSheet']['properties']['title'] as String);
      if (r['deleteDimension'] != null) {
        final rango = r['deleteDimension']['range'];
        final hoja = ids.entries.firstWhere((e) => e.value == rango['sheetId']).key;
        hojas[hoja]!.removeRange(rango['startIndex'] as int, rango['endIndex'] as int);
      }
    }
    return _json({});
  }

  (String, int, int?) _partes(String rango) {
    // "Hoja!A:P", "Hoja!A:A", "Hoja!A5"
    final m = RegExp(r'^(\w+)!([A-Z])(\d*)(?::([A-Z])\d*)?$').firstMatch(rango)!;
    final fila = m.group(3)!.isEmpty ? 0 : int.parse(m.group(3)!) - 1;
    final ultimaCol = m.group(4) == null ? null : m.group(4)!.codeUnitAt(0) - 65;
    return (m.group(1)!, fila, ultimaCol);
  }

  http.Response _leer(String rango) {
    final (hoja, fila, ultimaCol) = _partes(rango);
    // "Hoja!A1:J1" lee solo esa fila; "Hoja!A:P" lee todas.
    final soloUna = RegExp(r'\d+:[A-Z]\d+$').hasMatch(rango);
    final origen = soloUna ? hojas[hoja]!.skip(fila).take(1) : hojas[hoja]!;
    final filas = [
      for (final f in origen) _recortar(ultimaCol == null ? f : f.take(ultimaCol + 1).toList()),
    ];
    while (filas.isNotEmpty && filas.last.isEmpty) {
      filas.removeLast();
    }
    return _json({'range': rango, 'values': filas});
  }

  List<Object?> _recortar(List<Object?> f) {
    final r = [...f];
    while (r.isNotEmpty && (r.last == null || r.last == '')) {
      r.removeLast();
    }
    return r;
  }

  http.Response _escribir(String rango, Map<String, dynamic> cuerpo) {
    final (hoja, fila, _) = _partes(rango);
    final valores = (cuerpo['values'] as List).cast<List>();
    final h = hojas[hoja]!;
    for (var i = 0; i < valores.length; i++) {
      while (h.length <= fila + i) {
        h.add([]);
      }
      h[fila + i] = List<Object?>.from(valores[i]);
    }
    return _json({});
  }

  http.Response _agregar(String rango, Map<String, dynamic> cuerpo) {
    final (hoja, _, _) = _partes(rango);
    hojas[hoja]!.addAll([for (final f in cuerpo['values'] as List) List<Object?>.from(f as List)]);
    return _json({});
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errores.dart';

const _fuente = 'Google Sheets';

/// Saca el id de la planilla de un enlace como
/// `https://docs.google.com/spreadsheets/d/ID/edit`. También acepta el id solo.
/// Devuelve null si no lo reconoce.
String? idPlanillaDesdeEnlace(String texto) {
  final t = texto.trim();
  final m = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]{20,})').firstMatch(t);
  if (m != null) return m.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(t) ? t : null;
}

/// Enlace para abrir la planilla en el navegador.
Uri enlacePlanilla(String idPlanilla) => Uri.parse('https://docs.google.com/spreadsheets/d/$idPlanilla/edit');

/// Entrega un token de acceso OAuth vigente. En la app lo da el inicio de
/// sesión con Google; en la tarea diaria, una cuenta de servicio.
typedef ProveedorToken = Future<String> Function();

/// Cliente mínimo de la API de Google Sheets v4 (REST). Solo implementa lo
/// que usa PokeCotiza. Operaciones verificadas contra el documento de
/// descubrimiento oficial (revisión 20261026).
class SheetsCliente {
  SheetsCliente(this._token, {http.Client? cliente, Uri? base})
      : _http = cliente ?? http.Client(),
        _base = base ?? Uri.parse('https://sheets.googleapis.com/v4/');

  final ProveedorToken _token;
  final http.Client _http;
  final Uri _base;

  /// Crea una planilla con las pestañas indicadas y devuelve su id.
  Future<String> crear(String titulo, List<String> pestanas) async {
    final r = await _pedir('POST', 'spreadsheets', cuerpo: {
      'properties': {'title': titulo},
      'sheets': [
        for (final p in pestanas)
          {
            'properties': {'title': p},
          },
      ],
    });
    return r['spreadsheetId'] as String;
  }

  /// Nombre → id numérico de cada pestaña.
  Future<Map<String, int>> pestanas(String idPlanilla) async {
    final r = await _pedir('GET', 'spreadsheets/$idPlanilla', consulta: {'fields': 'sheets.properties'});
    final hojas = (r['sheets'] as List?) ?? const [];
    return {
      for (final h in hojas.whereType<Map<String, dynamic>>())
        (h['properties'] as Map)['title'] as String: (h['properties'] as Map)['sheetId'] as int,
    };
  }

  Future<void> agregarPestanas(String idPlanilla, List<String> nombres) async {
    if (nombres.isEmpty) return;
    await _pedir('POST', 'spreadsheets/$idPlanilla:batchUpdate', cuerpo: {
      'requests': [
        for (final n in nombres)
          {
            'addSheet': {
              'properties': {'title': n},
            },
          },
      ],
    });
  }

  /// Lee un rango. Devuelve valores sin formato (números como números).
  /// Google omite las celdas vacías al final de cada fila.
  Future<List<List<Object?>>> leer(String idPlanilla, String rango) async {
    final r = await _pedir('GET', 'spreadsheets/$idPlanilla/values/${Uri.encodeComponent(rango)}', consulta: {
      'valueRenderOption': 'UNFORMATTED_VALUE',
      'dateTimeRenderOption': 'FORMATTED_STRING',
    });
    final valores = (r['values'] as List?) ?? const [];
    return [for (final fila in valores) List<Object?>.from(fila as List)];
  }

  /// Sobrescribe un rango. RAW: lo que se escribe queda tal cual, sin que
  /// Google lo interprete como fecha o fórmula.
  Future<void> escribir(String idPlanilla, String rango, List<List<Object?>> filas) async {
    await _pedir('PUT', 'spreadsheets/$idPlanilla/values/${Uri.encodeComponent(rango)}',
        consulta: {'valueInputOption': 'RAW'}, cuerpo: {'values': filas});
  }

  /// Agrega filas al final de la tabla del rango.
  Future<void> agregar(String idPlanilla, String rango, List<List<Object?>> filas) async {
    if (filas.isEmpty) return;
    await _pedir('POST', 'spreadsheets/$idPlanilla/values/${Uri.encodeComponent(rango)}:append',
        consulta: {'valueInputOption': 'RAW', 'insertDataOption': 'INSERT_ROWS'}, cuerpo: {'values': filas});
  }

  /// Borra una fila (índice desde 0) de una pestaña.
  Future<void> eliminarFila(String idPlanilla, int idPestana, int indiceFila) async {
    await _pedir('POST', 'spreadsheets/$idPlanilla:batchUpdate', cuerpo: {
      'requests': [
        {
          'deleteDimension': {
            'range': {'sheetId': idPestana, 'dimension': 'ROWS', 'startIndex': indiceFila, 'endIndex': indiceFila + 1},
          },
        },
      ],
    });
  }

  Future<Map<String, dynamic>> _pedir(String metodo, String ruta,
      {Map<String, String>? consulta, Map<String, Object?>? cuerpo}) async {
    final uri = Uri.parse('${_base.toString()}$ruta').replace(queryParameters: consulta);
    final req = http.Request(metodo, uri)
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..headers['Content-Type'] = 'application/json; charset=utf-8';
    if (cuerpo != null) req.body = jsonEncode(cuerpo);
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _http.send(req));
    } on Exception catch (e) {
      throw FuenteNoDisponible(_fuente, 'Error de red: $e');
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final pista = switch (r.statusCode) {
        401 => 'la sesión de Google expiró o no es válida',
        403 => 'sin permiso para esta planilla',
        404 => 'la planilla no existe o no es accesible',
        429 => 'demasiadas peticiones; reintentar más tarde',
        _ => 'respuesta inesperada',
      };
      throw FuenteNoDisponible(_fuente, '$metodo $ruta: $pista', codigoHttp: r.statusCode);
    }
    if (r.body.isEmpty) return const {};
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos is Map<String, dynamic> ? datos : const {};
  }

  void cerrar() => _http.close();
}

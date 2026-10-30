import 'package:http/http.dart' as http;

import '../errores.dart';

/// Cliente HTTP "cortés": espera una pausa mínima entre peticiones al mismo
/// dominio, se identifica y corta las peticiones lentas. Lo usan todas las
/// fuentes para no sobrecargar los sitios.
class ClienteCortes {
  ClienteCortes({
    http.Client? cliente,
    this.pausaMinima = const Duration(seconds: 2),
    this.tiempoMaximo = const Duration(seconds: 20),
    this.userAgent = 'PokeCotiza/0.1 (uso personal)',
  }) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  final Duration pausaMinima;
  final Duration tiempoMaximo;
  final String userAgent;
  final Map<String, DateTime> _ultimaPeticion = {};

  Future<String> obtenerTexto(Uri uri, {required String fuente}) async {
    await _esperarTurno(uri.host);
    final http.Response respuesta;
    try {
      respuesta = await _cliente.get(uri, headers: {'User-Agent': userAgent}).timeout(tiempoMaximo);
    } on Exception catch (e) {
      throw FuenteNoDisponible(fuente, 'Error de red al pedir $uri: $e');
    }
    if (respuesta.statusCode != 200) {
      throw FuenteNoDisponible(fuente, 'Respuesta inesperada de $uri', codigoHttp: respuesta.statusCode);
    }
    return respuesta.body;
  }

  Future<void> _esperarTurno(String host) async {
    final ultima = _ultimaPeticion[host];
    if (ultima != null) {
      final espera = pausaMinima - DateTime.now().difference(ultima);
      if (espera > Duration.zero) await Future<void>.delayed(espera);
    }
    _ultimaPeticion[host] = DateTime.now();
  }

  void cerrar() => _cliente.close();
}

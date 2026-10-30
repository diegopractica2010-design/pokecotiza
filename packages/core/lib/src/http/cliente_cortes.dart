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

  /// Reserva el próximo turno del dominio antes de esperar, para que varias
  /// peticiones simultáneas queden separadas por [pausaMinima] y no salgan juntas.
  Future<void> _esperarTurno(String host) async {
    final ahora = DateTime.now();
    final anterior = _ultimaPeticion[host];
    final siguiente = anterior == null || ahora.isAfter(anterior.add(pausaMinima)) ? ahora : anterior.add(pausaMinima);
    _ultimaPeticion[host] = siguiente;
    final espera = siguiente.difference(ahora);
    if (espera > Duration.zero) await Future<void>.delayed(espera);
  }

  void cerrar() => _cliente.close();
}

/// Una fuente de precios no respondió o respondió con un error.
class FuenteNoDisponible implements Exception {
  FuenteNoDisponible(this.fuente, this.mensaje, {this.codigoHttp});

  final String fuente;
  final String mensaje;
  final int? codigoHttp;

  @override
  String toString() => 'FuenteNoDisponible($fuente${codigoHttp != null ? ', HTTP $codigoHttp' : ''}): $mensaje';
}

/// La fuente respondió, pero con una estructura distinta a la esperada.
/// Suele indicar que el sitio cambió y hay que actualizar el adaptador.
class FormatoInesperado implements Exception {
  FormatoInesperado(this.fuente, this.mensaje);

  final String fuente;
  final String mensaje;

  @override
  String toString() => 'FormatoInesperado($fuente): $mensaje';
}

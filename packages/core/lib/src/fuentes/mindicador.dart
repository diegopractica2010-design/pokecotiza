import 'dart:convert';

import '../errores.dart';
import '../http/cliente_cortes.dart';
import '../modelos.dart';

const _fuente = 'mindicador.cl';

/// Tipo de cambio a pesos chilenos.
class TipoCambio {
  const TipoCambio({required this.usd, required this.eur, required this.fecha});

  /// Pesos por 1 dólar.
  final double usd;

  /// Pesos por 1 euro.
  final double eur;
  final DateTime fecha;

  double aClp(double valor, Moneda moneda) => switch (moneda) {
        Moneda.clp => valor,
        Moneda.usd => valor * usd,
        Moneda.eur => valor * eur,
      };

  Map<String, Object> aJson() => {'usd': usd, 'eur': eur, 'fecha': fecha.toIso8601String()};

  static TipoCambio desdeJson(Map<String, dynamic> j) => TipoCambio(
        usd: (j['usd'] as num).toDouble(),
        eur: (j['eur'] as num).toDouble(),
        fecha: DateTime.parse(j['fecha'] as String),
      );
}

TipoCambio leerMindicador(String cuerpo) {
  final Object? datos;
  try {
    datos = jsonDecode(cuerpo);
  } on FormatException {
    throw FormatoInesperado(_fuente, 'la respuesta no es JSON válido');
  }
  double? valor(String clave) {
    final d = datos is Map ? datos[clave] : null;
    final v = d is Map ? d['valor'] : null;
    return v is num ? v.toDouble() : null;
  }

  final usd = valor('dolar');
  final eur = valor('euro');
  final fecha = DateTime.tryParse('${(datos is Map && datos['dolar'] is Map) ? datos['dolar']['fecha'] : ''}');
  if (usd == null || eur == null || fecha == null) {
    throw FormatoInesperado(_fuente, 'Faltan dolar/euro en la respuesta');
  }
  return TipoCambio(usd: usd, eur: eur, fecha: fecha);
}

class MindicadorCliente {
  MindicadorCliente(this._http, {Uri? uri}) : _uri = uri ?? Uri.parse('https://mindicador.cl/api');

  final ClienteCortes _http;
  final Uri _uri;

  /// Obtiene el tipo de cambio del día. Si el servicio falla y se entrega
  /// [ultimoConocido], lo devuelve en vez de fallar (mindicador.cl a veces no responde).
  Future<TipoCambio> obtener({TipoCambio? ultimoConocido}) async {
    try {
      return leerMindicador(await _http.obtenerTexto(_uri, fuente: _fuente));
    } on FuenteNoDisponible {
      if (ultimoConocido != null) return ultimoConocido;
      rethrow;
    } on FormatoInesperado {
      if (ultimoConocido != null) return ultimoConocido;
      rethrow;
    }
  }
}

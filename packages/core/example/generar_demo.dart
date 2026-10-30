// Genera los datos de la página de demostración ejecutando el flujo completo
// contra las fuentes reales: texto de la carta → lector → búsqueda en TCGdex
// → precios TCGdex + TCGmatch → valorización. Escribe JSON en la salida estándar.
//   dart run example/generar_demo.dart > demo.json
import 'dart:convert';

import 'package:pokecotiza_core/pokecotiza_core.dart';

class Ejemplo {
  const Ejemplo(this.texto, this.idioma, this.acabado, this.tcgmatchId);
  final String texto;
  final Idioma idioma;
  final Acabado acabado;
  final int tcgmatchId;
}

// Textos escritos a mano imitando lo impreso en cada carta (no son OCR real).
const ejemplos = [
  Ejemplo('ETAPA 1\nLucario-GX PS 210\nGolpe Aural 30+\n5ban Graphics 122/131', Idioma.espanol, Acabado.holo, 44078),
  Ejemplo('BASIC\nExeggcute HP 40\nMultiply\nYuka Morii 1/131', Idioma.ingles, Acabado.normal, 43946),
  Ejemplo('BASIC\nPidgey HP 50\nCall for Family\nG MEW EN 016/165', Idioma.ingles, Acabado.normal, 31533),
  Ejemplo('BASIC\nBudew HP 30\nItchy Pollen 10\nH PRE EN 004/131', Idioma.ingles, Acabado.normal, 29054),
];

Future<void> main() async {
  final http = ClienteCortes();
  final tcgdex = TcgdexCliente(http);
  final tcgmatch = TcgmatchCliente(http);
  final respaldo = TipoCambio(usd: 993.22, eur: 1109.37, fecha: DateTime.utc(2026, 10, 30, 3));
  final cambio = await MindicadorCliente(http).obtener(ultimoConocido: respaldo);
  final salida = <String, Object?>{
    'generado': DateTime.now().toUtc().toIso8601String(),
    'tipoCambio': {...cambio.aJson(), 'respaldo': identical(cambio, respaldo)},
    'cartas': <Object?>[],
  };
  try {
    for (final e in ejemplos) {
      final leidos = leerTextoCarta(e.texto);
      final candidatas = await tcgdex.buscar(
          idioma: e.idioma, nombre: leidos.nombre!, numeroLocal: leidos.numeroLocal, totalSet: leidos.totalSet);
      final elegida = candidatas.first;
      final carta = await tcgdex.carta(e.idioma, elegida.id, acabado: e.acabado);
      final precios = await tcgmatch.precios(e.tcgmatchId);
      final cots = [
        ...cotizacionesDesdeTcgmatch(precios, e.idioma, fecha: DateTime.now().toUtc()),
        ...carta.cotizaciones
      ];
      final valor = valorizar(
          CartaColeccion(id: elegida.id, nombre: carta.nombre, idioma: e.idioma, acabado: e.acabado), cots, cambio);
      (salida['cartas'] as List).add({
        'texto': e.texto,
        'idioma': e.idioma.name,
        'acabado': e.acabado.name,
        'leidos': {
          'nombre': leidos.nombre,
          'ps': leidos.ps,
          'numero': leidos.numero,
          'codigoSet': leidos.codigoSet,
          'regulacion': leidos.regulacion
        },
        'candidatas': [
          for (final c in candidatas) {'id': c.id, 'nombre': c.nombre, 'numero': c.numeroLocal}
        ],
        'carta': {'id': carta.id, 'nombre': carta.nombre, 'set': carta.nombreSet, 'ps': carta.ps},
        'tcgmatch': {
          'id': precios.idCatalogo,
          'nombre': precios.nombre,
          'codigo': precios.codigo,
          'url': precios.url.toString()
        },
        'cotizaciones': [
          for (final c in cots)
            {
              'fuente': c.fuente,
              'tipo': c.tipo.name,
              'moneda': c.moneda.name,
              'valor': c.valor,
              'clp': cambio.aClp(c.valor, c.moneda).round(),
              'detalle': c.detalle,
              'fecha': c.fecha?.toIso8601String(),
            },
        ],
        'valor': {'publicadoClp': valor.publicadoClp, 'ventasClp': valor.ventasClp},
      });
    }
  } finally {
    http.cerrar();
  }
  print(const JsonEncoder.withIndent(' ').convert(salida));
}

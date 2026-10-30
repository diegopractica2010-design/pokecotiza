// Expone el lector de texto de cartas al navegador como
// `window.pokecotizaLeerTexto(texto)`, que devuelve un JSON.
// Compilar con: dart compile js -O2 -o lector.js web/lector_js.dart
import 'dart:convert';
import 'dart:js_interop';

import 'package:pokecotiza_core/src/identificacion/parser_carta.dart';

@JS('pokecotizaLeerTexto')
external set _leerTexto(JSFunction f);

void main() {
  _leerTexto = ((JSString texto) {
    final d = leerTextoCarta(texto.toDart);
    return jsonEncode({
      'nombre': d.nombre,
      'ps': d.ps,
      'numero': d.numero,
      'numeroLocal': d.numeroLocal,
      'codigoSet': d.codigoSet,
      'regulacion': d.regulacion,
    }).toJS;
  }).toJS;
}

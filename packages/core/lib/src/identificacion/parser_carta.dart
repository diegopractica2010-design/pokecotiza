/// Datos que se pueden leer del texto de una carta (por ejemplo, el texto que
/// entrega el OCR de una foto). Cualquier campo puede faltar si no se leyó.
class DatosLeidos {
  const DatosLeidos({
    this.nombre,
    this.ps,
    this.numero,
    this.codigoSet,
    this.regulacion,
  });

  final String? nombre;
  final int? ps;

  /// Número tal como está impreso, por ejemplo "025/165".
  final String? numero;
  final String? codigoSet;
  final String? regulacion;

  /// Número dentro de la expansión, sin el total: "025/165" → "025".
  String? get numeroLocal => numero?.split('/').first;

  /// Total impreso de la expansión: "025/165" → 165.
  int? get totalSet => numero == null ? null : int.tryParse(numero!.split('/').last);

  @override
  String toString() =>
      'DatosLeidos(nombre: $nombre, ps: $ps, numero: $numero, set: $codigoSet, regulacion: $regulacion)';
}

final _reNumero = RegExp(r'(\d{1,3})\s*/\s*(\d{1,3})');
final _rePs = RegExp(r'(?:\b(?:PS|HP)\s*(\d{2,3})\b)|(?:\b(\d{2,3})\s*(?:PS|HP)\b)', caseSensitive: false);
final _reRegulacion = RegExp(r'^[A-Z]$');
// Códigos de expansión: OBF, PAL, MEW, SV3, SV2a, SV4a... Mayúsculas y dígitos,
// con a lo más una minúscula final, para no confundirlos con el nombre del
// ilustrador ("Yuka Morii 1/131").
final _reCodigoSet = RegExp(r'^[A-Z]{2,4}\d{0,2}[a-z]?$');
const _codigosIdioma = {'EN', 'ES', 'JP', 'JA', 'FR', 'DE', 'IT', 'PT', 'KO'};
final _reTieneLetra = RegExp(r'\p{L}', unicode: true);

// Líneas que nunca son el nombre: etapa, tipo de carta, textos de reglas.
final _reNoNombre = RegExp(
  r'^(basic|básico|basico|stage\s*\d|fase\s*\d|etapa\s*\d|evolves|evoluciona|'
  r'trainer|entrenador|supporter|partidario|item|objeto|energy|energía|'
  r'たね|1進化|2進化)',
  caseSensitive: false,
);

/// Extrae nombre, PS, número, código de set y letra de regulación del texto
/// de una carta. Es tolerante: lo que no reconoce lo deja en null.
DatosLeidos leerTextoCarta(String texto) {
  final lineas = texto.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  String? numero;
  String? codigoSet;
  String? regulacion;
  for (final linea in lineas) {
    final m = _reNumero.firstMatch(linea);
    if (m == null) continue;
    numero = '${m.group(1)}/${m.group(2)}';
    // Lo que va antes del número en esa línea: "G OBF EN 125/197".
    final antes = linea.substring(0, m.start).split(RegExp(r'\s+'));
    for (final token in antes.where((t) => t.isNotEmpty)) {
      if (regulacion == null && _reRegulacion.hasMatch(token)) {
        regulacion = token;
      } else if (codigoSet == null &&
          !_codigosIdioma.contains(token.toUpperCase()) &&
          _reCodigoSet.hasMatch(token) &&
          token.length >= 2) {
        codigoSet = token;
      }
    }
    break;
  }

  int? ps;
  for (final linea in lineas) {
    final m = _rePs.firstMatch(linea);
    if (m != null) {
      ps = int.parse(m.group(1) ?? m.group(2)!);
      break;
    }
  }

  String? nombre;
  for (final linea in lineas) {
    if (!_reTieneLetra.hasMatch(linea)) continue;
    if (_reNoNombre.hasMatch(linea)) continue;
    if (_reNumero.hasMatch(linea)) continue;
    // El nombre suele compartir línea con los PS: "Lucario-GX HP 210".
    final sinPs = linea.replaceAll(_rePs, '').trim();
    if (sinPs.isEmpty || !_reTieneLetra.hasMatch(sinPs)) continue;
    nombre = sinPs;
    break;
  }

  return DatosLeidos(
    nombre: nombre,
    ps: ps,
    numero: numero,
    codigoSet: codigoSet,
    regulacion: regulacion,
  );
}

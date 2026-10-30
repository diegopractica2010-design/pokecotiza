import 'package:pokecotiza_core/pokecotiza_core.dart';

/// "$34.783" (formato chileno, sin decimales). Sin el paquete intl para no
/// sumar dependencias.
String pesos(int? valor) {
  if (valor == null) return '—';
  final negativo = valor < 0;
  final digitos = valor.abs().toString();
  final grupos = <String>[];
  for (var i = digitos.length; i > 0; i -= 3) {
    grupos.insert(0, digitos.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${negativo ? '-' : ''}\$${grupos.join('.')}';
}

/// "33,81 EUR"
String monedaOriginal(double valor, Moneda moneda) {
  final texto = valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toStringAsFixed(2);
  return '${texto.replaceAll('.', ',')} ${moneda.name.toUpperCase()}';
}

String nombreIdioma(Idioma i) => switch (i) {
      Idioma.ingles => 'Inglés',
      Idioma.espanol => 'Español',
      Idioma.japones => 'Japonés',
    };

String nombreAcabado(Acabado a) => switch (a) {
      Acabado.normal => 'Normal',
      Acabado.holo => 'Holo',
      Acabado.reverseHolo => 'Reverse holo',
    };

String fechaCorta(DateTime f) {
  final l = f.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.day)}-${dos(l.month)}-${l.year} ${dos(l.hour)}:${dos(l.minute)}';
}

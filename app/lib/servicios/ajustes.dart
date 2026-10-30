import 'dart:convert';
import 'dart:io';

/// Preferencias guardadas en el dispositivo: dónde está la colección.
class Ajustes {
  Ajustes(this.archivo);

  final File archivo;

  /// Id de la planilla de Google Sheets; null = la colección está en el dispositivo.
  String? idPlanilla;

  Future<void> cargar() async {
    if (!await archivo.exists()) return;
    try {
      final d = jsonDecode(await archivo.readAsString());
      if (d is Map<String, dynamic>) idPlanilla = d['idPlanilla'] as String?;
    } on FormatException {
      idPlanilla = null;
    }
  }

  Future<void> guardar() async {
    await archivo.parent.create(recursive: true);
    await archivo.writeAsString(jsonEncode({'idPlanilla': idPlanilla}));
  }
}

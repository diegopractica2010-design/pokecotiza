import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

/// Saca una foto de la carta y devuelve el texto que contiene. La lectura
/// (OCR) se hace en el teléfono, sin enviar la foto a ningún servidor.
abstract class LectorFoto {
  /// Null si el usuario cancela la foto.
  Future<String?> leer(Idioma idioma);
}

/// Android: cámara con image_picker y lectura con Google ML Kit.
class LectorFotoMlKit implements LectorFoto {
  final _camara = ImagePicker();

  @override
  Future<String?> leer(Idioma idioma) async {
    // Resolución suficiente para el texto chico de abajo de la carta.
    final foto = await _camara.pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 95);
    if (foto == null) return null;
    final lector =
        TextRecognizer(script: idioma == Idioma.japones ? TextRecognitionScript.japanese : TextRecognitionScript.latin);
    try {
      final r = await lector.processImage(InputImage.fromFilePath(foto.path));
      return r.text;
    } finally {
      await lector.close();
      // La foto no se guarda: solo servía para leer el texto.
      try {
        await File(foto.path).delete();
      } on FileSystemException {
        // si no se puede borrar, la limpia el sistema
      }
    }
  }
}

/// La cámara solo está disponible en Android (ML Kit no existe para Windows).
LectorFoto? crearLectorFoto() => Platform.isAndroid ? LectorFotoMlKit() : null;

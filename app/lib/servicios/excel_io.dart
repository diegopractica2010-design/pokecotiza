import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Lee un .xlsx y devuelve las filas de la hoja "Coleccion" si existe, o de
/// la primera hoja. Los valores quedan como texto, int o double.
List<List<Object?>> leerXlsx(List<int> bytes) {
  final libro = Excel.decodeBytes(bytes);
  if (libro.tables.isEmpty) return const [];
  final hoja = libro.tables['Coleccion'] ?? libro.tables.values.first;
  return [
    for (final fila in hoja.rows)
      [
        for (final celda in fila)
          switch (celda?.value) {
            null => null,
            IntCellValue(:final value) => value,
            DoubleCellValue(:final value) => value,
            TextCellValue() && final t => t.value.text ?? t.toString(),
            final otro => otro.toString(),
          },
      ],
  ];
}

/// Escribe las filas en un .xlsx con una hoja "Coleccion".
Uint8List escribirXlsx(List<List<Object?>> filas) {
  final libro = Excel.createExcel();
  final porDefecto = libro.getDefaultSheet();
  if (porDefecto != null && porDefecto != 'Coleccion') libro.rename(porDefecto, 'Coleccion');
  final hoja = libro['Coleccion'];
  for (final f in filas) {
    hoja.appendRow([
      for (final v in f)
        switch (v) {
          null => null,
          int() => IntCellValue(v),
          double() => DoubleCellValue(v),
          _ => '$v'.isEmpty ? null : TextCellValue('$v'),
        },
    ]);
  }
  final bytes = libro.encode();
  if (bytes == null) throw StateError('No se pudo generar el archivo Excel');
  return Uint8List.fromList(bytes);
}

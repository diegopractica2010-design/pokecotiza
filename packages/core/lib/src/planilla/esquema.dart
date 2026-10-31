import '../errores.dart';
import '../modelos.dart';

/// Estructura de la planilla de PokeCotiza. Cambiar el orden de columnas
/// rompe planillas existentes: agregar columnas solo al final y subir
/// [versionEsquema].
abstract final class Esquema {
  static const versionEsquema = 2;

  static const coleccion = 'Coleccion';
  static const precios = 'Precios';
  static const resumen = 'Resumen';
  static const config = 'Config';
  static const pestanas = [coleccion, precios, resumen, config];

  static const columnasColeccion = [
    'id', 'nombre', 'idioma', 'codigo_set', 'numero', 'regulacion', 'condicion', 'acabado', //
    'gradeadora', 'nota_gradeo', 'cantidad', 'tcgdex_id', 'tcgmatch_id', 'valor_manual_clp', 'foto_url', 'fecha_alta',
    'tiendas', // v2: "afkstore:handle;otra:handle"
  ];

  /// `fecha`: cuándo se registró. `fecha_fuente`: fecha del dato según la fuente
  /// (por ejemplo, la última actualización de Cardmarket en TCGdex).
  static const columnasPrecios = [
    'fecha',
    'id_carta',
    'fuente',
    'tipo',
    'moneda',
    'valor',
    'valor_clp',
    'detalle',
    'url',
    'fecha_fuente',
  ];
  static const columnasResumen = ['fecha', 'publicado_clp', 'ventas_clp', 'cartas'];
  static const columnasConfig = ['clave', 'valor'];

  static List<String> encabezados(String pestana) => switch (pestana) {
        coleccion => columnasColeccion,
        precios => columnasPrecios,
        resumen => columnasResumen,
        config => columnasConfig,
        _ => throw ArgumentError.value(pestana, 'pestana'),
      };

  /// Rango de columnas de una pestaña, por ejemplo "Coleccion!A:P".
  static String rango(String pestana) => '$pestana!A:${ultimaColumna(pestana)}';

  /// Letra de la última columna de una pestaña, por ejemplo "P".
  static String ultimaColumna(String pestana) => _letra(encabezados(pestana).length);

  static String _letra(int n) => String.fromCharCode('A'.codeUnitAt(0) + n - 1);
}

/// Una fila de la planilla que no se pudo interpretar (por ejemplo, editada
/// a mano con un valor inválido). Se informa en vez de detener la lectura.
class FilaInvalida {
  const FilaInvalida(this.numeroFila, this.motivo);

  /// Número de fila tal como se ve en Google Sheets (la primera es 1).
  final int numeroFila;
  final String motivo;

  @override
  String toString() => 'Fila $numeroFila: $motivo';
}

List<Object?> cartaAFila(CartaColeccion c) => [
      c.id,
      c.nombre,
      c.idioma.codigoTcgdex,
      c.codigoSet ?? '',
      c.numero ?? '',
      c.regulacion ?? '',
      c.condicion.abreviatura,
      c.acabado.name,
      c.gradeo?.empresa ?? '',
      c.gradeo?.nota ?? '',
      c.cantidad,
      c.tcgdexId ?? '',
      c.tcgmatchId ?? '',
      c.valorManualClp ?? '',
      c.fotoUrl ?? '',
      c.fechaAlta?.toUtc().toIso8601String() ?? '',
      [for (final e in c.enlacesTiendas.entries) '${e.key}:${e.value}'].join(';'),
    ];

/// Convierte una fila en carta. Lanza [FormatoInesperado] si un campo
/// obligatorio falta o no es válido.
CartaColeccion filaACarta(List<Object?> fila) {
  String texto(int i) => i < fila.length && fila[i] != null ? '${fila[i]}'.trim() : '';
  String? opcional(int i) => texto(i).isEmpty ? null : texto(i);
  int? entero(int i) {
    final v = i < fila.length ? fila[i] : null;
    if (v is num) {
      // Un decimal (por ejemplo, cantidad 1,6) es un error de edición: no se redondea.
      if (v != v.roundToDouble()) throw FormatoInesperado('planilla', '"$v" no es un número entero');
      return v.toInt();
    }
    final t = texto(i);
    if (t.isEmpty) return null;
    return int.tryParse(t) ?? (throw FormatoInesperado('planilla', '"$t" no es un número entero'));
  }

  final id = texto(0);
  final nombre = texto(1);
  if (id.isEmpty) throw FormatoInesperado('planilla', 'falta el id');
  if (nombre.isEmpty) throw FormatoInesperado('planilla', 'falta el nombre');
  final idioma = Idioma.values.where((i) => i.codigoTcgdex == texto(2).toLowerCase()).firstOrNull ??
      (throw FormatoInesperado('planilla', 'idioma "${texto(2)}" no válido (usar en, es o ja)'));
  final condicion = texto(6).isEmpty
      ? Condicion.nm
      : (Condicion.desdeTexto(texto(6)) ?? (throw FormatoInesperado('planilla', 'condición "${texto(6)}" no válida')));
  final acabado = texto(7).isEmpty
      ? Acabado.normal
      : (Acabado.values.where((a) => a.name.toLowerCase() == texto(7).toLowerCase().replaceAll(' ', '')).firstOrNull ??
          (throw FormatoInesperado('planilla', 'acabado "${texto(7)}" no válido (normal, holo, reverseHolo)')));
  final cantidad = entero(10) ?? 1;
  if (cantidad < 1) throw FormatoInesperado('planilla', 'la cantidad debe ser 1 o más (es $cantidad)');
  final valorManual = entero(13);
  if (valorManual != null && valorManual < 0) {
    throw FormatoInesperado('planilla', 'el valor manual no puede ser negativo ($valorManual)');
  }
  final gradeadora = opcional(8);
  return CartaColeccion(
    id: id,
    nombre: nombre,
    idioma: idioma,
    codigoSet: opcional(3),
    numero: opcional(4),
    regulacion: opcional(5),
    condicion: condicion,
    acabado: acabado,
    gradeo: gradeadora == null ? null : Gradeo(empresa: gradeadora, nota: texto(9)),
    cantidad: cantidad,
    tcgdexId: opcional(11),
    tcgmatchId: entero(12),
    valorManualClp: valorManual,
    fotoUrl: opcional(14),
    fechaAlta: DateTime.tryParse(texto(15)),
    enlacesTiendas: {
      for (final par in texto(16).split(';'))
        if (par.contains(':') && par.split(':')[1].trim().isNotEmpty)
          par.split(':')[0].trim(): par.split(':')[1].trim(),
    },
  );
}

List<Object?> cotizacionAFila(String idCarta, Cotizacion c, int valorClp, DateTime fecha) => [
      fecha.toUtc().toIso8601String(),
      idCarta,
      c.fuente,
      c.tipo.name,
      c.moneda.name.toUpperCase(),
      c.valor,
      valorClp,
      c.detalle ?? '',
      c.url?.toString() ?? '',
      c.fecha?.toUtc().toIso8601String() ?? '',
    ];

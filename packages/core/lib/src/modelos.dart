/// Idiomas de carta soportados, con el código que usa cada fuente.
enum Idioma {
  ingles('en', 'english'),
  espanol('es', 'spanish'),
  japones('ja', 'japanese');

  const Idioma(this.codigoTcgdex, this.codigoTcgmatch);

  final String codigoTcgdex;
  final String codigoTcgmatch;
}

/// Condición física de la carta (escala habitual en el mercado).
enum Condicion {
  nm('NM', 'Near Mint'),
  lp('LP', 'Lightly Played'),
  mp('MP', 'Moderately Played'),
  hp('HP', 'Heavily Played'),
  dmg('DMG', 'Damaged');

  const Condicion(this.abreviatura, this.nombre);

  final String abreviatura;
  final String nombre;

  /// Interpreta textos como "NM", "near mint", "near-mint" o "Lightly Played".
  /// Devuelve null si no lo reconoce.
  static Condicion? desdeTexto(String texto) {
    final t = texto.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');
    for (final c in Condicion.values) {
      if (t == c.abreviatura.toLowerCase() || t == c.nombre.toLowerCase()) {
        return c;
      }
    }
    return null;
  }
}

/// Acabado de la impresión. Cambia mucho el precio.
enum Acabado {
  normal,

  /// Carta brillante en la ilustración (incluye Full Art, ex, GX, etc.).
  holo,

  /// Brillo en el resto de la carta, no en la ilustración.
  reverseHolo,
}

enum Moneda { clp, usd, eur }

/// Publicado: precio pedido por vendedores. Ventas: precio efectivamente pagado.
enum TipoPrecio { publicado, ventas }

/// Gradeo de una carta certificada, por ejemplo PSA 10.
class Gradeo {
  const Gradeo({required this.empresa, required this.nota});

  final String empresa;
  final String nota;

  @override
  String toString() => '$empresa $nota';
}

/// Una carta física de la colección (una fila de la pestaña `Coleccion`).
class CartaColeccion {
  const CartaColeccion({
    required this.id,
    required this.nombre,
    required this.idioma,
    this.codigoSet,
    this.numero,
    this.regulacion,
    this.condicion = Condicion.nm,
    this.gradeo,
    this.cantidad = 1,
    this.acabado = Acabado.normal,
    this.tcgdexId,
    this.tcgmatchId,
    this.valorManualClp,
    this.fotoUrl,
    this.fechaAlta,
    this.enlacesTiendas = const {},
  });

  final String id;
  final String nombre;
  final Idioma idioma;
  final String? codigoSet;

  /// Número impreso, por ejemplo "122/131".
  final String? numero;
  final String? regulacion;
  final Condicion condicion;
  final Gradeo? gradeo;
  final int cantidad;
  final Acabado acabado;

  /// Id de la carta en TCGdex, por ejemplo "sm6-122".
  final String? tcgdexId;

  /// Id de la página `/producto/catalogo/{id}` de TCGmatch.
  final int? tcgmatchId;

  /// Valor ingresado a mano (se usa para cartas gradeadas).
  final int? valorManualClp;

  /// Enlace a la foto en Google Drive.
  final String? fotoUrl;
  final DateTime? fechaAlta;

  /// Producto vinculado en cada tienda chilena: id de tienda → handle.
  final Map<String, String> enlacesTiendas;
}

/// Un precio obtenido de una fuente.
class Cotizacion {
  const Cotizacion({
    required this.fuente,
    required this.tipo,
    required this.moneda,
    required this.valor,
    this.fecha,
    this.url,
    this.detalle,
  });

  final String fuente;
  final TipoPrecio tipo;
  final Moneda moneda;
  final double valor;

  /// Fecha del dato según la fuente (o de la consulta si la fuente no la da).
  final DateTime? fecha;
  final Uri? url;

  /// Qué campo de la fuente se usó, por ejemplo "cardmarket avg30".
  final String? detalle;

  @override
  String toString() => '$fuente ${tipo.name} ${valor.toStringAsFixed(2)} ${moneda.name.toUpperCase()}'
      '${detalle != null ? ' ($detalle)' : ''}';
}

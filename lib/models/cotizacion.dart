/// Un precio encontrado para una carta en un mercado.
class Cotizacion {
  final String mercado;
  final String titulo;
  final double precio;
  final String moneda; // CLP, USD, EUR...
  final Uri url;
  final DateTime obtenidoEn;

  Cotizacion({
    required this.mercado,
    required this.titulo,
    required this.precio,
    required this.moneda,
    required this.url,
    DateTime? obtenidoEn,
  }) : obtenidoEn = obtenidoEn ?? DateTime.now();
}

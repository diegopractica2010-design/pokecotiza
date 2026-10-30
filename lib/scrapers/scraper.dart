import '../models/cotizacion.dart';

/// Interfaz común: cada mercado implementa su propio scraper.
abstract class MercadoScraper {
  String get nombre;
  Future<List<Cotizacion>> buscar(String carta);
}

# PokeCotiza

Aplicación para **Android y Windows** que cotiza cartas Pokémon TCG consultando (web scraping / APIs) los principales mercados de Chile y del mundo, y muestra los precios comparados en CLP.

## Stack propuesto
- **Flutter** (un solo código para Android y Windows).
- Scrapers en Dart (`http` + `html`), uno por mercado, detrás de una interfaz común (`lib/scrapers/scraper.dart`).

## Mercados
Ver [`docs/mercados.md`](docs/mercados.md). La lista está en revisión: cada fuente debe validarse (estructura del sitio, términos de uso, existencia de API oficial) antes de implementarse.

## Estado
Estructura inicial. Nada compilado ni probado todavía.

## Desarrollo
```bash
flutter pub get
flutter run -d windows   # o un dispositivo Android
```

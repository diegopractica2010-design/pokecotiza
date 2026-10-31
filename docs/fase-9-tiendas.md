# Fase 9: tiendas chilenas adicionales

Hecha el 2026-10-31.

## AFK Store (integrada)
- **Fuente:** el catálogo público de Shopify de la tienda (`/products/<producto>.js` y su buscador `/search/suggest.json`). Su robots.txt permite las páginas de productos y sus términos no mencionan scraping (revisado el 2026-10-30).
- **Cómo se vincula:** en "Confirmar carta", "Buscar en AFK Store" abre la búsqueda; se pega el enlace del producto (`https://www.afkstore.cl/products/...`). Se guarda en la nueva columna `tiendas` de la planilla (formato v2, agregada al final para no romper planillas existentes).
- **Qué precio se usa:** el de la variante con el **mismo idioma y condición** que la carta, **solo si tiene stock**. Las variantes se llaman, por ejemplo, "Ingles", "Español (Lp)". Las que no se pueden interpretar (por ejemplo, "Ingles (Pikachu 173 no Raw. esta Psa 8)") se ignoran.
- **Supuesto (sin verificar):** una variante sin condición ("Ingles") se trata como NM.
- **Precios:** `.js` informa centavos de peso (70.000.000 = $700.000), verificado comparando con la versión `.json` del mismo producto.

## Otras tiendas revisadas
| Tienda | Estado | Motivo |
|---|---|---|
| Pokestop | No integrada | No es Shopify con feed abierto (`/products.json` da 404); habría que leer HTML. Queda para después |
| Collector Center, Piedra Bruja, Oasis Games | No integradas | Venden sobre todo producto sellado (fase 1) |
| Mercado Libre | No integrada | Su API exige autenticación (fase 1) |

Agregar otra tienda Shopify es una línea en `tiendasShopify` (`packages/core/lib/src/fuentes/shopify.dart`), si su feed tiene variantes con el mismo formato.

## Pruebas
- Núcleo: 6 pruebas con respuestas reales guardadas de AFK Store (enlaces, variantes, precios, búsqueda, cotizador con caída de la tienda, columna nueva en la planilla).
- App: 1 prueba del flujo completo vinculando AFK Store.

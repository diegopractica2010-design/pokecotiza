# Fuentes de precios

> Ninguna fuente está validada todavía. Antes de implementar cada una hay que revisar: términos de uso y robots.txt, si existe API oficial, límites de uso, cobertura (idiomas, gradeadas) y moneda.

## Catálogo y precios de referencia (internacional)
| Fuente | Qué aporta | Estado |
|---|---|---|
| Pokémon TCG API (pokemontcg.io) | Catálogo + precios TCGplayer (USD) y Cardmarket (EUR) | Hay fuentes de terceros que dicen que se fusionó con Scrydex (de pago). **Por verificar** su estado actual y sus límites gratuitos. |
| pokemontcgapi.com | Precios Cardmarket/TCGplayer, filtro de impresiones japonesas | Según su documentación, sin precios de gradeadas. **Por verificar** el plan gratuito. |
| TCGdex | Catálogo multilenguaje | **Por verificar** cobertura de español y japonés. |
| TCGplayer | Mercado EE.UU. (USD) | Preferir vía API. |
| Cardmarket | Mercado Europa (EUR) | Preferir vía API. |
| eBay (ventas completadas) | Precios reales, incluidas gradeadas | **Por verificar** si hay API utilizable o si el scraping está permitido. |

## Chile (CLP)
Revisión inicial del 2026-10-30. Solo se leyó el robots.txt y se probó si responde `/products.json` (feed público típico de tiendas Shopify). **No se han leído los términos de uso de ningún sitio.**

| Fuente | Tipo | robots.txt | Feed `/products.json` | Notas |
|---|---|---|---|---|
| [TCGmatch](https://tcgmatch.cl/) | Marketplace de varios vendedores, singles por condición | Bloquea `/api/`; las páginas públicas no están bloqueadas | No (404) | **Fuente principal en Chile.** Hay que leer el HTML público; su API está excluida por robots.txt, así que no se usará. |
| [Pokestop](https://pokestop.cl/singles/) | Tienda de singles | Páginas de productos permitidas | No (404) | Leer el HTML. |
| [AFK Store](https://www.afkstore.cl/collections/singles-pokemon) | Tienda de singles | Permitido | Sí (200) | Probablemente Shopify; preferir el feed JSON. |
| [Piedra Bruja](https://piedrabruja.cl/collections/pokemon) | Tienda (más sellado que singles) | Permitido | Sí (200) | Verificar si tiene singles. |
| [Oasis Games](https://www.oasisgames.cl/) | Tienda física + online | Permitido | Sí (200) | Verificar si tiene singles. |
| [Magic4ever](https://www.magic4ever.cl/cartas-sueltas-pokemon) | Tienda (foco en Magic) con singles Pokémon | Permitido | No (404) | Leer el HTML. |
| [Collector Center](https://collectorcenter.cl/) | Tienda Pokémon | Permitido | Sí (200) | El resultado de búsqueda era antiguo; confirmar que sigue activa. |
| Mercado Libre Chile | Marketplace general | Por revisar | — | Por verificar si tiene API pública de búsqueda. |
| Yapo.cl | Avisos de particulares | Por revisar | — | Precios dispersos; prioridad baja. |

## Japón (JPY)
| Fuente | Qué aporta | Estado |
|---|---|---|
| CardRush | Singles japoneses, con gradeo PSA | Existe un scraper de terceros (Apify), lo que sugiere que se puede scrapear. **Por verificar** los términos del sitio. |

## Gradeadas
No hay fuente gratuita confirmada. Candidatas: ventas completadas en eBay, Mercado Libre (búsqueda "PSA 10") y CardRush para japonesas.

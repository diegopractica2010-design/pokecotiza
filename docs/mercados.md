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
| Fuente | Qué aporta | Estado |
|---|---|---|
| Mercado Libre Chile | Publicaciones de singles y gradeadas | Por verificar si tiene API pública de búsqueda. |
| Yapo.cl | Avisos de particulares | Precios muy dispersos; usar solo como referencia. |
| Tiendas TCG chilenas | Singles | **Pendiente**: el dueño debe indicar qué tiendas usa. |

## Japón (JPY)
| Fuente | Qué aporta | Estado |
|---|---|---|
| CardRush | Singles japoneses, con gradeo PSA | Existe un scraper de terceros (Apify), lo que sugiere que se puede scrapear. **Por verificar** los términos del sitio. |

## Gradeadas
No hay fuente gratuita confirmada. Candidatas: ventas completadas en eBay, Mercado Libre (búsqueda "PSA 10") y CardRush para japonesas.

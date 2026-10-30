# Fase 1: investigación de fuentes de precios

Fecha de las pruebas: **2026-10-30**. Cada prueba fue una consulta manual desde la línea de comandos (pocas peticiones, con pausas). Los resultados pueden cambiar si los sitios cambian.

## Resumen
| Fuente | ¿Sirve? | Cómo se accede | Qué entrega |
|---|---|---|---|
| **TCGmatch** (Chile) | **Sí** | Página pública de cada carta (`/producto/catalogo/{id}`), una vez vinculada | CLP: bajo/medio/alto/mercado, por idioma; **ventas reales** (cantidad y mediana); además precios TCGplayer en USD |
| **TCGdex** | **Sí** | API pública, sin clave | Catálogo en **inglés, español y japonés**; precios Cardmarket (EUR, con promedios 1/7/30 días) y TCGplayer (USD) |
| pokemontcg.io | Parcial | API pública | Catálogo en inglés. En la prueba, los precios de Cardmarket estaban desactualizados (2025-11-21). Primera petición devolvió error 500, la segunda funcionó |
| mindicador.cl | **Sí** | API pública | Dólar y euro en CLP del día (2026-10-30: USD 993,22; EUR 1.109,37) |
| AFK Store (Chile) | Sí | Feed público `/products.json` (Shopify) | Precio CLP; cada variante indica **idioma y condición** (ej. "Ingles (Lp)") |
| Collector Center, Piedra Bruja, Oasis Games | Bajo valor | Feed `/products.json` | En los primeros 250 productos casi no hay singles Pokémon (mayormente sellado y eventos) |
| Pokestop, Magic4ever (Chile) | Por probar | HTML público (robots.txt lo permite) | — |
| Mercado Libre Chile | **No, por ahora** | API de búsqueda | Respondió **403 "forbidden"** sin autenticación. Por verificar si con una app registrada (gratis) se permite |
| CardRush (Japón) | Probable | HTML público | robots.txt solo bloquea bots de IA (GPTBot, etc.). Términos de uso **no revisados** |
| eBay (ventas reales, gradeadas) | Por investigar | API oficial con cuenta de desarrollador | No probado |

## TCGmatch en detalle
### Qué permite
- **robots.txt:** permite todo excepto `/api/`, `/checkout`, `/mi-cuenta`, `/vender` y otras rutas privadas.
- **Términos y condiciones** (actualizados el 09-10-2024): no mencionan scraping, robots ni extracción automática. Sí dicen que el contenido es propiedad de TCGmatch o de sus licenciantes.
  - **Uso personal:** leer pocas páginas públicas a baja frecuencia es razonable.
  - **Uso comercial:** antes de comercializar la app hay que pedir autorización. Ver [contacto-tcgmatch.md](contacto-tcgmatch.md).

### Qué datos hay
Las páginas son Next.js y traen los datos en `<script id="__NEXT_DATA__">` (JSON), además de JSON-LD estándar.

| Página | Datos útiles |
|---|---|
| `/producto/catalogo/{id}` (una carta) | `markets.tcgmatch.prices` (low/mid/high/market, CLP), `countSellers`, `sales.count`, `sales.median`, `byLanguage.{spanish,english}`; `markets.tcgplayer.printings[]` (USD por variante) |
| `/producto/{id}` (una publicación) | precio, `language`, `status` (condición: `near-mint`, …), `printing`, `catalog._id`, `card.externalId` (= id de pokemontcg.io, ej. `sm6-122`). También trae el nombre del vendedor: **no se guardará** |
| `/cartas/pokemon/{set}` | Solo las primeras 24 cartas de la expansión, con `lowestPrice`, `marketPrice`, `listingsCount`. El resto se carga con "Cargar más" vía `/api/`, que no se usará |

### El problema: encontrar la carta
- El buscador del sitio funciona con `/api/`, excluido por robots.txt.
- Los sitemaps listan ~790.000 publicaciones (`/producto/{id}`), pero no las páginas de carta.

### La solución propuesta: vincular cada carta una vez
1. Al agregar una carta, la app abre TCGmatch **dentro de la app** (navegador embebido) con la búsqueda de esa carta. El usuario navega como cualquier persona.
2. Cuando el usuario abre la carta correcta, la app reconoce la URL:
   - `/producto/catalogo/{id}`: toma el `id`.
   - `/producto/{id}`: lee `catalog._id` de esa publicación.
   La app guarda ese id en la columna `tcgmatch_id` de la planilla.
3. También se puede pegar el enlace a mano (útil en Windows y al importar planillas).
4. Desde ahí, la app y la tarea diaria consultan solo `/producto/catalogo/{id}`: **una petición por carta** (~60 al día), con pausas entre peticiones.

Con 60 cartas, vincularlas es un trabajo de una sola vez de unos minutos.

### Limitaciones
- TCGmatch entrega **mediana** de ventas, no promedio. Decidido: se usa la mediana (menos sensible a ventas atípicas), mostrada como "precio de ventas reales".
- Los precios agregados vienen por **idioma**, no por **condición**. Para precio por condición habría que leer publicaciones individuales; queda para después.
- Si TCGmatch cambia su estructura, el adaptador deja de funcionar; se detecta con pruebas sobre páginas guardadas.

## Cómo encaja con los requisitos
| Requisito | Fuente principal | Respaldo |
|---|---|---|
| Promedio publicado (CLP) | TCGmatch `prices.mid/market` + tiendas Shopify | TCGplayer/Cardmarket convertidos |
| Ventas reales | TCGmatch `sales.median` | Cardmarket `avg30` (TCGdex), por confirmar si es de ventas |
| Español y japonés | TCGdex (catálogo) + TCGmatch `byLanguage.spanish` | — |
| Japonés (precios) | TCGdex/Cardmarket | CardRush (por verificar términos) |
| Gradeadas | **Sin fuente confirmada** | TCGmatch tiene sección "Gradeadas" (`/cartas/busqueda/type=graded`), por investigar; eBay |
| Condición | AFK Store (variantes) | Publicaciones de TCGmatch (futuro) |
| Tipo de cambio | mindicador.cl | — |

## Cierre de la fase 1 (2026-10-30)
| Tema | Resultado | Consecuencia |
|---|---|---|
| Gradeadas en TCGmatch | La búsqueda `/cartas/busqueda/type=graded` se carga desde `/api/` (la página trae solo la lista de juegos). No hay datos públicos sin la API | Gradeadas: **valor manual** por ahora (el usuario ingresa el valor). Se podrá vincular una publicación gradeada concreta más adelante |
| eBay (ventas reales) | Según la documentación oficial, la Marketplace Insights API (historial de ventas de 90 días) es de **acceso restringido**: solo para desarrolladores aprobados por eBay | **Descartado** por ahora |
| Mercado Libre | La API respondió 403 sin autenticación. La documentación oficial atribuye el 403 a token o permisos; un tercero dice que desde 2025 las búsquedas anónimas devuelven 403 (no confirmado oficialmente) | **Pospuesto** a la fase 9: habría que registrar una app y usar OAuth |
| TCGdex | Su base de datos de cartas tiene **licencia MIT** (`tcgdex/cards-database`). Los precios provienen de Cardmarket y TCGplayer, cuyos términos pueden restringir la redistribución | **Aprobado** para uso personal |
| Campos de Cardmarket | Según el SDK de TCGdex y un tercero: `low` = publicación más barata; `trend` = precio de tendencia de Cardmarket; `avg1/avg7/avg30` = promedio de **ventas** de 1, 7 y 30 días; sufijo `-holo` para la versión holo. No hay documentación oficial que lo confirme | Se usará `avg30` como respaldo de "ventas reales", marcado como fuente secundaria |
| AFK Store | Sus términos de servicio no mencionan scraping ni robots | **Aprobado** (feed `/products.json`) |
| Pokestop | No tiene página de términos en `/policies/terms-of-service` (404); robots.txt permite las páginas de productos | **Aprobado** con baja frecuencia (fase 9) |
| CardRush | robots.txt solo bloquea bots de IA; términos no revisados (sitio en japonés) | Pospuesto: TCGdex ya cubre precios de cartas japonesas vía Cardmarket |

### Fuentes que entran en la fase 2
1. **TCGdex:** catálogo (EN/ES/JA) y precios Cardmarket/TCGplayer.
2. **TCGmatch:** precios CLP por idioma y mediana de ventas, vía `/producto/catalogo/{id}`.
3. **mindicador.cl:** USD y EUR a CLP.

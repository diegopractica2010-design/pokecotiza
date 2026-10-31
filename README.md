# PokeCotiza

App para **Android y Windows** que valoriza una colección de cartas Pokémon TCG: identifica cada carta (foto, búsqueda manual o planilla), la cotiza en mercados de Chile y del mundo, y guarda la colección y el historial de precios en **Google Sheets**.

> **Estado:** todas las fases del plan tienen código, pruebas y revisión. Falta: configurar credenciales de Google y la clave de firma de Android (pasos del dueño), y probar en un teléfono y un PC reales.
>
> **Instalar:** [docs/instalar.md](docs/instalar.md).

## Qué hace
- **Identificar cartas:** foto con la cámara en Android (lee nombre, PS, número, set y regulación), escribir nombre y número, o importar un Excel. Siempre se confirma la carta entre las candidatas de TCGdex.
- **Cotizar** en TCGplayer (USD) y Cardmarket (EUR) vía TCGdex, y en Chile en TCGmatch (mediana de ventas reales) y AFK Store. Todo se convierte a pesos con el dólar y el euro de mindicador.cl.
- **Dos valores por carta:** precio publicado (mediana) y precio de ventas reales.
- **Guardar** en el dispositivo o en tu Google Sheets, compartida entre teléfono y PC.
- **Historial y gráficos** del valor de cada carta y de la colección.
- **Tarea diaria** gratuita en GitHub Actions que actualiza toda la colección en la planilla.
- **Exportar e importar** la colección en Excel.
- Cartas en **inglés, español y japonés**; **gradeadas** con valor manual.

## Estructura
| Carpeta | Qué hay |
|---|---|
| `app/` | App Flutter (Android y Windows) |
| `packages/core/` | Lógica compartida en Dart: fuentes de precios, lector de texto, valorización, planilla |
| `tools/actualizador/` | Tarea diaria |
| `docs/` | Requisitos, arquitectura, decisiones, una guía por fase y guías de configuración |

## Documentación principal
| Documento | Contenido |
|---|---|
| [docs/instalar.md](docs/instalar.md) | Descargar, instalar y primeros pasos |
| [docs/google-cloud.md](docs/google-cloud.md) | Conectar con Google Sheets |
| [docs/tarea-diaria.md](docs/tarea-diaria.md) | Configurar la actualización diaria |
| [docs/firma-android.md](docs/firma-android.md) | Clave de firma fija para Android |
| [docs/plan-de-trabajo.md](docs/plan-de-trabajo.md) | Fases y su estado |
| [docs/decisiones.md](docs/decisiones.md) | Decisiones y por qué |
| [docs/arquitectura.md](docs/arquitectura.md) | Diseño técnico |

## Licencia
Todos los derechos reservados. El código es visible pero no se concede permiso para usarlo, copiarlo ni distribuirlo. Ver [LICENSE](LICENSE).

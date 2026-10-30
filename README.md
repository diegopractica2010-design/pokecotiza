# PokeCotiza

App para **Android y Windows** que valoriza una colección de cartas Pokémon TCG: identifica cada carta (foto, búsqueda manual o planilla), la cotiza en mercados de Chile y del mundo, y guarda la colección y el historial de precios en **Google Sheets**.

> **Estado:** fase 2 (núcleo) en curso. Fases 0 y 1 cerradas. Ver [plan de trabajo](docs/plan-de-trabajo.md).

## Qué hará
- **Identificar cartas**
  - Android: foto con la cámara → lee nombre, PS, código de set, letra de regulación y número.
  - Android y Windows: ingreso manual.
  - Windows: importar un Excel o una hoja de Google Sheets.
- **Cotizar** en varios mercados y convertir a CLP.
- **Guardar** la colección y los precios en Google Sheets, compartida entre teléfono y PC.
- **Actualizar a diario** los precios de toda la colección con una tarea gratuita de GitHub Actions, y llevar historial.
- Cartas en **inglés, español y japonés**, y **gradeadas** (PSA, etc.).

## Documentación
| Documento | Contenido |
|---|---|
| [docs/requisitos.md](docs/requisitos.md) | Qué debe hacer la app (requisitos levantados contigo) |
| [docs/arquitectura.md](docs/arquitectura.md) | Diseño técnico en papel |
| [docs/mercados.md](docs/mercados.md) | Fuentes de precios y su estado de verificación |
| [docs/plan-de-trabajo.md](docs/plan-de-trabajo.md) | Fases, entregables y orden de desarrollo |
| [docs/decisiones.md](docs/decisiones.md) | Registro de decisiones y por qué se tomaron |
| [docs/preguntas-abiertas.md](docs/preguntas-abiertas.md) | Lo que falta definir |

## Stack previsto
Flutter (Dart) para la app, un paquete Dart compartido con la lógica de cotización, Google Sheets como base de datos y GitHub Actions para la actualización diaria. Detalle en la arquitectura.

## Licencia
Todos los derechos reservados. El código es visible pero no se concede permiso para usarlo, copiarlo ni distribuirlo. Ver [LICENSE](LICENSE).

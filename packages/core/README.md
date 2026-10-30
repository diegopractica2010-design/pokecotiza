# pokecotiza_core

Lógica de PokeCotiza sin interfaz gráfica. La usan la app (Flutter) y, más adelante, la tarea diaria de GitHub Actions.

## Qué incluye
| Archivo | Qué hace |
|---|---|
| `lib/src/modelos.dart` | Carta de la colección, idioma, condición, acabado, gradeo, cotización |
| `lib/src/identificacion/parser_carta.dart` | Lee nombre, PS, número, código de set y regulación desde el texto de una carta (por ejemplo, el OCR de una foto) |
| `lib/src/fuentes/tcgdex.dart` | Catálogo (EN/ES/JA) y precios de Cardmarket (EUR) y TCGplayer (USD) vía TCGdex |
| `lib/src/fuentes/tcgmatch.dart` | Precios en CLP por idioma y mediana de ventas desde páginas públicas de TCGmatch. No usa `/api/` |
| `lib/src/fuentes/mindicador.dart` | Dólar y euro en CLP, con respaldo al último valor conocido |
| `lib/src/valorizacion.dart` | Valor por carta (mediana publicada y de ventas reales) y total de la colección |
| `lib/src/planilla/` | Colección, historial de precios, resumen y tipo de cambio en Google Sheets |
| `lib/src/http/cliente_cortes.dart` | Cliente HTTP con pausa entre peticiones al mismo sitio |

## Uso local
Requiere el SDK de Dart (probado con 3.13.7).

```bash
dart pub get
```

```bash
dart test
```

Cotizar una carta real (hace peticiones a TCGmatch, TCGdex y mindicador.cl):

```bash
dart run example/cotizar.dart https://tcgmatch.cl/producto/catalogo/44078 sm6-122 es holo
```

## Pruebas
Las pruebas usan respuestas reales guardadas en `test/fixtures/` (2026-10-30), recortadas para no incluir datos personales de vendedores. Si un sitio cambia su formato, las pruebas siguen pasando pero el uso real falla con `FormatoInesperado`: hay que guardar una respuesta nueva y ajustar el adaptador.

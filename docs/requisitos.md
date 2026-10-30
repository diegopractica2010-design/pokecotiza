# Requisitos

Levantados con el dueño del proyecto el 2026-10-30.

## Objetivo
Valorizar la colección personal de cartas Pokémon y seguir cómo cambia su valor en el tiempo.

## Usuarios y volumen
Un usuario (el dueño), con un teléfono Android y un PC con Windows. Colección inicial de **~60 cartas**.

## Licencia y uso futuro
Código con todos los derechos reservados (ver `LICENSE`); se busca poder comercializar la app más adelante.

## Requisitos funcionales
| ID | Requisito | Plataforma | Prioridad |
|---|---|---|---|
| RF-01 | Ingresar una carta a mano (nombre, set, número, idioma, condición, gradeo) | Android, Windows | Alta |
| RF-02 | Ingresar una carta con una foto: leer nombre, PS, código de set, letra de regulación y número | Android | Alta |
| RF-03 | Confirmar o corregir la carta detectada antes de guardarla (elegir entre candidatas) | Android, Windows | Alta |
| RF-04 | Importar cartas desde un Excel (.xlsx) o una hoja de Google Sheets | Windows | Media |
| RF-05 | Cotizar una carta en varios mercados y mostrar el precio original y en CLP | Android, Windows | Alta |
| RF-05b | Calcular dos valores por carta: **promedio de precios publicados** y **promedio de ventas reales** (cuando la fuente las entregue) | Todas | Alta |
| RF-06 | Guardar la colección y las cotizaciones en Google Sheets | Android, Windows | Alta |
| RF-07 | Ver el valor total de la colección | Android, Windows | Alta |
| RF-08 | Actualizar a diario los precios de toda la colección, sin servidor pagado | GitHub Actions | Media |
| RF-09 | Ver el historial de precios de una carta y de la colección | Android, Windows | Media |
| RF-10 | Soportar cartas en inglés, español y japonés | Todas | Alta (EN), Media (ES/JP) |
| RF-11 | Soportar cartas gradeadas (empresa y nota) | Todas | Media |
| RF-12 | Exportar la colección a Excel | Windows | Baja |
| RF-13 | Registrar la condición de la carta (NM, LP, MP, HP, DMG) y cotizar según ella; NM por defecto si no se indica | Todas | Alta |
| RF-14 | Guardar una foto de cada carta en Google Drive y enlazarla desde la planilla | Android (cámara), Windows (subir archivo) | Media |

## Requisitos no funcionales
- **Costo cero de infraestructura:** sin servidor pagado.
- **Tolerancia a fallos de fuentes:** si un mercado cambia o bloquea, el resto sigue funcionando y la app avisa qué fuente falló.
- **Trazabilidad:** cada precio guarda su fuente, moneda, fecha y enlace.
- **Respeto a los sitios:** preferir APIs oficiales, respetar términos de uso, consultar a baja frecuencia y con caché.

## Fuera de alcance (por ahora)
- Comprar o vender desde la app.
- Varios usuarios o cuentas.
- iOS / macOS.

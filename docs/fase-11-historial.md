# Fase 11: historial y gráficos

Hecha el 2026-10-31.

## Qué muestra la app
- **Colección:** gráfico del valor total (publicado y ventas reales) bajo el total. Se agrega un punto cada vez que "Actualizar precios" cotiza al menos una carta (y cada día con la tarea diaria, que escribe la pestaña Resumen).
- **Detalle de una carta:** gráfico de su valor en el tiempo. Se agrega un punto cada vez que se cotiza.

## Dónde se guarda
| Almacenamiento | Por carta | Colección |
|---|---|---|
| Dispositivo | `historial` en `coleccion.json` (máx. 400 puntos por carta) | `resumen` en `coleccion.json` (máx. 400) |
| Google Sheets | Se calcula desde la pestaña Precios (valores en CLP, agrupados por fecha) | Pestaña Resumen |

Si Google no responde, se muestra lo guardado en el dispositivo.

## Gráfico
Dibujado con `CustomPaint`, sin dependencias. Dos líneas (publicado y ventas), valores mínimo y máximo a la izquierda, primera y última fecha abajo, y un punto en el último valor. Funciona con 0, 1 o muchos puntos, y con huecos (fechas sin precio de ventas).

## Pruebas
- Núcleo: puntos por fecha desde el historial de la planilla y resumen ordenado (1 prueba).
- App: 6 pruebas (historial local y resumen, total al actualizar, gráfico con 0, 1 y varios puntos, unión de historiales, caída de fuentes y lecturas del gráfico). Además se revisó visualmente una captura del gráfico.

## Revisión de Codex (PR #10)
| Hallazgo | Corrección |
|---|---|
| Con Google Sheets se perdían los puntos guardados solo en el dispositivo (antes de conectar, gradeadas) | Se unen ambos historiales; en la misma fecha manda la planilla |
| El gráfico del detalle releía toda la pestaña Precios en cada redibujo | `HistorialFuturo` solo relee cuando hay historial nuevo |
| Al reemplazar una carta por otra con el mismo id, el gráfico mezclaba ambas | El historial se reinicia desde el reemplazo |
| Si todas las fuentes fallaban, se pisaba el último precio con uno vacío y el total registraba una baja falsa | Se conserva el último precio; si alguna carta queda sin valor por falla, no se registra el total |

## Sin verificar
- Rendimiento con una planilla de Precios muy grande (se lee completa para cada carta): con ~60 cartas y una fila por fuente al día, en un año serían ~60.000 filas. Si se vuelve lento, conviene leer solo las fechas recientes.

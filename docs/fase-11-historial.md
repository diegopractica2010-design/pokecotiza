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
- App: historial local y resumen, registro del total al actualizar y gráfico con 0, 1 y varios puntos (3 pruebas). Además se revisó visualmente una captura del gráfico.

## Sin verificar
- Rendimiento con una planilla de Precios muy grande (se lee completa para cada carta): con ~60 cartas y una fila por fuente al día, en un año serían ~60.000 filas. Si se vuelve lento, conviene leer solo las fechas recientes.

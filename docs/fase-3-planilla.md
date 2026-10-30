# Fase 3: colección en Google Sheets

Iniciada el 2026-10-30. Código en `packages/core/lib/src/planilla/`.

## Qué hace
- **Crear la planilla** "PokeCotiza" con sus 4 pestañas y encabezados (`PlanillaColeccion.crear`).
- **Preparar la estructura** de una planilla existente: agrega las pestañas que falten sin tocar los datos (`prepararEstructura`).
- **Colección:** leer, agregar o reemplazar por id, y eliminar cartas. Las filas editadas a mano con errores se informan (número de fila y motivo) sin detener la lectura.
- **Historial de precios:** agrega cada cotización con su valor en CLP y lee el historial de una carta.
- **Resumen diario** del valor total de la colección.
- **Último tipo de cambio** guardado en `Config`, para usarlo si mindicador.cl falla.

## Estructura de la planilla
| Pestaña | Columnas |
|---|---|
| `Coleccion` | id, nombre, idioma (en/es/ja), codigo_set, numero, regulacion, condicion (NM/LP/MP/HP/DMG), acabado (normal/holo/reverseHolo), gradeadora, nota_gradeo, cantidad, tcgdex_id, tcgmatch_id, valor_manual_clp, foto_url, fecha_alta |
| `Precios` | fecha, id_carta, fuente, tipo (publicado/ventas), moneda, valor, valor_clp, detalle, url |
| `Resumen` | fecha, publicado_clp, ventas_clp, cartas |
| `Config` | clave, valor (version_esquema, tipo_cambio_usd, tipo_cambio_eur, tipo_cambio_fecha) |

Reglas: las columnas solo se agregan al final (si no, se rompen planillas existentes); las fechas se guardan en formato ISO (UTC); al eliminar una carta su historial de precios se conserva.

## Cómo se conecta con Google
- API de Google Sheets v4 por REST, sin librerías extra. Operaciones verificadas contra el documento de descubrimiento oficial (revisión 20261026).
- Escritura con `valueInputOption=RAW`: Google no reinterpreta los valores. Por ejemplo, "007/091" no se convierte en fecha.
- Lectura con `valueRenderOption=UNFORMATTED_VALUE`: los números llegan como números y no con formato regional ("1.109,37").
- Permiso previsto: `drive.file` (la app solo ve los archivos que ella crea). Según el documento oficial, este permiso sirve para crear la planilla y para leer y escribir filas.
- El token lo entrega quien use el núcleo: en la app, el inicio de sesión con Google (fase 4); en la tarea diaria, una cuenta de servicio (fase 6).

## Pruebas
- 8 pruebas con un Google Sheets simulado en memoria (`test/sheets_falso.dart`), que imita el comportamiento documentado: omite celdas y filas vacías al final.
- Se rompió el código a propósito dos veces (lectura con formato; agregar siempre en vez de reemplazar) y las pruebas lo detectaron.

## Sin verificar
- **No se ha probado contra Google Sheets real.** Requiere un proyecto de Google Cloud con la API de Sheets activada y credenciales OAuth, que se configuran en la fase 4 junto con el inicio de sesión de la app.
- Comportamiento de `drive.file` con una planilla creada por la app y abierta después desde otro dispositivo con la misma cuenta (esperado: funciona, porque el acceso es por app y cuenta).
- Límites de uso de la API de Sheets para una colección de ~60 cartas (se espera que sobre).

## Lo que necesitará el dueño (fase 4)
1. Un proyecto en Google Cloud Console.
2. Activar las APIs de Google Sheets y Google Drive.
3. Crear credenciales OAuth para Android y para escritorio (Windows).
Los pasos exactos se escribirán y verificarán al llegar a la fase 4, porque la consola de Google cambia seguido.

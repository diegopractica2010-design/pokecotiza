# Fase 8: importar y exportar Excel

Hecha el 2026-10-30. En la app: menú **⋮** de la colección.

## Importar desde Excel
- Lee la hoja "Coleccion" del archivo, o la primera hoja si no existe.
- La primera fila debe tener encabezados. Se reconocen por nombre, en cualquier orden, con o sin tildes:

| Columna | Obligatoria | Nombres aceptados | Valores |
|---|---|---|---|
| Nombre | Sí | nombre, carta | texto |
| Idioma | Sí | idioma | es/en/ja, o "español", "inglés", "japonés" |
| Número | No | número, nro | 122/131 |
| Cantidad | No | cantidad, copias | entero (1 si falta) |
| Condición | No | condición, estado | NM, LP, MP, HP, DMG (NM si falta) |
| Acabado | No | acabado, holo | normal, holo, reverse holo |
| Set, regulación, gradeadora, nota, valor_manual_clp, tcgdex_id, tcgmatch_id, foto, id | No | (los de la pestaña Coleccion) | |

- Las filas con errores se informan con su número y no detienen el resto.
- Si una fila trae un `id` que ya existe, la carta se reemplaza (no se duplica).
- Las cartas importadas no se cotizan automáticamente: se usa "Actualizar precios".

## Exportar a Excel
Guarda un `.xlsx` con las columnas de la pestaña Coleccion más el último valor publicado y de ventas reales. Ese archivo se puede volver a importar.

## Pruebas
- Núcleo: 4 pruebas (encabezados escritos a mano, errores por fila, archivo sin columnas obligatorias, exportar e importar sin cambios).
- App: 2 pruebas (escribir y leer un .xlsx con texto japonés, números y celdas vacías; exportar, importar y reimportar sin duplicar).

## Sin verificar
- Los diálogos de abrir y guardar archivo en Android y Windows (`file_picker` 13.1) no se probaron en un dispositivo.
- Archivos .xlsx hechos con otros programas (fórmulas, fechas con formato): se leen como texto.

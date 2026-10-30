# Fase 2: núcleo (`packages/core`)

Iniciada el 2026-10-30.

## Hecho
- [x] Modelos: carta de la colección, idioma, condición, acabado, gradeo, cotización.
- [x] Lector de texto de cartas: nombre, PS, número, código de set, regulación (EN/ES/JA).
- [x] TCGdex: búsqueda por nombre y número (descarta TCG Pocket), ficha de carta y precios Cardmarket/TCGplayer según acabado.
- [x] TCGmatch: lectura de `/producto/catalogo/{id}`, precios por idioma, mediana de ventas, resolución de enlaces de publicación.
- [x] mindicador.cl: dólar y euro, con respaldo al último valor conocido.
- [x] Valorización: mediana publicada, mediana de ventas (prefiere CLP), gradeadas manuales, total de la colección.
- [x] Cliente HTTP con pausa entre peticiones al mismo sitio.
- [x] 28 pruebas con respuestas reales guardadas; CI en GitHub Actions (formato, análisis, pruebas).
- [x] Prueba manual contra los sitios reales con `example/cotizar.dart` (2026-10-30).

## Resultado de la prueba real (2026-10-30)
Lucario GX Full Art 122/131 (español, holo):

| Fuente | Tipo | Valor | CLP |
|---|---|---|---|
| TCGmatch | publicado (market, español) | 30.000 CLP | 30.000 |
| Cardmarket | publicado (trend) | 33,81 EUR | 37.508 |
| Cardmarket | ventas (avg30) | 41,05 EUR | 45.540 |
| TCGplayer | publicado (holofoil market) | 35,02 USD | 34.783 |

Valor publicado: **34.783 CLP** · Ventas reales: **45.540 CLP** (TCGmatch no tenía ventas en español para esta carta, así que se usó Cardmarket). mindicador.cl no respondió y se usó el último tipo de cambio conocido.

## Errores encontrados al probar el flujo completo (2026-10-30)
Al generar la página de pruebas con textos de cartas reales aparecieron cuatro errores que las pruebas anteriores no cubrían. Están corregidos y con prueba:

| Error | Corrección |
|---|---|
| "ETAPA 1" se tomaba como nombre de la carta | El lector ignora también "Etapa N" |
| El ilustrador ("Yuka Morii 1/131") se tomaba como código de set | El código de set exige mayúsculas y dígitos (OBF, MEW, SV2a) |
| TCGdex no encuentra "Lucario-GX" (la llama "Lucario GX") | La búsqueda reintenta sin guion y luego con la primera palabra |
| El filtro de número de TCGdex es aproximado ("1" trae "102") y la primera candidata podía ser de otra expansión | Se dejan solo números exactos y se ordenan primero las expansiones cuyo total oficial coincide con el impreso ("131" en "1/131") |

## Página de pruebas
- `web/lector_js.dart`: expone el lector al navegador. Compilar con `dart compile js -O2 -o lector.js web/lector_js.dart`.
- `example/generar_demo.dart`: ejecuta el flujo completo con las fuentes reales y escribe los datos de la página (`dart run example/generar_demo.dart > demo.json`).

## Pendiente en esta fase
- [ ] Cache local de respuestas (evitar repetir consultas el mismo día).
- [ ] Ajuste del valor por condición (hoy todas las fuentes se tratan como NM).
- [ ] Más casos reales para el lector de texto cuando haya fotos con OCR (fase 7).

## Fuera de esta fase
Google Sheets (fase 3), interfaz (fase 4), tarea diaria (fase 6).

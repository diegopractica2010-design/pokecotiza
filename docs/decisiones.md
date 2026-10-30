# Registro de decisiones

| # | Fecha | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|---|
| 1 | 2026-10-30 | Flutter para Android y Windows | Un solo código para ambas plataformas | Apps nativas separadas |
| 2 | 2026-10-30 | Sin servidor propio | Requisito de costo cero | Backend propio con hosting |
| 3 | 2026-10-30 | Google Sheets como base de datos | Gratis, compartida entre teléfono y PC, el usuario la puede ver y editar | Excel local (difícil de sincronizar) |
| 4 | 2026-10-30 | Actualización diaria con GitHub Actions | Gratis y programable; reutiliza la misma lógica en Dart | Actualizar solo a pedido (deja huecos en el historial) |
| 5 | 2026-10-30 | Lógica en un paquete Dart compartido | La app y la tarea diaria usan el mismo código de cotización | Scrapers duplicados en otro lenguaje |
| 6 | 2026-10-30 | Preferir APIs al scraping de HTML | Más estable y menos riesgo con los términos de uso | Scrapear todo |
| 7 | 2026-10-30 | Dos valores por carta: promedio publicado y promedio de ventas reales | Pedido del dueño; las publicaciones suelen estar por sobre lo que realmente se paga | Un solo precio |
| 8 | 2026-10-30 | TCGmatch como fuente principal en Chile, leyendo solo páginas públicas | Es un marketplace con varios vendedores; su robots.txt excluye `/api/` | Usar su API interna |
| 9 | 2026-10-30 | Repo público con todos los derechos reservados | El dueño quiere poder comercializarlo; sin licencia abierta nadie obtiene permisos de uso | Licencias abiertas (MIT, GPL) |
| 10 | 2026-10-30 | Registrar la condición de cada carta, NM por defecto | Cambia mucho el precio; TCGmatch vende por condición | Ignorar la condición |
| 11 | 2026-10-30 | Fotos en Google Drive con permiso `drive.file` | Gratis, junto a la planilla; acceso solo a archivos de la app | Guardar fotos solo en el dispositivo |
| 12 | 2026-10-30 | TCGmatch se vincula carta por carta y se lee solo `/producto/catalogo/{id}` | Su búsqueda depende de `/api/` (excluida por robots.txt); 60 cartas se vinculan en minutos | Usar su API interna; recorrer los sitemaps (~790 mil publicaciones) |
| 13 | 2026-10-30 | TCGdex como catálogo principal (EN/ES/JA) y fuente de Cardmarket/TCGplayer | Funciona sin clave, tiene japonés y español, y precios recientes | pokemontcg.io (solo inglés; Cardmarket desactualizado en la prueba) |
| 14 | 2026-10-30 | Tipo de cambio desde mindicador.cl | API pública chilena, probada | — |
| 15 | 2026-10-30 | Ventas reales se expresan como mediana | Es lo que entrega TCGmatch y resiste ventas atípicas | Promedio |
| 16 | 2026-10-30 | No contactar a TCGmatch por ahora | La app es de uso personal; lectura de pocas páginas públicas a baja frecuencia | Pedir autorización antes de empezar |
| 17 | 2026-10-30 | Cartas gradeadas con valor manual por ahora | No hay fuente pública gratuita: TCGmatch las sirve vía `/api/` y eBay restringe su API de ventas | Scrapear la API de TCGmatch; API de eBay |
| 18 | 2026-10-30 | Mercado Libre pospuesto a la fase 9 | Su API exige autenticación (403 sin token) | Scrapear su HTML |
| 19 | 2026-10-30 | Cardmarket `avg30` como respaldo de ventas reales | Según fuentes secundarias es promedio de ventas a 30 días | Usar `trend` |

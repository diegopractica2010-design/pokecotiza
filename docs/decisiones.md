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

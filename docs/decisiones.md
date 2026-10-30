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
| 20 | 2026-10-30 | Dart puro para el núcleo, en `packages/core` | Lo comparten la app Flutter y la tarea diaria | Lógica dentro de la app |
| 21 | 2026-10-30 | Acabado de la carta (normal / holo / reverse holo) en vez de "es holo" | En la prueba real, el `-holo` de Cardmarket para una Full Art valía un tercio del precio normal: corresponde a reverse holo (deducción, no documentado) | Un booleano "holo" |
| 22 | 2026-10-30 | Si TCGplayer no tiene la variante del acabado, se omite | Mezclar acabados da precios engañosos | Usar cualquier variante disponible |
| 23 | 2026-10-30 | El tipo de cambio cae al último valor conocido si mindicador.cl no responde | El servicio no respondió varias veces el 2026-10-30 | Fallar la cotización completa |
| 24 | 2026-10-30 | Cliente REST propio para Google Sheets (sin el paquete `googleapis`) | Se usan 7 operaciones; menos dependencias y el token lo entrega cada plataforma | Paquete `googleapis` completo |
| 25 | 2026-10-30 | Escribir con RAW y leer con UNFORMATTED_VALUE | Evita que Google convierta "007/091" en fecha y que los números lleguen con formato regional | USER_ENTERED / FORMATTED_VALUE |
| 26 | 2026-10-30 | La app crea la planilla y usa el permiso `drive.file` | Acceso solo a archivos de la app; el mismo permiso sirve para las fotos | Permiso `spreadsheets` (todas las planillas del usuario) |
| 27 | 2026-10-30 | Eliminar una carta conserva su historial de precios | El historial sirve para ver la evolución de la colección | Borrar también sus precios |
| 28 | 2026-10-30 | Windows inicia sesión con `googleapis_auth` (navegador) y Android con `google_sign_in` | `google_sign_in` no es compatible con Windows (pub.dev) | Un solo paquete para ambos |
| 29 | 2026-10-30 | La app guarda primero en el dispositivo, con el mismo formato de fila que la planilla | Se puede probar sin credenciales de Google y pasar después a Sheets sin convertir datos | Exigir Google desde el inicio |
| 30 | 2026-10-30 | GitHub Actions compila el APK y la versión de Windows | Este entorno es Linux, sin Android SDK ni Windows | Compilar a mano en el PC del dueño |
| 31 | 2026-10-30 | En TCGmatch se pega el enlace; el navegador dentro de la app queda para después | `webview_flutter` no es compatible con Windows; pegar el enlace funciona en ambos | `flutter_inappwebview` desde el inicio |
| 32 | 2026-10-30 | Permiso `spreadsheets` en vez de `drive.file` (reemplaza la decisión 26 para la planilla) | Con `drive.file`, no está confirmado que el otro dispositivo pueda abrir la planilla creada en el primero; la vía oficial exige un selector de archivos de Google | `drive.file` + Google Picker |
| 33 | 2026-10-30 | Credenciales de Google por `--dart-define` desde variables y secretos del repositorio | No quedan en el código; sin ellas la app funciona solo en el dispositivo | Archivo de configuración en el repositorio |
| 34 | 2026-10-30 | La última cotización de cada carta se guarda también en el dispositivo | La app abre rápido sin leer todo el historial de la planilla | Leer siempre de la planilla |
| 35 | 2026-10-30 | La tarea diaria usa una cuenta de servicio de Google | No depende de la sesión del usuario (que vence cada 7 días en modo de prueba) | Guardar el token del usuario como secreto |
| 36 | 2026-10-30 | Si faltan los secretos, la tarea diaria se salta con un aviso | No llenar el historial de ejecuciones fallidas antes de configurarla | Que falle hasta configurarla |

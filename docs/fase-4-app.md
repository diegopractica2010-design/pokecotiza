# Fase 4: primera versión de la app (Android y Windows)

Iniciada el 2026-10-30. Código en `app/` (Flutter 3.47.9, Dart 3.13.7).

## Parte A: app base (hecha)
| Pantalla | Qué hace |
|---|---|
| Colección | Lista de cartas con su valor publicado y de ventas reales, total de la colección, tipo de cambio, avisos de filas con error. Botón "Actualizar precios" (cotiza todas, una a la vez) |
| Agregar carta | Nombre, número e idioma (a mano o pegando el texto de la carta, que lee el núcleo). Busca en TCGdex y muestra las candidatas con imagen. Permite agregar sin catálogo (gradeadas) |
| Confirmar / Editar | Acabado, condición, cantidad, gradeo con valor manual y enlace de TCGmatch (se valida). "Guardar y cotizar" |
| Detalle | Valor, precios por fuente (original y en pesos), fuentes que fallaron, actualizar, editar y eliminar |

- **Núcleo:** nuevo `Cotizador`, que junta TCGdex y TCGmatch para una carta. Si una fuente falla, sigue con las demás y lo informa. Lo reutilizará la tarea diaria.
- **Almacenamiento:** por ahora, un archivo en el dispositivo (`coleccion.json`), con el mismo formato de fila que la planilla. Así el paso a Google Sheets no cambia los datos.
- **Android:** permiso de internet y apertura de enlaces https.
- **Instaladores automáticos:** `.github/workflows/app.yml` corre análisis y pruebas, compila el APK (en Ubuntu) y la versión de Windows (en un equipo Windows de GitHub), y los deja para descargar 30 días en la pestaña "Actions" del repositorio.

### Pruebas
- App: 6 pruebas (3 de ellas por la revisión de Codex). Una recorre el flujo completo (agregar → buscar → confirmar con TCGmatch → ver valor) con respuestas reales guardadas; otra verifica que un enlace inválido no guarde nada; otra, que el archivo local guarde y relea los datos. Se rompió el código a propósito (no guardar el vínculo con TCGmatch) y la prueba lo detectó.
- Núcleo: 48 pruebas (4 nuevas del cotizador).

### Revisión de Codex (PR #6)
| Hallazgo | Corrección |
|---|---|
| (P1) Cada APK se firmaba con una clave distinta: no se podía actualizar sin desinstalar (y perder la colección local) | Firma con clave estable si existe el secreto del repositorio; guía en [firma-android.md](firma-android.md). **Pendiente: el dueño debe crear el secreto** |
| Una gradeada no se guardaba si mindicador.cl fallaba | Las gradeadas no piden tipo de cambio |
| Una respuesta ilegible de TCGdex cortaba la cotización | Se informa como falla de esa fuente y se sigue con TCGmatch |
| Si "Actualizar precios" fallaba, el botón quedaba bloqueado | El avance se libera siempre |
| Se aceptaban valores manuales negativos | Se rechazan |
| Dos guardados simultáneos podían pisarse en el archivo local | Las escrituras se hacen en cola |
| Si la búsqueda fallaba, desaparecía "Agregar sin catálogo" | Queda siempre disponible |

### Sin verificar
- **No se ha ejecutado en un teléfono ni en Windows:** este entorno es Linux y no tiene Android SDK. La compilación la hace GitHub; falta que el dueño instale y pruebe.
- La APK queda firmada con la clave de desarrollo: se instala en el teléfono, pero no sirve para Google Play (no está en el plan).
- En Android, el navegador dentro de la app para TCGmatch queda para después; por ahora se abre el navegador del teléfono y se pega el enlace.

## Parte B: Google Sheets (código hecho; falta configurar credenciales)
- **Ajustes (⚙):**
  - "Conectar con Google y crear planilla": inicia sesión, crea la planilla, sube las cartas del dispositivo y cambia la app a Google Sheets.
  - "Conectar con esa planilla": para el segundo dispositivo, pegando el enlace de la planilla.
  - "Abrir planilla" y "Desconectar".
- **Inicio de sesión:**
  - Android: `google_sign_in` 7 con una credencial "web" (`serverClientId`); Google reconoce la app por el paquete y la huella SHA-1 de la clave de firma.
  - Windows: `googleapis_auth` abre el navegador; la sesión se guarda cifrada con `flutter_secure_storage` y se renueva sola.
- **Datos:** la colección, el historial de precios y el tipo de cambio van a la planilla. La última cotización de cada carta se guarda además en el dispositivo para abrir la app rápido.
- **Al abrir la app:** si la planilla no está disponible (sesión vencida), muestra la copia del dispositivo con un aviso.
- **Credenciales:** entran al compilar (`--dart-define`) desde las variables y secretos del repositorio. Sin ellas, la app funciona solo con el dispositivo.
- **Pruebas:** 7 nuevas (13 en total), con Google Sheets simulado y una sesión falsa: crear y conectar, subir cartas, segundo dispositivo, historial. Se rompió la subida de cartas a propósito y las pruebas lo detectaron.

### Revisión de Codex (PR #7)
| Hallazgo | Corrección |
|---|---|
| Si Google fallaba con la sesión aparentemente vigente, la colección quedaba vacía | La planilla se copia en el dispositivo; si Google falla, se muestra esa copia con un aviso |
| Android: rechazar el permiso de Sheets dejaba la app "conectada" sin poder usarla | "Conectada" exige también el permiso; si falta, se vuelve a pedir |

### Lo que falta (necesita al dueño)
1. Crear las credenciales en Google Cloud: [google-cloud.md](google-cloud.md).
2. Para Android, además, la clave de firma fija: [firma-android.md](firma-android.md).

### Sin verificar
- No se ha probado contra Google real (faltan las credenciales).
- Que la sesión venza cada 7 días mientras la app esté en "modo de prueba" (información de foros, no oficial).

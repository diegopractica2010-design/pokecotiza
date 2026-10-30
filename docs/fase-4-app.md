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

## Parte B: Google Sheets real (pendiente, necesita al dueño)
- **Android:** inicio de sesión con `google_sign_in`.
- **Windows:** `google_sign_in` no es compatible con Windows (según pub.dev, solo Android, iOS, macOS y web). Se usará `googleapis_auth`, que abre el navegador para iniciar sesión.
- **Lo que tendrá que hacer el dueño:** crear un proyecto en Google Cloud, activar las APIs de Sheets y Drive, y crear credenciales OAuth para Android y escritorio. Los pasos se verifican contra la consola de Google al momento de hacerlo.
- Luego: la opción "Guardar en Google Sheets" en la app y la prueba contra la planilla real.

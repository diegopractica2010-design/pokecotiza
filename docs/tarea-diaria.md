# Tarea diaria (fase 6)

Todos los días a las 09:47 UTC, GitHub Actions cotiza toda la colección de tu planilla y registra en ella:
- en `Precios`, una fila por fuente y carta;
- en `Resumen`, el valor total del día;
- en `Config`, el tipo de cambio.

Gratis en repositorios públicos. También se puede correr a mano: pestaña **Actions → Actualización diaria de precios → Run workflow**.

## Configurar (una vez)
Usa una **cuenta de servicio**: un usuario de Google para programas. No depende de tu sesión y no vence cada 7 días.

1. En Google Cloud (el mismo proyecto de [google-cloud.md](google-cloud.md)): **IAM y administración → Cuentas de servicio → Crear**. Nombre: `pokecotiza-diaria`. No necesita roles.
2. En esa cuenta: **Claves → Agregar clave → JSON**. Se descarga un archivo `.json`. Es una contraseña: no lo subas al repositorio ni lo compartas.
3. Abre tu planilla de PokeCotiza en Google Sheets → **Compartir** → agrega el correo de la cuenta de servicio (termina en `iam.gserviceaccount.com`) como **Editor**.
4. En GitHub, en **Settings → Secrets and variables → Actions**:
   - Secreto `GOOGLE_SERVICE_ACCOUNT_JSON`: el contenido completo del `.json`.
   - Variable `POKECOTIZA_ID_PLANILLA`: el enlace de la planilla.

Sin esto, la tarea se salta con un aviso, sin fallar.

## Qué hace
`tools/actualizador/bin/actualizar.dart` usa la lógica del núcleo (`actualizarColeccion`):
1. Tipo de cambio (si mindicador.cl falla, usa el de la planilla).
2. Cada carta: TCGdex y TCGmatch (pausa de 2 s entre peticiones al mismo sitio). Una fuente que falla no detiene el resto.
3. Registra precios y resumen. El informe queda en la página de la ejecución en GitHub.

## Revisión de Codex (PR #8)
| Hallazgo | Corrección |
|---|---|
| Si todas las fuentes de una carta fallaban, contaba como 0 y el resumen mostraba una baja falsa | Se usa su último precio registrado y se informa |
| La clave de la cuenta de servicio era visible para todos los pasos del workflow | Solo la ven el paso que verifica si existe y el que cotiza |
| Sin tipo de cambio (mindicador caído y ninguno guardado) no se registraba nada | Sigue con precios en pesos (TCGmatch y gradeadas) y lo avisa |

## Sin verificar
- Que los sitios no bloqueen las peticiones desde los equipos de GitHub.
- Los nombres de menú de Google Cloud (revisar al configurar).
